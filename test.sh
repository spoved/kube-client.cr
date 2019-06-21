#!/usr/bin/env bash
set -ex


minikube status

kubectl config use-context minikube 

# Check all possible clusters, as you .KUBECONFIG may have multiple contexts:
kubectl config view -o jsonpath='{"Cluster name\tServer\n"}{range .clusters[*]}{.name}{"\t"}{.cluster.server}{"\n"}{end}'

# Select name of cluster you want to interact with from above output:
export CLUSTER_NAME="minikube"

# Point to the API server refering the cluster name
APISERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"${CLUSTER_NAME}\")].cluster.server}")

# Gets the token value
TOKEN=$(kubectl get secrets -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}"|base64 -d)

# Explore the API with TOKEN
curl -X GET ${APISERVER}/api --header "Authorization: Bearer ${TOKEN}" --insecure
