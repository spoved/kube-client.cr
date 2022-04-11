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

      def make_query(options) : Hash(String, String | Array(String))?
        query = Hash(String, String | Array(String)).new
        options.each do |k, v|
          query[k] = v unless v.nil?
        end
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
      # ameba:disable Style/NegatedConditionsInUnless
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

    # resource [#metadata] with metadata.namespace and metadata.name set
    def create_resource(resource : T) : T
      @transport.request(
        method: "POST",
        path: path(namespace: resource.metadata!.namespace),
        request_object: resource,
        response_class: @resource_class
      ).as(T)
    end

    def get? : Bool
      @api_resource.verbs.includes? "get"
    end

    # raises [`Kube::Error::NotFound`] if resource is not found
    def get(name, namespace = @namespace) : T
      @transport.request(
        method: "GET",
        path: path(name, namespace: namespace),
        response_class: @resource_class
      ).as(T)
    end

     # returns response body as a String instead of T
     def get_as_string(name, namespace = @namespace)
      @transport.request(
        method: "GET",
        path: path(name, namespace: namespace),
        response_class: @resource_class
      ).as(String)
    end

    # raises [`Kube::Error::NotFound`] if resource is not found
    def get(resource : T) : T
      @transport.request(
        method: "GET",
        path: path(resource.metadata!.name, namespace: resource.metadata!.namespace),
        response_class: @resource_class
      ).as(T)
    end

    def list?
      @api_resource.verbs.includes? "list"
    end

    def process_list(list) : Array(T)
      if (list.is_a?(K8S::Kubernetes::ResourceList(T)))
        list.items
      else
        Array(T).new
      end
    end

    # returns array of instances of resource_class
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
              resource_version : String? = nil, timeout : Int32? = nil,
              namespace = @namespace)
      channel = Channel(::K8S::WatchEvent(T) | Kube::Error::API).new
      query = make_query({
        "labelSelector"   => selector_query(label_selector),
        "fieldSelector"   => selector_query(field_selector),
        "resourceVersion" => resource_version,
        "timeoutSeconds"  => timeout,
        "watch"           => "true",
      })
      logger.warn { "Watching #{query}" }
      @transport.watch_request(
        path: path(namespace: namespace),
        query: query,
        response_class: ::K8S::WatchEvent(T),
        response_channel: channel,
      )
      channel
    end

    def update? : Bool
      @api_resource.verbs.includes? "update"
    end

    # returns instance of resource_class
    def update_resource(resource : T) : T
      @transport.request(
        method: "PUT",
        path: path(resource.metadata!.name, namespace: resource.metadata!.namespace),
        request_object: resource,
        response_class: @resource_class
      ).as(T)
    end

    def patch? : Bool
      @api_resource.verbs.includes? "patch"
    end

    # name [String]
    # obj [#to_json]
    # namespace [String, nil]
    # strategic_merge [Boolean] use kube Strategic Merge Patch instead of standard Merge Patch (arrays of objects are merged by name)
    def merge_patch(name, obj, namespace = @namespace, strategic_merge = true) : T
      @transport.request(
        method: "PATCH",
        path: path(name, namespace: namespace),
        content_type: strategic_merge ? "application/strategic-merge-patch+json" : "application/merge-patch+json",
        request_object: obj,
        response_class: @resource_class
      ).as(T)
    end

    # name [String]
    # ops [Hash] json-patch operations
    # namespace [String, nil]
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

    # name [String]
    # namespace [String, nil]
    # propagationPolicy [String, nil] The propagationPolicy to use for the API call. Possible values include “Orphan”, “Foreground”, or “Background”
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

    # returns array of instances of resource_class
    def delete_collection(namespace = @namespace,
                          label_selector : String | Hash(String, String) | Nil = nil,
                          field_selector : String | Hash(String, String) | Nil = nil,
                          propagation_policy : String? = nil) : Array(T)
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

    # resource [resource_class] with metadata
    # options [Hash]
    # see #delete for possible options
    def delete_resource(resource : T, **options)
      delete(resource.metadata!.name, **options.merge({namespace: resource.metadata!.namespace}))
    end
  end
end
