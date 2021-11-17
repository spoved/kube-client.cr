#!/usr/bin/env bash
set -ex

./support/setup.cr

# Point to the API server refering the cluster name
jsonpath="{.clusters[?(@.name==\"k3d-${CLUSTER_NAME}\")].cluster.server}"
export KUBE_API_SERVER=$(kubectl config view -o jsonpath="${jsonpath}")

# Gets the token value
export KUBE_TOKEN=$(kubectl get secrets -n kube-system -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}" | base64 -d)
env | egrep "APP_NS|APP_NAME|CLUSTER_NAME|KUBE_" | sort >.env_test
