require "./client_mixin"
require "./client/*"
require "halite"
require "spoved/logger"

# TODO: Write documentation for `Kube::Client`
module Kube
  class Client
    spoved_logger

    include ClientMixin
    extend ServiceAccount

    property context = Hash(Symbol, String | YAML::Any | Nil).new
    getter config : Kube::Client::Config
    getter api : Api

    # Initialize a Client using the `KUBECONFIG` env
    # TODO: handle multiple config files
    def self.new
      unless ENV["KUBECONFIG"]?
        raise Error.new("Must define KUBECONFIG env")
      end

      instance = Client.allocate
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

    def nodes(label_selector : Hash(String, String)? = nil)
      params = Hash(String, String).new
      format_label_selectors(params, label_selector)

      api.get("nodes", params: params)
    end

    def stream
      api.stream
    end

    def watch_nodes(label_selector : Hash(String, String)? = nil)
      params = {
        "watch" => "true",
      }
      format_label_selectors(params, label_selector)
      api.stream_get("nodes", params: params)
    end

    def watch_pods(namespace : String? = nil, label_selector : Hash(String, String)? = nil)
      if namespace.nil?
        namespace = context[:namespace] || "default"
      end

      params = {
        "watch" => "true",
      }
      format_label_selectors(params, label_selector)
      api.stream_get("namespaces/#{namespace}/pods", params: params)
    end

    # Gathers all the pods
    def pods(namespace : String? = nil, label_selector : Hash(String, String)? = nil)
      if namespace.nil?
        namespace = context[:namespace] || "default"
      end

      params = Hash(String, String).new
      format_label_selectors(params, label_selector)

      api.get("namespaces/#{namespace}/pods", params: params)
    end

    # Delete pod
    def delete_pod(name : String, namespace : String? = nil)
      if namespace.nil?
        namespace = context[:namespace] || "default"
      end

      api.delete("namespaces/#{namespace}/pods/#{name}")
    end

    # Will select pods with the provided status
    def select_pods(namespace : String? = nil, label_selector : Hash(String, String)? = nil, status : String? = nil) : Array(JSON::Any)
      data = pods(namespace, label_selector)["items"].as_a
      if status.nil?
        data
      else
        data.select { |pod| pod["status"]["phase"] == status }
      end
    end

    def add_pod_label(pod_name : String, key : String, value : String, namespace : String? = nil)
      mod_pod_label("add", pod_name, key, value, namespace)
    end

    def del_pod_label(pod_name : String, key : String, namespace : String? = nil)
      mod_pod_label("delete", pod_name, key, "", namespace)
    end

    def mod_pod_label(mod, pod_name : String, key : String, value : String, namespace : String? = nil)
      if namespace.nil?
        namespace = context[:namespace] || "default"
      end

      data = [
        {
          "op"    => mod,
          "path"  => "/metadata/labels/#{key}",
          "value" => value,
        },
      ]

      api.default_headers = format_headers.merge({
        "Content-Type" => "application/json-patch+json",
        "Accept"       => "application/json",
      })

      resp = api.patch("namespaces/#{namespace}/pods/#{pod_name}", body: data.to_json)
      api.default_headers = format_headers
      resp
    end

    def patch(path, data)
      api.default_headers = format_headers.merge({
        "Content-Type" => "application/json-patch+json",
        "Accept"       => "application/json",
      })

      resp = api.patch(path, body: data.to_json)
      api.default_headers = format_headers
      resp
    end

    private def format_label_selectors(params, label_selector)
      if label_selector
        params["labelSelector"] = label_selector.map { |k, v| "#{k}=#{v}" }.join(",")
      end
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
