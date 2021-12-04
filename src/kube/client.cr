require "halite"
require "spoved/logger"
require "spoved/system_cmd"
require "../ext/*"
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
          @transport.gets(api_paths, skip_missing: skip_missing).each do |api_resource_list|
            if api_resource_list && api_resource_list.is_a?(K8S::Apimachinery::Apis::Meta::V1::APIResource)
              api(api_resource_list.group_version).api_resources = api_resource_list.resources
            end
          end
        rescue ex : Kube::Error::API::NotFound | Kube::Error::API::ServiceUnavailable
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
        rescue ex : Kube::Error::API::ServiceUnavailable | Kube::Error::API::NotFound
          Array(Kube::ResourceClient(K8S::Kubernetes::Resource)).new
        end
      }
    end
  end
end
