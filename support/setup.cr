#!/usr/bin/env crystal
require "json"
require "log"

Log.setup(:debug)

CLUSTER_NAME  = ENV["CLUSTER_NAME"]
APP_NAMESPACE = ENV["APP_NAMESPACE"]
APP_NAME      = ENV["APP_NAME"]

def create_cluster
  system("k3d cluster create #{CLUSTER_NAME} -c spec/files/k3d-cluster-test.yaml --kubeconfig-update-default")
end

def delete_cluster
  system("k3d cluster delete #{CLUSTER_NAME}")
end

def get_cluster_status
  data = JSON.parse(`k3d cluster list -o json`)
  data.as_a.find { |cluster| cluster["name"] == CLUSTER_NAME }
rescue
  Log.error { "k3d cluster list failed" }
  exit 1
end

cluster = get_cluster_status
if cluster && cluster["serversRunning"] == cluster["serversCount"]
  Log.info { "Cluster #{CLUSTER_NAME} is already running" }
  # exit 0
else
  create_cluster
end

# if helm_status == "deployed"
#   Log.info { "Helm chart #{APP_NAME} is already deployed" }
#   # exit 0
# else
#   helm_install
# end
