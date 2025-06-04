#!/usr/bin/env bash

# Check that we have the required environment variables
if [[ -z "$ARTIFACTORY_USER" || -z "$ARTIFACTORY_PASSWORD" ]]; then
    echo "Unable to publish to experian artifactory, ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD env vars are not set"
    exit 1
fi

# Get version
VERSION=$(poetry version | awk '{print $2}')

# Check if lambda layer exists
LAYER_FILE="dist/lambda-layer-pgpcrypto-$VERSION.zip"
if [ ! -f "$LAYER_FILE" ]; then
    echo "Lambda layer file not found: $LAYER_FILE"
    echo "Run 'make layer-build' first"
    exit 1
fi

# Verify that the user wants to publish
echo "Are you sure you want to publish $LAYER_FILE to experian artifactory? (y/n)"
read -r response
if [[ "$response" != "y" ]]; then
    echo "Aborting publish"
    exit 1
fi

# Publish the lambda layer
echo "Publishing lambda layer to experian artifactory batch-products-local repository..."
curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" \
    -T "$LAYER_FILE" \
    "https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/$LAYER_FILE"

if [ $? -eq 0 ]; then
    echo "Successfully published lambda layer to artifactory"
else
    echo "Failed to publish lambda layer to artifactory"
    exit 1
fi