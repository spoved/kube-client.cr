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
      @api_resources = @transport.get(
        path,
        response_class: K8S::Apimachinery::Apis::Meta::V1::APIResourceList
      ).as(K8S::Apimachinery::Apis::Meta::V1::APIResourceList).resources
    end

    # Cached APIResources
    def api_resources : Array(K8S::Apimachinery::Apis::Meta::V1::APIResource)
      @api_resources || api_resources!
    end

    # raises `K8s::Error::UndefinedResource` if resource not found
    def find_api_resource(resource_name)
      found_resource = api_resources.find { |api_resource| api_resource.name == resource_name }
      found_resource ||= api_resources!.find { |api_resource| api_resource.name == resource_name }
      raise Kube::Error::UndefinedResource.new("Unknown resource #{resource_name} for #{@api_version}") unless found_resource

      found_resource
    end

    def resource(resource_name, namespace : String? = nil) : ResourceClient
      ResourceClient.new(@transport, self, find_api_resource(resource_name), namespace: namespace)
    end

    def client_for_resource(api_version : String, kind : String, namespace : String? = nil)
      unless @api_version == api_version
        raise Kube::Error::UndefinedResource.new("Invalid apiVersion=#{api_version} for #{@api_version} client")
      end

      found_resource = api_resources.find { |api_resource| api_resource.kind == kind }
      found_resource ||= api_resources!.find { |api_resource| api_resource.kind == kind }
      raise Kube::Error::UndefinedResource.new("Unknown resource kind=#{kind} for #{@api_version}") unless found_resource

      ResourceClient.new(@transport, self, found_resource, namespace: namespace)
    end

    def client_for_resource(resource : T, namespace : String? = nil) : ResourceClient(T) forall T
      if resource.is_a?(::K8S::Kubernetes::Resource::Object)
        client_for_resource(resource.api_version, resource.kind, resource.metadata.try(&.namespace) || namespace)
      else
        client_for_resource(resource.api_version, resource.kind, namespace)
      end
    end

    # If namespace is given, non-namespaced resources will be skipped
    def resources(namespace : String? = nil)
      api_resources.map do |api_resource|
        if api_resource.namespaced
          ResourceClient.new(@transport, self, api_resource, namespace: namespace)
        elsif namespace.nil?
          ResourceClient.new(@transport, self, api_resource)
        else
          nil
        end
      end.reject(Nil)
    end

    # Pipeline list requests for multiple resource types.
    #
    # Returns flattened array with mixed resource kinds.
    def list_resources(resources : Array(Kube::ResourceClient)? = nil, **options) : Array(K8S::Resource)
      Log.trace { "list_resources(#{resources}, #{options})" }
      resources ||= self.resources.select(&.list?)
      ResourceClient.list(resources, @transport, **options)
    end
  end
end
