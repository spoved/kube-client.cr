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

    @api_groups : Array(String) = Array(String).new

    def initialize(@transport : Kube::Transport, @namespace : String? = nil); end

    def version : K8S::Apimachinery::Version::Info
      @version ||= @transport.version
    end

    # api_version [String] "group/version" or "version" (core)
    def api(api_version : String = "v1") : Kube::ApiClient
      self.api_clients[api_version] ||= Kube::ApiClient.new(@transport, api_version)
    end

    # Cached /apis preferred group apiVersions
    def api_groups : Array(String)
      @api_groups.empty? ? api_groups! : @api_groups
    end

    # Force-update /apis cache.
    # Required if creating new CRDs/apiservices.
    def api_groups! : Array(String)
      logger.trace { "Updating api groups" }

      @mutex.synchronize do
        groups = @transport.get(
          "/apis",
          response_class: K8S::Apimachinery::Apis::Meta::V1::APIGroupList
        ).as(K8S::Apimachinery::Apis::Meta::V1::APIGroupList)
          .groups.flat_map(&.versions.map(&.group_version))

        @api_groups.clear
        @api_clients.clear

        @api_groups.concat(groups)
      end

      @api_groups.not_nil!
    end

    # api_versions [Array(String)] defaults to all APIs
    # prefetch_resources [Bool] prefetch any missing api_resources for each api_version
    # skip_missing [Bool] return Kube::ApiClient without api_resources? if 404
    def apis(api_versions = nil, prefetch_resources = false, skip_missing = false, skip_forbidden = true, skip_unknown = true) : Array(Kube::ApiClient)
      api_versions ||= (["v1"] + api_groups).uniq!

      if prefetch_resources
        # api groups that are missing their api_resources
        api_paths = api_versions
          .reject { |api_version| api(api_version).api_resources? }
          .map { |api_version| Kube::ApiClient.path(api_version) }

        # load into Kube::ApiClient.api_resources=
        begin
          @transport.gets(api_paths,
            response_class: K8S::Apimachinery::Apis::Meta::V1::APIResourceList,
            skip_missing: skip_missing,
            skip_forbidden: skip_forbidden,
            skip_unknown: skip_unknown,
          ).each do |api_resource_list|
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

    def resources(namespace : String? = nil)
      apis(prefetch_resources: true).flat_map { |api|
        logger.trace { "Fetching resources for #{api.api_version}" }
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
    def list_resources(resource_list : Array(Kube::ResourceClient)? = nil, **options)
      logger.trace { "list_resources(#{resource_list}, #{options})" }
      resource_list ||= self.resources(options[:namespace]?).select(&.list?)
      logger.info { "list_resources found #{resource_list.size} API resources" }

      ResourceClient.list(resource_list, @transport, **options)
    rescue ex : Kube::Error::NotFound
      logger.error { ex.message }
      raise ex
    end

    def client_for_resource(resource : T.class | T, namespace : String? = nil) forall T
      api_ver = {% if T < K8S::Kubernetes::Resource %}
                  {% anno = T.annotation(::K8S::GroupVersionKind) %}
                  {% if anno && anno.named_args[:group] %}
                    File.join({{anno.named_args[:group]}}, {{anno.named_args[:version]}})
                  {% else %}
                    resource.group.empty? ? resource.api_version : File.join(resource.group, resource.api_version)
                  {% end %}
                {% else %}
                  resource.api_version
                {% end %}
      logger.warn { api_ver }
      api(api_ver).client_for_resource(resource, namespace: namespace)
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
