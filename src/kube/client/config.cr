require "../error"
require "./config/*"
require "yaml"
require "base64"

module Kube
  class Client
    # Kubernetes client configuration class
    class Config
      # data (Hash) - Parsed kubeconfig data.
      # kcfg_path (string) - Base directory for resolving relative references to external files.
      #   If set to nil, all external lookups & commands are disabled (even for absolute paths).
      # See also the more convenient Config.read
      def initialize(data : YAML::Any, kcfg_path : String? = nil)
        @kcfg = data
        @kcfg_path = kcfg_path
        raise "Unknown kubeconfig version" if @kcfg["apiVersion"] != "v1"
      end

      # Builds Config instance by parsing given file, with lookups relative to file's directory.
      def self.read(filename : String)
        parsed = YAML.parse(File.read(filename))
        Config.new(parsed, File.dirname(filename))
      end

      # Returns all the available contexts
      def contexts : Array(String)
        @kcfg["contexts"].as_a.map { |x| x["name"].to_s }
      end

      def current_context
        fetch_context(@kcfg["current-context"].as_s)
      end

      private def allow_external_lookups?
        @kcfg_path != nil
      end

      # Returns the absolute path of the file path
      private def ext_file_path(path : String) : String
        unless allow_external_lookups?
          raise "Kubeclient::Config: external lookups disabled, can't load \"#{path}\""
        end
        path =~ /^\// ? File.expand_path(path) : File.expand_path(File.join(@kcfg_path || "", path))
      end

      # Returns the absolute path of the command path
      private def ext_command_path(path : String) : String
        unless allow_external_lookups?
          raise "Kubeclient::Config: external lookups disabled, can't execute \"#{path}\""
        end
        # Like go client https://github.com/kubernetes/kubernetes/pull/59495#discussion_r171138995,
        # distinguish 3 cases:
        # - absolute (e.g. /path/to/foo)
        # - $PATH-based (e.g. curl)
        # - relative to config file's dir (e.g. ./foo)
        if path =~ /^\//
          File.expand_path(path)
        elsif File.basename(path) == path
          File.expand_path(path)
        else
          File.expand_path(File.join(@kcfg_path || "", path))
        end
      end

      # Fetch the cluster, user and namespace information for the provided {context_name}
      def fetch_context(context_name : String)
        context = @kcfg["contexts"].as_a.find do |x|
          x["name"] == context_name
        end

        unless context
          raise KeyError.new("Unknown context #{context_name}")
        end

        cluster = @kcfg["clusters"].as_a.find do |x|
          x["name"] == context["context"]["cluster"]
        end

        unless cluster
          raise KeyError.new("Unknown cluster #{context["context"]["cluster"]}")
        end

        user = @kcfg["users"].as_a.find do |x|
          x["name"] == context["context"]["user"]
        end

        unless user
          raise KeyError.new("Unknown user #{context["context"]["user"]}")
        end

        namespace = context["context"]["namespace"]? ? context["context"]["namespace"].as_s : nil

        {
          :name      => context["name"].as_s,
          :cluster   => cluster["cluster"],
          :user      => user["user"],
          :namespace => namespace,
        }
      end

      private def fetch_cluster_ca_data(cluster : YAML::Any) : String | Nil
        if cluster["certificate-authority"]?
          File.read(ext_file_path(cluster["certificate-authority"].as_s))
        elsif cluster["certificate-authority-data"]?
          Base64.decode_string(cluster["certificate-authority-data"].as_s)
        end
      end

      private def fetch_user_cert_data(user : YAML::Any) : String | Nil
        if user["client-certificate"]?
          File.read(ext_file_path(user["client-certificate"].as_s))
        elsif user["client-certificate-data"]?
          Base64.decode_string(user["client-certificate-data"].as_s)
        end
      end

      private def fetch_user_key_data(user : YAML::Any) : String | Nil
        if user["client-key"]?
          File.read(ext_file_path(user["client-key"].as_s))
        elsif user["client-key-data"]?
          Base64.decode_string(user["client-key-data"].as_s)
        end
      end

      # TODO: Enable exec support
      # TODO: Enable auth provider
      # TODO: Enable support for user/pass
      def fetch_user_auth_options(user : YAML::Any)
        options = Hash(Symbol, String).new
        if user["token"]?
          options[:bearer_token] = user["token"].as_s
          # TODO: Enable exec support
          # elsif user["exec"]?
          #   exec_opts = user["exec"].as_a.dup
          #   exec_opts["command"] = ext_command_path(exec_opts["command"]) if exec_opts["command"]?
          #   options[:bearer_token] = Kubeclient::ExecCredentials.token(exec_opts)
          # TODO: Enable auth provider
          # elsif user["auth-provider"]?
          #   auth_provider = user["auth-provider"]
          #   options[:bearer_token] = case auth_provider["name"].as_s
          #                            when "gcp"
          #                            then Kubeclient::GoogleApplicationDefaultCredentials.token
          #                            when "oidc"
          #                            then Kubeclient::OIDCAuthProvider.token(auth_provider["config"])
          #                            end
          # TODO: Enable support for user/pass
          # else
          #   %w[username password].each do |attr|
          #     options[attr.to_sym] = user[attr].as_s if user[attr]?
          #   end
        end
        options
      end
    end
  end
end
