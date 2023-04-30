require "./transport"
require "./api_client"

module Kube
  # Per-APIResource type client.
  #
  # Used to get/list/update/patch/delete specific types of resources, optionally in some specific namespace.
  class ResourceClient(T)
    @@logger = ::Log.for("kube.resource_client")
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
                  label_selector = nil, field_selector = nil, skip_forbidden = false) : Indexable
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

      # resources.each { |r| logger.warn { r.class } }
      # api_paths.zip(resources.map(&.class)).each { |x, r| logger.warn { "list: #{x} => #{r}" } }

      resources.zip(api_lists).flat_map do |resource, api_list|
        logger.trace &.emit "listing #{resource.class}", namespace: namespace, label_selector: label_selector, field_selector: field_selector
        if api_list.nil?
          api_list
        elsif api_list.is_a?(K8S::Kubernetes::Resource::List)
          begin
            resource.process_list(api_list).each.flatten
          rescue ex
            logger.error &.emit "error listing #{resource.class}", namespace: namespace, label_selector: label_selector, field_selector: field_selector
            raise ex
          end
        else
          raise "unexpected response type: #{api_list.class}"
        end
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
    getter? namespaced : Bool

    def initialize(@transport, @api_client, @api_resource, @namespace = nil)
      @logger = ::Log.for("kube.resource_client - #{T}")

      if @api_resource.name.includes? "/"
        @resource, @subresource = @api_resource.name.split("/", 2)
      else
        @resource = @api_resource.name
        @subresource = nil
      end
      @namespaced = @api_resource.namespaced

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
        response_class: T
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
        response_class: T
      ).as(T)
    end

    # returns response body as a String instead of T
    def get_as_string(name, namespace = @namespace)
      @transport.request(
        method: "GET",
        path: path(name, namespace: namespace),
        response_class: T
      ).as(String)
    end

    # raises [`Kube::Error::NotFound`] if resource is not found
    def get(resource : T) : T
      @transport.request(
        method: "GET",
        path: path(resource.metadata!.name, namespace: resource.metadata!.namespace),
        response_class: T
      ).as(T)
    end

    def list?
      @api_resource.verbs.includes? "list"
    end

    def process_list(list : X) : Indexable(T) forall X
      {% if X >= K8S::Kubernetes::Resource::List(T) %}
        list.as(K8S::Kubernetes::Resource::List).items.map { |item| item.as(T) }
      {% else %}
        logger.error { "Unexpected list type: #{list.class}" }
        K8S::Kubernetes::Resource::List(T).new
      {% end %}
    rescue ex
      raise ex
    end

    # returns array of instances of resource_class
    def list(label_selector : String | Hash(String, String) | Nil = nil,
             field_selector : String | Hash(String, String) | Nil = nil, namespace = @namespace) : Indexable(T)
      list = meta_list(label_selector: label_selector, field_selector: field_selector, namespace: namespace)
      process_list(list)
    end

    def meta_list(label_selector : String | Hash(String, String) | Nil = nil, field_selector : String | Hash(String, String) | Nil = nil, namespace = @namespace) : K8S::Kubernetes::Resource::List(T)
      @transport.request(
        method: "GET",
        path: path(namespace: namespace),
        query: make_query({
          "labelSelector" => selector_query(label_selector),
          "fieldSelector" => selector_query(field_selector),
        })
      ).as(K8S::Kubernetes::Resource::List(T))
    end

    def watch(label_selector : String | Hash(String, String) | Nil = nil,
              field_selector : String | Hash(String, String) | Nil = nil,
              timeout : Int32? = nil, namespace = @namespace) : Kube::WatchChannel(T)
      _list = meta_list(label_selector: label_selector, field_selector: field_selector, namespace: namespace)
      resource_version = _list.metadata!["resourceVersion"]?.try &.as(String)
      _watch_channel = Kube::WatchChannel(T).new(@transport, resource_version)

      # If we have a list, send the items to the channel before we start watching
      if _list.is_a?(K8S::Kubernetes::Resource::List(T))
        spawn do
          _list.items.each do |item|
            watch_event = {% if ::K8S::Kubernetes::VERSION_MINOR == 1 && ::K8S::Kubernetes::VERSION_MAJOR < 16 %}
                            ::K8S::Kubernetes::WatchEvent(T).from_json(
                              {type: "ADDED", object_raw: item.to_json}.to_json
                            )
                          {% else %}
                            ::K8S::Kubernetes::WatchEvent(T).new(::K8S::Apimachinery::Apis::Meta::V1::WatchEvent.new(
                              type: "ADDED",
                              object: item,
                            ))
                          {% end %}
            _watch_channel.channel.send(watch_event)
          end
        end
      end

      query = make_query({
        "labelSelector"   => selector_query(label_selector),
        "fieldSelector"   => selector_query(field_selector),
        "resourceVersion" => resource_version,
        "timeoutSeconds"  => timeout.nil? ? nil : timeout.to_s,
        "watch"           => "true",
      })
      _start_watch(_watch_channel, query, namespace)
    end

    # Will resume a watch from a given resource version
    def watch(resource_version : String, label_selector : String | Hash(String, String) | Nil = nil,
              field_selector : String | Hash(String, String) | Nil = nil,
              timeout : Int32? = nil, namespace = @namespace) : Kube::WatchChannel(T)
      query = make_query({
        "labelSelector"   => selector_query(label_selector),
        "fieldSelector"   => selector_query(field_selector),
        "resourceVersion" => resource_version,
        "timeoutSeconds"  => timeout.nil? ? nil : timeout.to_s,
        "watch"           => "true",
      })
      _watch_channel = Kube::WatchChannel(T).new(@transport, resource_version)
      _start_watch(_watch_channel, query, namespace)
    end

    def watch(auto_resume = false, **nargs, &block)
      channel = watch(**nargs)
      while !channel.closed?
        event = channel.receive
        if event.is_a?(Kube::Error::WatchClosed) && auto_resume
          rv = event.resource_version
          raise event if rv.nil?
          logger.debug &.emit "Watch channel closed, resuming", resource_version: rv, response_code: event.code
          channel = watch(**nargs, resource_version: rv)
        elsif event.is_a?(Kube::Error::API)
          raise event
        else
          yield event
        end
      end
    end

    private def _start_watch(_watch_channel, query, namespace)
      logger.debug &.emit "Start watch", path: path(namespace: namespace), query: query, resource_version: _watch_channel.resource_version

      @transport.watch_request(
        path: path(namespace: namespace),
        query: query,
        response_class: K8S::Kubernetes::WatchEvent(T),
        response_channel: _watch_channel,
      )
      _watch_channel
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
        response_class: T
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
        response_class: T
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
        response_class: T
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
        response_class: T,
      ).as(T)
    end

    # returns array of instances of resource_class
    def delete_collection(namespace = @namespace,
                          label_selector : String | Hash(String, String) | Nil = nil,
                          field_selector : String | Hash(String, String) | Nil = nil,
                          propagation_policy : String? = nil) : Indexable(T)
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
