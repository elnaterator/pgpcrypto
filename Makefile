# Variables
COMPOSE_FILE = docker-compose.yml
SERVICE_NAME = app
.DEFAULT_GOAL := help

# Build

lib-build: ## Build pgpcrypto python library
	chmod +x scripts/build.sh && ./scripts/build.sh

gpg-build: ## Build gpg binaries from source on Amazon Linux 2 and Amazon Linux 2023
	chmod +x scripts/build_gpg.sh && ./scripts/build_gpg.sh build

gpg-fetch: ## If 'gpg' binary not found locally download from artifactory
	chmod +x scripts/build_gpg.sh && ./scripts/build_gpg.sh fetch

layer-build: ## Build lambda layer zip to dist/ directory
	if [ ! -f "temp/al2/gpg" ]; then make gpg-fetch; fi
	chmod +x scripts/build_layer.sh && ./scripts/build_layer.sh

# Release

update-version: ## Update the version of pgpcrypto to VERSION
	chmod +x scripts/update_version.sh && ./scripts/update_version.sh $(VERSION)

lib-release: update-version lib-build ## Release a new version of pgpcrypto to experian artifactory with version VERSION
	chmod +x scripts/release.sh && ./scripts/release.sh

gpg-release: ## Release gpg binary to artifactory, use existing gpg binary if found locally, or else build
	if [ ! -f "temp/al2/gpg" ]; then make gpg-build; fi
	chmod +x scripts/build_gpg.sh && ./scripts/build_gpg.sh release

layer-release: ## Release lambda layer to AWS Lambda with name LAYER
	aws lambda publish-layer-version \
		--layer-name $(LAYER) \
		--zip-file fileb://dist/lambda_layer.zip \
		--compatible-runtimes python3.10 python3.11 \
		--compatible-architectures x86_64 \
		| jq -r '.LayerVersionArn'

# Test

test: test-unit test-lambda ## Run unit tests and then lambda test

test-unit: ## Run unit tests locally
	poetry install
	poetry run pytest tests -v -s

test-lambda: lib-build layer-build test-lambda-docker-start test-lambda-invoke test-lambda-docker-stop ## Start lambda docker container, invoke test lambda function tests/lambda.py, and stop container

test-lambda-docker-start: ## Start docker container running lambda function with pgpcrypto layer and tests/lambda.py
	docker compose -f $(COMPOSE_FILE) up -d $(SERVICE_NAME) --build

test-lambda-docker-stop: ## Stop docker container running lambda function
	docker compose -f $(COMPOSE_FILE) down

test-lambda-invoke: ## Invoke the function test lambda function in docker container
	@echo ""
	curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:9000/2015-03-31/functions/function/invocations | jq
	@echo "\n"

test-lambda-docker-bash: ## Run bash in lambda docker container
	docker compose -f $(COMPOSE_FILE) run --build --entrypoint "" --rm $(SERVICE_NAME) bash

help: ## Print these help docs
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: help build run stop test rebuild