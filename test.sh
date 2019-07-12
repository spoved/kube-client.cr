#!/usr/bin/env bash
set -ex

export CLUSTER_NAME="minikube"
export APP_NAME="kubecr-test"

setup_minikube(){
  set +e
  mini_k_status=$(minikube status --format "{{.APIServer}}")
  set -e

  if [[ "${mini_k_status}" != "Running" ]]; then
    minikube delete
    minikube start --cpus 4 --memory 8192
  fi

  kubectl config use-context ${CLUSTER_NAME}
}

check_helm(){
  set +e
  helm list 1>/dev/null 2>&1
  if [[ $? -ne 0 ]]; then
    helm init 1>/dev/null 2>&1
    sleep 10
  fi
  set -e

  chart_status=$(helm list --output json 2>/dev/null | jq '.Releases | .[] | select(.Name == "kubecr-test") | .Status' -r)
  if [[ -z "${chart_status}" ]];then
    helm install stable/elastic-stack --name ${APP_NAME} -f ./spec/files/elastic-stack.yml 1>/dev/null 2>&1
    sleep 60
  fi
}

run_spec(){
  crystal spec
}


setup_minikube
check_helm

# Point to the API server refering the cluster name
export KUBE_API_SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"${CLUSTER_NAME}\")].cluster.server}")

# Gets the token value
export KUBE_TOKEN=$(kubectl get secrets -n kube-system -o jsonpath="{.items[?(@.metadata.annotations['kubernetes\.io/service-account\.name']=='default')].data.token}"|base64 -d)

# minikube dashboard
run_spec

echo ${env | sort} > .env
