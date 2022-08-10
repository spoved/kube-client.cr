require "json"
require "yaml"

require "./error"
require "./config/var"
require "./config/*"

module Kube
  class Config
    class Error < Kube::Error; end

    include Kube::Config::Var

    @[JSON::Field(key: "apiVersion")]
    @[YAML::Field(key: "apiVersion")]
    property api_version : String = "v1"
    property kind : String = "Config"

    property clusters : Array(Cluster) = Array(Cluster).new
    property contexts : Array(Context) = Array(Context).new

    @[JSON::Field(key: "current-context")]
    @[YAML::Field(key: "current-context")]
    property current_context : String? = nil
    property preferences : Hash(String, String) = Hash(String, String).new
    property users : Array(User) = Array(User).new

    def initialize(@clusters, @contexts, @current_context,
                   @preferences = Hash(String, String).new, @users = Array(User).new, @api_version = "v1", @kind = "Config"); end

    def initialize; end

    # Attempts to create a `Kube::Config` automatically using environment variables, or
    # existing configuration files.
    #
    # Look-up order:
    #   - KUBE_TOKEN, KUBE_CA, KUBE_SERVER environment variables
    #   - KUBECONFIG environment variable
    #   - $HOME/.kube/config file
    #
    # Will raise when no means of configuration is available
    def self.autoconfig
      if ENV.has_key?("KUBE_TOKEN") && ENV.has_key?("KUBE_CA") && ENV.has_key?("KUBE_SERVER")
        kube_ca = Base64.decode_string(ENV["KUBE_CA"])
        unless kube_ca =~ /CERTIFICATE/
          raise "KUBE_CA does not seem to be base64 encoded"
        end
        kube_token = Base64.decode_string(ENV["KUBE_TOKEN"])
        kube_server = ENV["KUBE_SERVER"]
        Kube::Config.build(kube_server, kube_ca, kube_token)
      elsif ENV.has_key?("KUBECONFIG")
        Kube::Config.from_kubeconfig_env
      else
        found_config = [
          File.join(Path.home, ".kube", "config"),
          "/etc/kubernetes/admin.conf",
          "/etc/kubernetes/kubelet.conf",
        ].find { |path| File.exists?(path) && File.readable?(path) }
        if found_config
          Kube::Config.load_file(found_config)
        else
          nil
        end
      end
    end

    def self.defaults
      Config.new
    end

    # Loads a configuration from a YAML file
    def self.load_file(path : String) : Kube::Config
      Config.from_yaml(File.read(path))
    end

    # Loads configuration files listed in KUBE_CONFIG environment variable and
    # merge using the configuration merge rules, @see K8s::Config.merge
    def self.from_kubeconfig_env(kubeconfig = nil) : Kube::Config
      kubeconfig ||= ENV.fetch("KUBECONFIG", "")

      raise Error.new("KUBECONFIG not set") if kubeconfig.empty?
      paths = kubeconfig.split(/(?!\\):/)

      config = new()
      paths.each do |path|
        raise Error.new("KUBECONFIG file not found: #{path}") unless File.exists?(path)
        config.merge!(load_file(path))
      end
      config
    end

    # Build a minimal configuration from at least a server address, server certificate authority data and an access token.
    def self.build(server : String, ca : String, auth_token : String,
                   cluster_name : String = "kubernetes", user : String = "k8s-client", context : String = "k8s-client", **options)
      new(
        **{
          clusters: [
            Cluster.new(name: cluster_name, cluster: ClusterDef.new(server: server, certificate_authority_data: ca)),
          ],
          users: [
            User.new(name: user, user: UserDef.new(token: auth_token)),
          ],
          contexts: [
            Context.new(name: context, context: ContextDef.new(cluster: cluster_name, user: user)),
          ],
          current_context: context,
        }.merge(options)
      )
    end

    # Merges configuration according to the rules specified in
    # https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/#merging-kubeconfig-files
    def merge(other : Kube::Config) : Kube::Config
      Config.new(
        clusters: merge_arrays(clusters.dup, other.clusters),
        contexts: merge_arrays(contexts.dup, other.contexts),
        current_context: current_context || other.current_context,
        preferences: preferences.dup.merge(other.preferences),
        users: merge_arrays(users.dup, other.users),
        api_version: api_version,
        kind: kind
      )
    end

    def merge!(other : Kube::Config) : Kube::Config
      merge_arrays(clusters, other.clusters)
      merge_arrays(contexts, other.contexts)
      self.current_context = self.current_context || other.current_context
      preferences.merge!(other.preferences)
      merge_arrays(users, other.users)
      self
    end

    private def merge_arrays(current, other)
      current.concat(other.reject { |new_mapping| current.any? { |old_mapping| (old_mapping.name == new_mapping.name) } })
    end

    # Returns the context with the given `name` or the current context
    def context(name : String? = nil) : Context
      name = current_context if name.nil?
      raise(Error.new "no context set") if name.nil?
      contexts.find { |c| c.name == name } || raise(Error.new "context not found: #{name.inspect}")
    end

    # Returns the user with the given `name` or the user of the current context
    def user(name : String? = nil) : User
      name = context.user if name.nil?
      users.find { |u| u.name == name } || raise(Error.new "user not found: #{name.inspect}")
    end

    # Returns the cluster with the given `name` or the cluster of the current context
    def cluster(name : String? = nil) : Cluster
      name = context.cluster if name.nil?
      clusters.find { |c| c.name == name } || raise(Error.new "cluster not found: #{name.inspect}")
    end
  end
end
