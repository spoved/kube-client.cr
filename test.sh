#!/usr/bin/env bash
set -e

# minikube status

kubectl config use-context minikube

# Check all possible clusters, as you .KUBECONFIG may have multiple contexts:
# kubectl config view -o jsonpath='{"Cluster name\tServer\n"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}'

# Select name of cluster you want to interact with from above output:
export CLUSTER_NAME="minikube"

# Point to the API server refering the cluster name
export KUBE_API_SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"${CLUSTER_NAME}\")].cluster.server}")

# Gets the token value
export KUBE_TOKEN=$(kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}"|base64 -d)

helm init 1>/dev/null 2>&1

status=$(helm list --output json  2>/dev/null | jq '.Releases | .[] | select(.Name == "kubecr-test") | .Status' -r)
if [[ -z "${status}" ]];then
  helm install stable/percona --name kubecr-test 1>/dev/null 2>&1
else
  # helm del --purge kubecr-test  1>/dev/null 2>&1
  # sleep 10
  echo ""
fi



crystal spec
