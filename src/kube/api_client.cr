require "spoved/logger"
require "./transport"

module Kube
  class ApiClient
    spoved_logger
    private getter transport : Transport
    getter api_version : String

    @api_resources : Array(K8S::Apimachinery::Apis::Meta::V1::APIResource)? = nil

    # *api_version* : either core version (v1) or apigroup/apiversion (apps/v1)
    def self.path(api_version : String) : String
      if api_version.includes? "/"
        File.join("/apis", api_version)
      else
        File.join("/api", api_version)
      end
    end

    def initialize(@transport : Transport, @api_version : String); end

    def path(*path)
      @transport.path(self.class.path(@api_version), *path)
    end

    # api_resources loaded yet?
    def api_resources? : Bool
      !@api_resources.nil?
    end

    # Force-update APIResources
    def api_resources! : Array(K8S::Apimachinery::Apis::Meta::V1::APIResource)
      logger.trace { "Loading API resources for #{path}" }
      @api_resources = @transport.get(
        path,
        response_class: K8S::Apimachinery::Apis::Meta::V1::APIResourceList
      ).as(K8S::Apimachinery::Apis::Meta::V1::APIResourceList).resources
      logger.trace { "Loaded #{@api_resources.not_nil!.size} API resources for #{path}" }
      @api_resources.not_nil!
    end

    # Cached APIResources
    def api_resources : Array(K8S::Apimachinery::Apis::Meta::V1::APIResource)
      @api_resources || api_resources!
    end

    # raises `K8s::Error::UndefinedResource` if resource not found
    def find_api_resource(resource_name)
      found_resource = api_resources.find { |api_resource| api_resource.name == resource_name }
      found_resource ||= find_api_resource_by_kind(resource_name)
      raise Kube::Error::UndefinedResource.new("Unknown resource #{resource_name} for #{@api_version}") unless found_resource
      found_resource
    end

    # raises `K8s::Error::UndefinedResource` if resource not found
    def find_api_resource_by_kind(kind)
      found_resource = api_resources.find { |api_resource| api_resource.kind == kind }
      raise Kube::Error::UndefinedResource.new("Unknown resource kind: #{kind} for #{@api_version}") unless found_resource
      found_resource
    end

    def resource(resource_name, namespace : String? = nil) : ResourceClient
      client_for_resource(find_api_resource(resource_name), namespace: namespace)
    end

    def client_for_resource(kind : String, namespace : String? = nil)
      # raise Kube::Error::UndefinedResource.new("Invalid apiVersion=#{api_version} for #{@api_version} client") unless api_version == @api_version
      logger.trace &.emit "client_for_resource", api_version: @api_version, kind: kind, namespace: namespace
      klass = k8s_resource_class("", @api_version, kind)
      raise K8S::Error::UnknownResource.new("Resource #{kind} is not available in #{@api_version}") unless klass
      client_for_resource(klass, namespace)
    rescue ex : K8S::Error::UnknownResource
      raise Kube::Error::UndefinedResource.new("Resource #{kind} is not available in #{@api_version}")
    end

    def client_for_resource(resource : X.class, namespace : String? = nil, api_resource : K8S::Apimachinery::Apis::Meta::V1::APIResource? = nil) forall X
      found_resource = api_resource || find_api_resource_by_kind(resource.kind)
      logger.trace &.emit "client_for_resource", resource: resource.to_s, namespace: namespace, api_resource: api_resource ? api_resource.kind : nil

      {% if X.abstract? %}
        case resource.kind
        {% for y in X.all_subclasses %}{% if !y.abstract? && !(y < K8S::Kubernetes::Resource::List) %}
        when {{y}}.kind
          ::Kube::ResourceClient({{y}}).new(@transport, self, found_resource, namespace)
        {% end %}{% end %}
        else
          ::Kube::ResourceClient(X).new(@transport, self, found_resource, namespace)
        end
      {% else %}
        ::Kube::ResourceClient(X).new(@transport, self, found_resource, namespace)
      {% end %}
    rescue ex : K8S::Error::UnknownResource
      raise Kube::Error::UndefinedResource.new("Resource #{resource.kind} is not available in #{@api_version}")
    end

    def client_for_resource(resource : K8S::Apimachinery::Apis::Meta::V1::APIResource, namespace : String? = nil)
      if resource.name.includes? "/"
        client_for_subresource(resource, namespace)
      else
        logger.trace &.emit "client_for_resource", api_resouce: resource.to_json, namespace: namespace
        klass = K8S::Util.get_resource_klass({api_version: @api_version, kind: resource.kind})
        raise K8S::Error::UnknownResource.new("Resource #{resource.kind} is not available in #{@api_version}") unless klass
        client_for_resource(klass, namespace: namespace, api_resource: resource)
      end
    rescue ex : K8S::Error::UnknownResource
      logger.trace &.emit "client_for_resource: unable to find resouce", api_resouce: resource.to_json, namespace: namespace
      ::Kube::ResourceClient(K8S::Kubernetes::Resource::Generic).new(@transport, self, resource, namespace)
    end

    def client_for_subresource(resource : K8S::Apimachinery::Apis::Meta::V1::APIResource, namespace : String? = nil)
      parent, subresource = resource.name.split("/", 2)
      logger.trace &.emit "client_for_subresource", parent: parent, subresource: subresource, namespace: namespace
      # TODO: implement subresource clients
      ::Kube::ResourceClient(K8S::Kubernetes::Resource::Generic).new(@transport, self, resource, namespace)
    end

    # If namespace is given, non-namespaced resources will be skipped
    def resources(namespace : String? = nil)
      api_resources.map do |ar|
        if ar.namespaced
          client_for_resource(ar, namespace: namespace)
        elsif namespace.nil?
          client_for_resource(ar)
        else
          nil
        end
      end.reject(Nil)
    end

    # Pipeline list requests for multiple resource types.
    #
    # Returns flattened array with mixed resource kinds.
    def list_resources(resource_list : Array(Kube::ResourceClient)? = nil, **options) : Indexable
      logger.trace { "list_resources(#{resource_list}, #{options})" }

      if options[:namespace]?
        resource_list ||= self.resources.select(&.list?).select(&.namespaced?).reject(&.subresource?)
      else
        resource_list ||= self.resources.select(&.list?).reject(&.subresource?)
      end
      ResourceClient.list(resource_list, @transport, **options)
    end
  end
end
