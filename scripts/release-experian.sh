#!/usr/bin/env bash

if [[ -z "$ARTIFACTORY_USER" || -z "$ARTIFACTORY_PASSWORD" ]]; then
    echo "Unable to publish to experian artifactory, ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD env vars are not set"
    exit 1
fi

echo "Publishing to pgpcrypto python library to experian artifactory pypi-local repository..."
poetry config repositories.experian-artifactory-local https://artifactory.experian.local/artifactory/api/pypi/pypi-local
poetry config http-basic.experian-artifactory-local "$ARTIFACTORY_USER" "$ARTIFACTORY_PASSWORD"
poetry publish -r experian-artifactory-local

echo "Publishing lambda layer zip file to experian artifactory batch-products-local repository..."
PGPCRYPTO_VERSION=$(poetry version | tr ' ' '-')
curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -T dist/lambda_layer.zip \
    https://artifactory.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/lambda_layer-$PGPCRYPTO_VERSION-py3.10-py3.11.zip