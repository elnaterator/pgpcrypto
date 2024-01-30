# Variables
COMPOSE_FILE = docker-compose.yml
SERVICE_NAME = app
.DEFAULT_GOAL := help

# Build

build: gpg ## Build pgpcrypto python library and lambda layer to dist/ directory
	chmod +x scripts/build_layer.sh
	./scripts/build_layer.sh

gpg: ## If no 'gpg' binary, try download from s3 or else build on EC2 then upload to s3
	make gpg-pull || make gpg-build
	make gpg-push

gpg-push: ## Upload gpg binary to s3 at $GNUPG_S3_LOCATION
	chmod +x scripts/s3_gpg_cache.sh
	./scripts/s3_gpg_cache.sh push

gpg-pull: ## Force download of gpg binary from s3 at $GNUPG_S3_LOCATION
	chmod +x scripts/s3_gpg_cache.sh
	./scripts/s3_gpg_cache.sh pull

gpg-build: ## Build gpg binary from source EC2 instance
	chmod +x scripts/build_gpg.sh
	./scripts/build_gpg.sh build

# Lambda docker container
	
start: ## Start docker container running lambda function with pgpcrypto layer and tests/lambda.py
	docker-compose -f $(COMPOSE_FILE) up -d $(SERVICE_NAME) --build

stop: ## Stop docker container running lambda function
	docker-compose -f $(COMPOSE_FILE) down

invoke: ## Invoke the function test lambda function in docker container
	@echo ""
	curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:9000/2015-03-31/functions/function/invocations
	@echo "\n"

# Tests

test: unittest test-lambda-docker ## Run unit tests and then lambda test via docker container

unittest: ## Run unit tests locally
	poetry install
	poetry run pytest tests -v -s

test-lambda-docker: build start invoke stop ## Start lambda docker container, invoke test lambda function tests/lambda.py, and stop container

bash: ## Run bash in lambda docker container
	docker-compose -f $(COMPOSE_FILE) run --build --entrypoint "" --rm $(SERVICE_NAME) bash

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