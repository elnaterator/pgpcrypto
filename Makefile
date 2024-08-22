# Variables
COMPOSE_FILE = docker-compose.yml
SERVICE_NAME = app
.DEFAULT_GOAL := help

# Build

build: gpg ## Build pgpcrypto python library and lambda layer to dist/ directory
	chmod +x scripts/build.sh && ./scripts/build.sh

gpg: ## If 'gpg' binary not found locally download from artifactory
	chmod +x scripts/build_gpg.sh && ./scripts/build_gpg.sh fetch

gpg-build: ## Build gpg binary from source on EC2 instance
	chmod +x scripts/build_gpg.sh && ./scripts/build_gpg.sh build

# Release

update-version: ## Update the version of pgpcrypto to VERSION
	poetry version $(VERSION)

release: update-version build ## Release a new version of pgpcrypto to experian artifactory with version VERSION
	chmod +x scripts/release.sh && ./scripts/release.sh

gpg-release: ## Release gpg binary to artifactory, use existing gpg binary if found locally, or else build
	if [ ! -f "gpg" ]; then make gpg-build; fi
	chmod +x scripts/build_gpg.sh && ./scripts/build_gpg.sh release

# Docker
	
start: ## Start docker container running lambda function with pgpcrypto layer and tests/lambda.py
	docker compose -f $(COMPOSE_FILE) up -d $(SERVICE_NAME) --build

stop: ## Stop docker container running lambda function
	docker compose -f $(COMPOSE_FILE) down

invoke: ## Invoke the function test lambda function in docker container
	@echo ""
	curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:9000/2015-03-31/functions/function/invocations | jq
	@echo "\n"

# Test

test: unittest test-lambda-docker ## Run unit tests and then lambda test via docker container

unittest: ## Run unit tests locally
	poetry install
	poetry run pytest tests -v -s

test-lambda-docker: build start invoke stop ## Start lambda docker container, invoke test lambda function tests/lambda.py, and stop container

bash: ## Run bash in lambda docker container
	docker compose -f $(COMPOSE_FILE) run --build --entrypoint "" --rm $(SERVICE_NAME) bash

deploy: ## Deploy to a lambda layer with name LAYER
	aws lambda publish-layer-version \
		--layer-name $(LAYER) \
		--zip-file fileb://dist/lambda_layer.zip \
		--compatible-runtimes python3.10 python3.11 \
		--compatible-architectures x86_64 \
		| jq -r '.LayerVersionArn'

help: ## Print these help docs
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: help build run stop test rebuild