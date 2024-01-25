# Variables
COMPOSE_FILE = docker-compose.yml
SERVICE_NAME = app
.DEFAULT_GOAL := help


gpg-build: ## Build the gpg binary from source on an Amazon Linux 2 EC2 instance and then download gpg binary from s3
	chmod +x scripts/build_gpg.sh
	./scripts/build_gpg.sh build

gpg: ## Try to download the gpg binary from s3 at $GNUPG_S3_LOCATION/gpg or else call gpg-build.
	chmod +x scripts/build_gpg.sh
	./scripts/build_gpg.sh fetch || make gpg-build

build: gpg ## Build python layer if the gpg binary needs to be built from source
	chmod +x scripts/build_layer.sh
	./scripts/build_layer.sh
	
start: ## Run the lambda function Docker container
	docker-compose -f $(COMPOSE_FILE) up -d $(SERVICE_NAME) --build

stop: ## Stop the lambda function Docker container
	docker-compose -f $(COMPOSE_FILE) down

invoke: ## Invoke the function tests/lambda.py in docker container
	@echo ""
	curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:9000/2015-03-31/functions/function/invocations
	@echo "\n"

test: test-local test-docker ## Run test-local and then test-docker

test-local: ## Run unit tests locally via poetry
	poetry install
	poetry run pytest tests -v

test-docker: build start invoke stop ## Start lambda docker container, invoke test lambda function tests/lambda.py, and stop container

bash: ## Run bash in docker container
	docker-compose -f $(COMPOSE_FILE) run --build --entrypoint "" --rm $(SERVICE_NAME) bash

help: ## Print these help docs
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: help build run stop test rebuild