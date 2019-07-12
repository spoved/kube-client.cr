require "json"

module Kube
  class Client
    class NodeList
      include JSON::Serializable

      property kind : String

      @[JSON::Field(key: "apiVersion")]
      property api_version : String

      property metadata : Metadata?

      property items : Array(Node)
    end

    class Node
      include JSON::Serializable

      property metadata : Metadata

      property spec : SpecClass

      property status : StatusClass
    end

    class Metadata
      include JSON::Serializable

      property name : String?

      @[JSON::Field(key: "selfLink")]
      property self_link : String

      property uid : String?

      @[JSON::Field(key: "resourceVersion")]
      property resource_version : String

      @[JSON::Field(key: "creationTimestamp")]
      property creation_timestamp : String

      property labels : Labels

      property annotations : Annotations
    end

    class Annotations
      include JSON::Serializable

      @[JSON::Field(key: "container.googleapis.com/instance_id")]
      property container_googleapis_com_instance_id : String

      @[JSON::Field(key: "node.alpha.kubernetes.io/ttl")]
      property node_alpha_kubernetes_io_ttl : String

      @[JSON::Field(key: "volumes.kubernetes.io/controller-managed-attach-detach")]
      property volumes_kubernetes_io_controller_managed_attach_detach : String
    end

    class Labels
      include JSON::Serializable

      @[JSON::Field(key: "beta.kubernetes.io/arch")]
      property beta_kubernetes_io_arch : String

      @[JSON::Field(key: "beta.kubernetes.io/fluentd-ds-ready")]
      property beta_kubernetes_io_fluentd_ds_ready : String

      @[JSON::Field(key: "beta.kubernetes.io/instance-type")]
      property beta_kubernetes_io_instance_type : String

      @[JSON::Field(key: "beta.kubernetes.io/os")]
      property beta_kubernetes_io_os : String

      @[JSON::Field(key: "cloud.google.com/gke-nodepool")]
      property cloud_google_com_gke_nodepool : String

      @[JSON::Field(key: "cloud.google.com/gke-os-distribution")]
      property cloud_google_com_gke_os_distribution : String

      @[JSON::Field(key: "failure-domain.beta.kubernetes.io/region")]
      property failure_domain_beta_kubernetes_io_region : String

      @[JSON::Field(key: "failure-domain.beta.kubernetes.io/zone")]
      property failure_domain_beta_kubernetes_io_zone : String

      @[JSON::Field(key: "kubernetes.io/hostname")]
      property kubernetes_io_hostname : String

      property application : String?

      property logbackend : String?

      @[JSON::Field(key: "beta.kubernetes.io/masq-agent-ds-ready")]
      property beta_kubernetes_io_masq_agent_ds_ready : String?

      @[JSON::Field(key: "projectcalico.org/ds-ready")]
      property projectcalico_org_ds_ready : String?
    end

    class SpecClass
      include JSON::Serializable

      @[JSON::Field(key: "podCIDR")]
      property pod_cidr : String

      @[JSON::Field(key: "providerID")]
      property provider_id : String

      @[JSON::Field(key: "externalID")]
      property external_id : String?

      property taints : Array(Taint)?
    end

    class Taint
      include JSON::Serializable

      property key : String

      property value : String

      property effect : String
    end

    class StatusClass
      include JSON::Serializable

      property capacity : Allocatable

      property allocatable : Allocatable

      property conditions : Array(Condition)

      property addresses : Array(Address)

      @[JSON::Field(key: "daemonEndpoints")]
      property daemon_endpoints : DaemonEndpoints

      @[JSON::Field(key: "nodeInfo")]
      property node_info : NodeInfo

      property images : Array(Image)

      @[JSON::Field(key: "volumesInUse")]
      property volumes_in_use : Array(String)?

      @[JSON::Field(key: "volumesAttached")]
      property volumes_attached : Array(VolumesAttached)?
    end

    class Address
      include JSON::Serializable

      @[JSON::Field(key: "type")]
      property address_type : String

      property address : String
    end

    class Allocatable
      include JSON::Serializable

      @[JSON::Field(key: "attachable-volumes-gce-pd")]
      property attachable_volumes_gce_pd : String

      property cpu : String

      @[JSON::Field(key: "ephemeral-storage")]
      property ephemeral_storage : String

      @[JSON::Field(key: "hugepages-2Mi")]
      property hugepages_2_mi : String

      property memory : String

      property pods : String
    end

    class Condition
      include JSON::Serializable

      @[JSON::Field(key: "type")]
      property condition_type : String

      property status : String

      @[JSON::Field(key: "lastHeartbeatTime")]
      property last_heartbeat_time : String

      @[JSON::Field(key: "lastTransitionTime")]
      property last_transition_time : String

      property reason : String

      property message : String
    end

    class DaemonEndpoints
      include JSON::Serializable

      @[JSON::Field(key: "kubeletEndpoint")]
      property kubelet_endpoint : KubeletEndpoint
    end

    class KubeletEndpoint
      include JSON::Serializable

      @[JSON::Field(key: "Port")]
      property port : Int32
    end

    class Image
      include JSON::Serializable

      property names : Array(String)

      @[JSON::Field(key: "sizeBytes")]
      property size_bytes : Int32
    end

    class NodeInfo
      include JSON::Serializable

      @[JSON::Field(key: "machineID")]
      property machine_id : String

      @[JSON::Field(key: "systemUUID")]
      property system_uuid : String

      @[JSON::Field(key: "bootID")]
      property boot_id : String

      @[JSON::Field(key: "kernelVersion")]
      property kernel_version : String

      @[JSON::Field(key: "osImage")]
      property os_image : String

      @[JSON::Field(key: "containerRuntimeVersion")]
      property container_runtime_version : String

      @[JSON::Field(key: "kubeletVersion")]
      property kubelet_version : String

      @[JSON::Field(key: "kubeProxyVersion")]
      property kube_proxy_version : String

      @[JSON::Field(key: "operatingSystem")]
      property operating_system : String

      property architecture : String
    end

    class VolumesAttached
      include JSON::Serializable

      property name : String

      @[JSON::Field(key: "devicePath")]
      property device_path : String
    end
  end
end
