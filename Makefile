BUILD_COMMIT := $(shell git rev-parse --short HEAD 2> /dev/null)
K8S_VERSION="v1.20"

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z \-_0-9]+:.*?## / {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST) | sort

setup_k8s: ## Setup k8s for testing
	@crystal ./support/setup.cr

test: ## Run tests
	@crystal spec --error-trace --exclude-warnings /usr/local/Cellar/crystal --exclude-warnings ./lib/ -Dk8s_v1.20

gen: ## Generate version files
	@crystal ./bin/gen

docs: ## Generate docs
	@crystal ./bin/gen_docs.cr

.PHONY: help setup_k8s test gen docs