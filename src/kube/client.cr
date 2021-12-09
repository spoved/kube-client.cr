require "spoved/logger"
require "spoved/system_cmd"
require "./types"
require "./transport"
require "./config"

module Kube
  spoved_logger

  def self.client(**options) : Kube::Client
    Client.new(Transport.new(**options))
  end

  # Top-level client wrapper.
  # Uses a `Transport` instance to talk to the kube API.
  # Offers access to `Kube::ApiClient` and `ResourceClient` instances.
  class Client
    spoved_logger
    @mutex = Mutex.new
    @version : K8S::Apimachinery::Version::Info? = nil

    def self.config(config : Kube::Config, namespace : String? = nil, **options) : Kube::Client
      Client.new(Transport.config(config, **options), namespace)
    end

    # An `Kube::Client` instance from in-cluster config within a kube pod, using the kubernetes service envs and serviceaccount secrets
    def self.in_cluster_config(namespace : String? = nil, **options) : Kube::Client
      Client.new(Transport.in_cluster_config(**options), namespace)
    end

    # Attempts to create a K8s::Client instance automatically using environment variables, existing configuration
    # files or in cluster configuration.
    #
    # Look-up order:
    #   - KUBE_TOKEN, KUBE_CA, KUBE_SERVER environment variables
    #   - KUBECONFIG environment variable
    #   - $HOME/.kube/config file
    #   - In cluster configuration
    #
    # Will raise when no means of configuration is available
    def self.autoconfig(namespace : String? = nil, **options) : Kube::Client
      config = if ENV.has_key?("KUBE_TOKEN") && ENV.has_key?("KUBE_CA") && ENV.has_key?("KUBE_SERVER")
                 kube_ca = Base64.decode_string(ENV["KUBE_CA"])
                 unless kube_ca =~ /CERTIFICATE/
                   raise "KUBE_CA does not seem to be base64 encoded"
                 end
                 kube_token = Base64.decode_string(ENV["KUBE_TOKEN"])
                 kube_server = ENV["KUBE_SERVER"]
                 Kube::Config.build(kube_server, kube_ca, kube_token)
               elsif ENV.has_key?("KUBECONFIG")
                 Kube::Config.from_kubeconfig_env
               else
                 found_config = [
                   File.join(Path.home, ".kube", "config"),
                   "/etc/kubernetes/admin.conf",
                   "/etc/kubernetes/kubelet.conf",
                 ].find { |path| File.exists?(path) && File.readable?(path) }
                 if found_config
                   Kube::Config.load_file(found_config)
                 else
                   nil
                 end
               end

      if config.nil?
        self.in_cluster_config
      else
        self.config(config, namespace, **options)
      end
    end

    private getter transport : Kube::Transport

    # default namespace for all operations
    private getter namespace : String? = nil

    private getter api_clients : Hash(String, Kube::ApiClient) = Hash(String, Kube::ApiClient).new
    getter api_groups : Array(String)? = nil

    def initialize(@transport : Kube::Transport, @namespace : String? = nil); end

    # @raise [K8s::Error]
    # @return [K8s::Resource]
    def version : K8S::Apimachinery::Version::Info
      @version ||= @transport.version
    end

    # @param api_version [String] "group/version" or "version" (core)
    def api(api_version : String = "v1") : Kube::ApiClient
      self.api_clients[api_version] ||= Kube::ApiClient.new(@transport, api_version)
    end

    # Force-update /apis cache.
    # Required if creating new CRDs/apiservices.
    def api_groups! : Array(String)
      @mutex.synchronize do
        @api_groups = @transport.get(
          "/apis",
          response_class: K8S::Apimachinery::Apis::Meta::V1::APIGroupList
        ).as(K8S::Apimachinery::Apis::Meta::V1::APIGroupList)
          .groups.flat_map(&.versions.map(&.group_version))

        @api_clients.clear
      end

      @api_groups.not_nil!
    end

    # Cached /apis preferred group apiVersions
    def api_groups : Array(String)
      @api_groups || api_groups!
    end

    # @param api_versions [Array<String>] defaults to all APIs
    # @param prefetch_resources [Boolean] prefetch any missing api_resources for each api_version
    # @param skip_missing [Boolean] return Kube::ApiClient without api_resources? if 404
    # @return [Array<Kube::ApiClient>]
    def apis(api_versions = nil, prefetch_resources = false, skip_missing = false)
      api_versions ||= ["v1"] + api_groups

      if prefetch_resources
        # api groups that are missing their api_resources
        api_paths = api_versions
          .uniq
          .reject { |api_version| api(api_version).api_resources? }
          .map { |api_version| Kube::ApiClient.path(api_version) }

        # load into Kube::ApiClient.api_resources=
        begin
          @transport.gets(api_paths, response_class: K8S::Apimachinery::Apis::Meta::V1::APIResourceList, skip_missing: skip_missing).each do |api_resource_list|
            if api_resource_list && api_resource_list.is_a?(K8S::Apimachinery::Apis::Meta::V1::APIResource)
              api(api_resource_list.group_version).api_resources = api_resource_list.resources
            end
          end
        rescue ex : Kube::Error::NotFound | Kube::Error::ServiceUnavailable
          logger.error { ex.message }
          # kubernetes api is in unstable state
          # because this is only performance optimization, better to skip prefetch and move on
        end
      end

      api_versions.map { |api_version| api(api_version) }
    end

    # @param namespace [String, nil]
    def resources(namespace : String? = nil)
      apis(prefetch_resources: true).flat_map { |api|
        begin
          api.resources(namespace: namespace)
        rescue ex : Kube::Error::ServiceUnavailable | Kube::Error::NotFound
          logger.error { ex.message }
          Array(Kube::ResourceClient(K8S::Kubernetes::Resource)).new
        end
      }
    end

    # Pipeline list requests for multiple resource types.
    #
    # Returns flattened array with mixed resource kinds.
    def list_resources(resources : Array(Kube::ResourceClient)? = nil, **options)
      logger.trace { "list_resources(#{resources}, #{options})" }
      resources ||= self.resources.select(&.list?)
      ResourceClient.list(resources, @transport, **options)
    rescue ex : Kube::Error::NotFound
      logger.error { ex.message }
      raise ex
    end

    def client_for_resource(resource : T, namespace : String? = nil) forall T
      api(resource.api_version).client_for_resource(resource, namespace: namespace)
    end

    def create_resource(resource : T) forall T
      client_for_resource(resource).create_resource(resource)
    end

    def get_resource(resource : T) forall T
      client_for_resource(resource).get_resource(resource)
    end

    def get_resources(resources : Enumerable(T)) forall T
      # prefetch api resources, skip missing APIs
      resource_apis = apis(resources.map(&.api_version), prefetch_resources: true, skip_missing: true)

      # map each resource to  request options, or nil if resource is not (yet) defined
      requests = resources.zip(resource_apis).map { |resource, api_client|
        next nil unless api_client.api_resources?

        resource_client = api_client.client_for_resource(resource)

        {
          method:         "GET",
          path:           resource_client.path(resource.metadata.name, namespace: resource.metadata.namespace),
          response_class: resource_client.resource_class,
        }
      }

      # map non-nil requests to response objects, or nil for nil request options
      K8S::Util.compact_map(requests) { |reqs|
        @transport.requests(*reqs, skip_missing: true)
      }
    end

    def update_resource(resource : T) forall T
      client_for_resource(resource).update_resource(resource)
    end

    def delete_resource(resource : T, **options) forall T
      client_for_resource(resource).delete_resource(resource, **options)
    end

    def patch_resource(resource, attrs)
      client_for_resource(resource).json_patch(resource.metadata.name, attrs)
    end
  end
end
