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

    def initialize(@clusters, @contexts, @current_context, @api_version = "v1", @kind = "Config"); end

    def initialize(@clusters, @contexts, @current_context, @preferences, @users, @api_version = "v1", @kind = "Config"); end

    def initialize; end

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
          clusters:        [{name: cluster_name, cluster: {server: server, certificate_authority_data: ca}}],
          users:           [{name: user, user: {token: auth_token}}],
          contexts:        [{name: context, context: {cluster: cluster_name, user: user}}],
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
