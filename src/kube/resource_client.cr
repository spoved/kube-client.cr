require "./transport"
require "./api_client"

module Kube
  # Per-APIResource type client.
  #
  # Used to get/list/update/patch/delete specific types of resources, optionally in some specific namespace.
  class ResourceClient(T)
    @@logger = ::Log.for(Kube::ResourceClient)
    @logger : ::Log

    def logger
      @logger
    end

    def self.logger
      @@logger
    end

    module Utils
      # @param selector [NilClass, String, Hash{String => String}]
      # @return [NilClass, String]
      def selector_query(selector : String | Symbol | Hash(String, String) | Nil) : String
        case selector
        when Nil
          nil
        when Symbol
          selector.to_s
        when String
          selector
        when Hash
          selector.map { |k, v| "#{k}=#{v}" }.join ','
        else
          fail "Invalid selector type. #{selector.inspect}"
        end
      end

      # @param options [Hash]
      # @return [Hash, NilClass]
      def make_query(options)
        query = options.compact
        return nil if query.empty?
        query
      end
    end

    include Utils
    extend Utils

    private property transport : Kube::Transport
    private property api_client : Kube::ApiClient
    getter api_resource : K8S::Apimachinery::Apis::Meta::V1::APIResource
    getter namespace : String? = nil
    getter resource : String
    getter subresource : String? = nil
    getter resource_class = K8S::Kubernetes::Resource

    private macro define_new
      def self.new(transport, api_client, api_resource : K8S::Apimachinery::Apis::Meta::V1::APIResource, namespace = nil)
        ver = (api_resource.version.nil? ||  api_resource.version.not_nil!.empty?) ? "v1" : api_resource.version.not_nil!
        group = api_resource.group.nil? ? "" : api_resource.group.not_nil!
        case {group, ver, api_resource.kind}
        {% for resource in K8S::Kubernetes::Resource.subclasses %}
          {% if resource.annotation(::K8S::GroupVersionKind) %}
            {% anno = resource.annotation(::K8S::GroupVersionKind) %}
            when { {{anno[:group]}}, {{anno[:version]}}, {{anno[:kind]}} }
            ::Kube::ResourceClient({{resource.id}}).new(transport, api_client, api_resource, namespace, {{resource.id}})
          {% end %}
        {% end %}
        else
          # puts ({group, ver, api_resource.kind}.inspect)
          logger.warn { "Unknown resource: #{group}/#{ver}/#{api_resource.kind}" }
          ::Kube::ResourceClient(K8S::Kubernetes::Resource).new(transport, api_client, api_resource, namespace, K8S::Kubernetes::Resource)
        end
      end
    end

    define_new

    def initialize(@transport, @api_client, @api_resource, @namespace, @resource_class)
      @logger = ::Log.for("Kube::ResourceClient(#{@resource_class}")
      if @api_resource.name.includes? "/"
        @resource, @subresource = @api_resource.name.split("/", 2)
      else
        @resource = @api_resource.name
        @subresource = nil
      end

      fail("Resource #{api_resource.name} is not namespaced") unless api_resource.namespaced || !namespace
    end

    def api_version : String
      @api_client.api_version
    end

    # resource or resource/subresource
    def name : String
      @api_resource.name
    end

    def kind
      @api_resource.kind
    end

    def subresource?
      !!@subresource
    end

    def path(name = nil, subresource = @subresource, namespace = @namespace)
      namespace_part = namespace ? ["namespaces", namespace] : [] of String

      if name && subresource
        @api_client.path(*namespace_part, @resource, name, subresource)
      elsif name
        @api_client.path(*namespace_part, @resource, name)
      else
        @api_client.path(*namespace_part, @resource)
      end
    end

    def create?
      @api_resource.verbs.include? "create"
    end

    # @param resource [#metadata] with metadata.namespace and metadata.name set
    # @return [Object] instance of resource_class
    def create_resource(resource : T)
      @transport.request(
        method: "POST",
        path: path(namespace: resource.metadata.namespace),
        request_object: resource,
        response_class: @resource_class
      )
    end

    # @return [Bool]
    def get? : Bool
      @api_resource.verbs.include? "get"
    end

    # @param name [String]
    # @param namespace [String, NilClass]
    # @return [Object] instance of resource_class
    def get(name, namespace = @namespace)
      @transport.request(
        method: "GET",
        path: path(name, namespace: namespace),
        response_class: @resource_class
      )
    end

    # @param resource [resource_class]
    # @return [Object] instance of resource_class
    def get_resource(resource)
      @transport.request(
        method: "GET",
        path: path(resource.metadata.name, namespace: resource.metadata.namespace),
        response_class: @resource_class
      )
    end

    # @return [Bool]
    def list?
      @api_resource.verbs.include? "list"
    end

    # @param list [K8s::Resource]
    # @return [Array<Object>] array of instances of resource_class
    def process_list(list)
      list.items.map { |item|
        # list items omit kind/apiVersion
        @resource_class.new(item.merge({"apiVersion" => list.apiVersion, "kind" => @api_resource.kind}))
      }
    end

    # @return [Array<Object>] array of instances of resource_class
    def list(label_selector : String | Hash(String, String) | Nil = nil, field_selector : String | Hash(String, String) | Nil = nil, namespace = @namespace)
      list = meta_list(label_selector: label_selector, field_selector: field_selector, namespace: namespace)
      process_list(list)
    end

    def meta_list(label_selector : String | Hash(String, String) | Nil = nil, field_selector : String | Hash(String, String) | Nil = nil, namespace = @namespace)
      @transport.request(
        method: "GET",
        path: path(namespace: namespace),
        query: make_query({
          "labelSelector" => selector_query(label_selector),
          "fieldSelector" => selector_query(fieldSelector),
        })
      )
    end

    def watch(label_selector : String | Hash(String, String) | Nil = nil,
              field_selector : String | Hash(String, String) | Nil = nil,
              resource_version : String? = nil, timeout : Int32 = nil, namespace = @namespace)
      # TODO: add watch
    end

    # @return [Boolean]
    def update?
      @api_resource.verbs.include? "update"
    end

    # @param resource [#metadata] with metadata.resourceVersion set
    # @return [Object] instance of resource_class
    def update_resource(resource)
      @transport.request(
        method: "PUT",
        path: path(resource.metadata.name, namespace: resource.metadata.namespace),
        request_object: resource,
        response_class: @resource_class
      )
    end

    # @return [Boolean]
    def patch?
      @api_resource.verbs.include? "patch"
    end

    # @param name [String]
    # @param obj [#to_json]
    # @param namespace [String, nil]
    # @param strategic_merge [Boolean] use kube Strategic Merge Patch instead of standard Merge Patch (arrays of objects are merged by name)
    # @return [Object] instance of resource_class
    def merge_patch(name, obj, namespace = @namespace, strategic_merge = true)
      @transport.request(
        method: "PATCH",
        path: path(name, namespace: namespace),
        content_type: strategic_merge ? "application/strategic-merge-patch+json" : "application/merge-patch+json",
        request_object: obj,
        response_class: @resource_class
      )
    end

    # @param name [String]
    # @param ops [Hash] json-patch operations
    # @param namespace [String, nil]
    # @return [Object] instance of resource_class
    def json_patch(name, ops, namespace = @namespace)
      @transport.request(
        method: "PATCH",
        path: path(name, namespace: namespace),
        content_type: "application/json-patch+json",
        request_object: ops,
        response_class: @resource_class
      )
    end

    # @return [Boolean]
    def delete?
      @api_resource.verbs.include? "delete"
    end

    # @param name [String]
    # @param namespace [String, nil]
    # @param propagationPolicy [String, nil] The propagationPolicy to use for the API call. Possible values include “Orphan”, “Foreground”, or “Background”
    # @return [K8s::Resource]
    def delete(name, namespace = @namespace, propagation_policy = nil)
      @transport.request(
        method: "DELETE",
        path: path(name, namespace: namespace),
        query: make_query(
          {"propagationPolicy" => propagation_policy}
        ),
        response_class: @resource_class
      )
    end

    # @return [Array<Object>] array of instances of resource_class
    def delete_collection(namespace = @namespace,
                          label_selector : String | Hash(String, String) | Nil = nil,
                          field_selector : String | Hash(String, String) | Nil = nil,
                          propagation_policy : String? = nil)
      list = @transport.request(
        method: "DELETE",
        path: path(namespace: namespace),
        query: make_query({
          "labelSelector"     => selector_query(label_selector),
          "fieldSelector"     => selector_query(field_selector),
          "propagationPolicy" => propagation_policy,
        })
      )
      process_list(list)
    end

    # @param resource [resource_class] with metadata
    # @param options [Hash]
    # @see #delete for possible options
    # @return [K8s::Resource]
    def delete_resource(resource, **options)
      delete(resource.metadata.name, **options.merge({namespace: resource.metadata.namespace}))
    end
  end
end
