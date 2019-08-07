require "spoved/logger"
require "./client"

# TODO: Write documentation for `Kube::Helper`
module Kube::Helper
  spoved_logger

  # A parsed event message from `::Kube::Client#stream`
  alias Event = NamedTuple(type: String, kind: String, name: String, msg: Hash(String, JSON::Any))

  # Hash containing the possible phases of the kubernetes pod
  POD_PHASES = {
    pending:    "Pending",
    running:    "Running",
    succeeded:  "Succeeded",
    failed:     "Failed",
    unkown:     "Unknown",
    completed:  "Completed",
    crash_loop: "CrashLoopBackOff",
  }

  # Kubernetes API Client
  getter client : ::Kube::Client

  # Helper method to return the status phase of the pod
  def pod_status(pod : JSON::Any) : String
    pod["status"]["phase"].as_s
  rescue
    "Unknown"
  end

  # Helper method to return the name of the pod
  def pod_name(pod : JSON::Any) : String?
    pod["metadata"]["name"].as_s
  rescue ex
    logger.error(ex, "pod_name")
    nil
  end

  # Helper method to return the ip address of the pod
  def pod_ip(pod : JSON::Any) : String?
    return nil unless pod["status"]["podIP"]?
    pod["status"]["podIP"].as_s
  rescue ex
    logger.error(ex, "pod_ip")
    nil
  end

  # Helper method to return the cluster ip of the pod
  def pod_cluster_ip(pod : JSON::Any) : String?
    return nil unless pod["status"]["hostIP"]?
    pod["status"]["hostIP"].as_s
  rescue ex
    logger.error(ex, "pod_role")
    nil
  end

  # Helper method to return the labels of the pod
  def pod_labels(pod : JSON::Any) : Hash(String, String)?
    pod["metadata"]["labels"].as_h.map { |v| v.as_s }
  rescue ex
    logger.error(ex, "pod_labels")
    nil
  end

  # Helper method to return the ip of the node
  def node_ip(node : Hash(String, JSON::Any) | JSON::Any) : String?
    node["status"]["addresses"].as_a.find { |i| i["type"].as_s == "InternalIP" }.as(JSON::Any)["address"].as_s
  rescue ex
    logger.error(ex, "node_ip")
    nil
  end

  # Helper method to return the name of the node
  def node_name(node : JSON::Any) : String?
    node["metadata"]["name"].as_s
  rescue ex
    logger.error(ex, "node_name")
    nil
  end

  # Helper method to return if the node is considered "ready"
  def node_ready?(node : JSON::Any) : Bool
    node["status"]["conditions"].as_a.each do |cond|
      if cond["type"]? && cond["type"].as_s == "Ready"
        cond["status"].as_s == "True" ? true : false
      end
    end
    false
  end

  # Helper method to return if the node is schedulable
  def node_schedulable?(node : JSON::Any) : Bool
    !node_unschedulable?(node)
  end

  # Helper method to return if the node is unschedulable
  def node_unschedulable?(node : JSON::Any) : Bool
    if node["spec"]["unschedulable"]?
      node["spec"]["unschedulable"].as_bool
    else
      false
    end
  rescue ex
    logger.error(ex, "node_unschedulable?")
    false
  end

  # Gather all nodes in the cluster
  def gather_nodes : Array(JSON::Any)
    client.nodes["items"].as_a
  rescue ex
    logger.error(ex, "gather_nodes")
    Array(JSON::Any).new
  end
end
