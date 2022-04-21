BUILD_COMMIT := $(shell git rev-parse --short HEAD 2> /dev/null)
K8S_VERSION="v1.22"

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z \-_0-9]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

spec: ## Run tests
	@k3d cluster create -c ./spec/files/k3d/${K8S_VERSION}.yml
	@crystal spec --error-trace --exclude-warnings /usr/local/Cellar/crystal --exclude-warnings ./lib/ -Dk8s_${K8S_VERSION}
	@k3d cluster delete k3d-cluster-test


# gen: ## Generate version files
# 	@crystal ./bin/gen

docs: ## Generate docs
	@crystal ./bin/gen_docs.cr

.PHONY: help spec gen docs