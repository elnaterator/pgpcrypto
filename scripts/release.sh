#!/usr/bin/env bash

if [[ -z "$ARTIFACTORY_USER" || -z "$ARTIFACTORY_PASSWORD" ]]; then
    echo "Unable to publish to experian artifactory, ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD env vars are not set"
    exit 1
fi

VERSION=$(poetry version | awk '{print $2}')

echo "Are you sure you want to publish version $VERSION to experian artifactory? (y/n)"
read -r response
if [[ "$response" != "y" ]]; then
    echo "Aborting publish"
    exit 1
fi

echo "Publishing pgpcrypto $VERSION to experian artifactory pypi-local repository..."
poetry config repositories.experian-artifactory-local https://artifactory.experian.local/artifactory/api/pypi/pypi-local
poetry config http-basic.experian-artifactory-local "$ARTIFACTORY_USER" "$ARTIFACTORY_PASSWORD"
poetry publish -r experian-artifactory-local

echo "Publishing lambda_layer-pgpcrypto-$VERSION.zip to experian artifactory batch-products-local repository..."
curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -T dist/lambda_layer.zip \
    https://artifactory.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/lambda_layer-pgpcrypto-$VERSION.zip

echo "Tagging version $VERSION in git repository and pushing to origin..."
git tag -a "$VERSION" -m "Release $VERSION"
git push origin --tags