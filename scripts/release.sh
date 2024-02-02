#!/usr/bin/env bash

# Check that we have the required environment variables
if [[ -z "$ARTIFACTORY_USER" || -z "$ARTIFACTORY_PASSWORD" ]]; then
    echo "Unable to publish to experian artifactory, ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD env vars are not set"
    exit 1
fi

# Get version
VERSION=$(poetry version | awk '{print $2}')

# Check if git tag already exists for version
git pull --tags origin
if git rev-parse "$VERSION" >/dev/null 2>&1; then
    echo "Tag $VERSION already exists, please bump the version"
    exit 1
fi

# Verify that the user wants to publish
echo "Are you sure you want to publish version $VERSION to experian artifactory? (y/n)"
read -r response
if [[ "$response" != "y" ]]; then
    echo "Aborting publish"
    exit 1
fi

# Publish the pypi package
echo "Publishing pgpcrypto $VERSION to experian artifactory pypi-local repository..."
poetry config repositories.experian-artifactory-local https://artifactory.experian.local/artifactory/api/pypi/pypi-local
poetry config http-basic.experian-artifactory-local "$ARTIFACTORY_USER" "$ARTIFACTORY_PASSWORD"
poetry publish -r experian-artifactory-local

# Publish the lambda layer
echo "Publishing lambda_layer-pgpcrypto-$VERSION.zip to experian artifactory batch-products-local repository..."
curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -T dist/lambda_layer.zip \
    https://artifactory.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/lambda_layer-pgpcrypto-$VERSION.zip

# Commit if there are uncommitted changes
if [[ -n $(git status -s) ]]; then
    echo "Uncommitted changes detected, committing before tagging"
    git add -A
    git commit -m "Release $VERSION"
fi

# Tag and push to origin
echo "Tag version $VERSION in git repository and pushing to origin..."
git tag -a "$VERSION" -m "Release $VERSION"
git push origin
git push origin --tags