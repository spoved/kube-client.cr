require "./version"
require "./client_mixin"
require "./client/*"
require "halite"

# TODO: Write documentation for `Kube::Client`
module Kube
  class Client
    include ClientMixin

    property context = Hash(Symbol, String | YAML::Any | Nil).new
    getter config : Kube::Client::Config

    # Initialize a Client using the `KUBECONFIG` env
    def self.new
      unless ENV["KUBECONFIG"]?
        raise Error.new("Must define KUBECONFIG env")
      end

      instance = Client.allocate
      # TODO: handle multiple config files
      # ```
      # export  KUBECONFIG=$KUBECONFIG:config-demo:config-demo-2
      # ```
      instance.initialize(ENV["KUBECONFIG"].split(':').first)
      instance
    end

    def initialize(kube_file : String)
      @config = Config.read(kube_file)
      @context = config.current_context

      uri = URI.parse(context[:cluster].as(YAML::Any)["server"].as_s)
      @api = Api.new(uri.host.as(String), scheme: uri.scheme.as(String), port: uri.port)
      update_api
    end

    # Change the current context
    #
    # @example
    #   ```
    #   client = Kube::Client.new("~/.kube/config")
    #   client.context[:name]   => "mysql-test"
    #   client.change_context("mysql-helper")
    #   client.context[:name]   => "mysql-helper"
    #   ```
    def change_context(context_name : String)
      @context = config.fetch_context(context_name)
      update_api
    end

    def pods(namespace : String? = nil, label_selector : Hash(String, String)? = nil)
      if namespace.nil?
        namespace = context[:namespace] || "default"
      end

      params = Hash(String, String).new
      if label_selector
        params["labelSelector"] = label_selector.map { |k, v| "#{k}=#{v}" }.join(",")
      end

      api.get("namespaces/#{namespace}/pods", params: params)
    end

    # This is called after initialization and when the context changes. It will
    #   update the api client with any changes to the server settings.
    private def update_api
      raise Error.new("No cluster info found") unless context[:cluster]?
      raise Error.new("No server info found") unless context[:cluster].as(YAML::Any)["server"]?
      uri = URI.parse(context[:cluster].as(YAML::Any)["server"].as_s)

      api.host = uri.host.as(String)
      api.scheme = uri.scheme.as(String)
      api.port = uri.port
      api.default_headers = format_headers
    end

    private def format_headers
      auth_options = config.fetch_user_auth_options(context[:user].as(YAML::Any))
      if auth_options[:bearer_token]?
        DEFAULT_HEADERS.merge({
          "Authorization" => "Bearer #{auth_options[:bearer_token]}",
        })
      else
        raise Error.new("Unsupported Auth type")
      end
    end

    def api
      @api
    end
  end
end
