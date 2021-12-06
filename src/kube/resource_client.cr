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

    # Pipeline list requests for multiple resource types.
    #
    # Returns flattened array with mixed resource kinds.
    #
    # `skip_forbidden` [Boolean] skip resources that return HTTP 403 errors
    def self.list(resources : Array(ResourceClient), transport : Transport, namespace : String? = nil,
                  label_selector = nil, field_selector = nil, skip_forbidden = false) : Array(K8S::Resource)
      api_paths = resources.map(&.path(namespace: namespace))

      api_lists = transport.gets(
        api_paths,
        response_class: K8S::Kubernetes::Resource,
        query: make_query({
          "labelSelector" => selector_query(label_selector),
          "fieldSelector" => selector_query(field_selector),
        }),
        skip_forbidden: skip_forbidden
      )

      # api_lists.each { |r| puts r.class }
      # resources.zip(api_lists)
      resources.zip(api_lists).flat_map do |resource, api_list|
        api_list ? resource.process_list(api_list) : [] of K8S::Kubernetes::Resource
      end.reject(Nil)
    end

    module Utils
      # @param selector [NilClass, String, Hash{String => String}]
      # @return [NilClass, String]
      def selector_query(selector : String | Symbol | Hash(String, String) | Nil) : String?
        case selector
        when Nil
          nil
        when Symbol
          selector.to_s
        when String
          selector
        when Hash
          selector.map { |k, v| "#{k}=#{v}" }.join ","
        else
          raise Kube::Error.new "Invalid selector type. #{selector.inspect}"
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
        klass = k8s_resource_class(group, ver, api_resource.kind)
        case klass
        {% for resource in K8S::Kubernetes::Resource.all_subclasses %}
        {% if !resource.abstract? && resource.annotation(::K8S::GroupVersionKind) %}
        when {{resource.id}}.class
          ::Kube::ResourceClient({{resource.id}}).new(transport, api_client, api_resource, namespace, {{resource.id}})
        {% end %}{% end %}
        else
          raise Kube::Error::UndefinedResource.new("Unknown resource kind: #{klass.inspect}")
        end
      rescue ex : K8S::Error::UnknownResource
        ::Kube::ResourceClient(K8S::Kubernetes::Resource).new(transport, api_client, api_resource, namespace, K8S::Kubernetes::Resource)
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

      raise Kube::Error.new("Resource #{api_resource.name} is not namespaced") unless api_resource.namespaced || !namespace
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
      namespace_part = namespace ? {"namespaces", namespace} : {"", ""}

      if name && subresource
        @api_client.path(*namespace_part, @resource, name, subresource)
      elsif name
        @api_client.path(*namespace_part, @resource, name)
      else
        @api_client.path(*namespace_part, @resource)
      end
    end

    def create? : Bool
      @api_resource.verbs.includes? "create"
    end

    # @param resource [#metadata] with metadata.namespace and metadata.name set
    # @return [Object] instance of resource_class
    def create_resource(resource : T) : T
      @transport.request(
        method: "POST",
        path: path(namespace: resource.metadata!.namespace),
        request_object: resource,
        response_class: @resource_class
      ).as(T)
    end

    # @return [Bool]
    def get? : Bool
      @api_resource.verbs.includes? "get"
    end

    # @raise [`Kube::Error::NotFound`] if resource is not found
    def get(name, namespace = @namespace) : T
      @transport.request(
        method: "GET",
        path: path(name, namespace: namespace),
        response_class: @resource_class
      ).as(T)
    end

    # @raise [`Kube::Error::NotFound`] if resource is not found
    def get(resource : T) : T
      @transport.request(
        method: "GET",
        path: path(resource.metadata!.name, namespace: resource.metadata!.namespace),
        response_class: @resource_class
      ).as(T)
    end

    # @return [Bool]
    def list?
      @api_resource.verbs.includes? "list"
    end

    # @param list [K8s::Resource]
    # @return [Array<Object>] array of instances of resource_class
    def process_list(list) : Array(T)
      if (list.is_a?(K8S::Kubernetes::ResourceList(T)))
        list.items
      else
        Array(T).new
      end
    end

    # @return [Array<Object>] array of instances of resource_class
    def list(label_selector : String | Hash(String, String) | Nil = nil,
             field_selector : String | Hash(String, String) | Nil = nil, namespace = @namespace) : Array(T)
      list = meta_list(label_selector: label_selector, field_selector: field_selector, namespace: namespace)
      process_list(list)
    end

    def meta_list(label_selector : String | Hash(String, String) | Nil = nil, field_selector : String | Hash(String, String) | Nil = nil, namespace = @namespace)
      @transport.request(
        method: "GET",
        path: path(namespace: namespace),
        query: make_query({
          "labelSelector" => selector_query(label_selector),
          "fieldSelector" => selector_query(field_selector),
        })
      )
    end

    def watch(label_selector : String | Hash(String, String) | Nil = nil,
              field_selector : String | Hash(String, String) | Nil = nil,
              resource_version : String? = nil, timeout : Int32 = nil, namespace = @namespace)
      # TODO: add watch
    end

    # @return [Boolean]
    def update? : Bool
      @api_resource.verbs.includes? "update"
    end

    # @param resource [#metadata] with metadata.resourceVersion set
    # @return [Object] instance of resource_class
    def update_resource(resource : T) : T
      @transport.request(
        method: "PUT",
        path: path(resource.metadata!.name, namespace: resource.metadata!.namespace),
        request_object: resource,
        response_class: @resource_class
      ).as(T)
    end

    # @return [Boolean]
    def patch? : Bool
      @api_resource.verbs.includes? "patch"
    end

    # @param name [String]
    # @param obj [#to_json]
    # @param namespace [String, nil]
    # @param strategic_merge [Boolean] use kube Strategic Merge Patch instead of standard Merge Patch (arrays of objects are merged by name)
    # @return [Object] instance of resource_class
    def merge_patch(name, obj, namespace = @namespace, strategic_merge = true) : T
      @transport.request(
        method: "PATCH",
        path: path(name, namespace: namespace),
        content_type: strategic_merge ? "application/strategic-merge-patch+json" : "application/merge-patch+json",
        request_object: obj,
        response_class: @resource_class
      ).as(T)
    end

    # @param name [String]
    # @param ops [Hash] json-patch operations
    # @param namespace [String, nil]
    # @return [Object] instance of resource_class
    def json_patch(name, ops, namespace = @namespace) : T
      @transport.request(
        method: "PATCH",
        path: path(name, namespace: namespace),
        content_type: "application/json-patch+json",
        request_object: ops,
        response_class: @resource_class
      ).as(T)
    end

    def delete? : Bool
      @api_resource.verbs.includes? "delete"
    end

    # @param name [String]
    # @param namespace [String, nil]
    # @param propagationPolicy [String, nil] The propagationPolicy to use for the API call. Possible values include “Orphan”, “Foreground”, or “Background”
    # @return [K8s::Resource]
    def delete(name, namespace = @namespace, propagation_policy = nil) : T
      @transport.request(
        method: "DELETE",
        path: path(name, namespace: namespace),
        query: make_query(
          {"propagationPolicy" => propagation_policy}
        ),
        response_class: @resource_class,
      ).as(T)
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
    def delete_resource(resource : T, **options)
      delete(resource.metadata!.name, **options.merge({namespace: resource.metadata!.namespace}))
    end
  end
end
