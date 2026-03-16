IMAGE_NAME ?= pygmystack/haproxy
IMAGE_TAG  ?= test
FULL_IMAGE := $(IMAGE_NAME):$(IMAGE_TAG)

.DEFAULT_GOAL := help

.PHONY: help build test test-bats test-structure test-runtime validate-config up down shell clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	docker build --tag $(FULL_IMAGE) .

test: build ## Build image and run all tests (requires: brew install bats-core)
	@command -v bats >/dev/null 2>&1 || { \
		echo "Error: bats is not installed. Install with: brew install bats-core"; \
		exit 1; \
	}
	IMAGE_NAME=$(FULL_IMAGE) bats --tap tests/

test-bats: ## Run all BATS tests without rebuilding the image
	@command -v bats >/dev/null 2>&1 || { \
		echo "Error: bats is not installed. Install with: brew install bats-core"; \
		exit 1; \
	}
	IMAGE_NAME=$(FULL_IMAGE) bats --tap tests/

test-structure: ## Run image structure tests only (no Docker socket required)
	@command -v bats >/dev/null 2>&1 || { \
		echo "Error: bats is not installed. Install with: brew install bats-core"; \
		exit 1; \
	}
	IMAGE_NAME=$(FULL_IMAGE) bats --tap tests/image_structure.bats

test-runtime: ## Run container runtime and integration tests (Docker socket required)
	@command -v bats >/dev/null 2>&1 || { \
		echo "Error: bats is not installed. Install with: brew install bats-core"; \
		exit 1; \
	}
	IMAGE_NAME=$(FULL_IMAGE) bats --tap tests/runtime.bats

validate-config: ## Validate the default haproxy.cfg syntax
	docker run --rm $(FULL_IMAGE) haproxy -c -f /app/haproxy.cfg

up: ## Start the stack with docker compose
	docker compose up -d

down: ## Stop the stack with docker compose
	docker compose down

shell: ## Open an interactive shell inside the container
	docker run --rm -it --entrypoint bash $(FULL_IMAGE)

clean: ## Remove the local test Docker image
	docker rmi $(FULL_IMAGE) 2>/dev/null || true
