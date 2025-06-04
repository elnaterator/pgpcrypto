#!/usr/bin/env bash

CUR_VERSION=$(poetry version | awk '{print $2}')
NEW_VERSION=$1

if [[ -z "$NEW_VERSION" ]]; then
    echo "Usage: $0 <new_version>, or 'make update-version VERSION=<new_version>'"
    echo "Must provide a new version to bump to."
    exit 1
fi

echo "Updating from version $CUR_VERSION to $NEW_VERSION"

# Bump version from poetry
poetry version $NEW_VERSION

# Update the version in the readme
echo "Updating VERSION=\"$CUR_VERSION\" to VERSION=\"$NEW_VERSION\" in README.md"
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/VERSION=\"$CUR_VERSION\"/VERSION=\"$NEW_VERSION\"/" README.md
else
    # Linux
    sed -i "s/VERSION=\"$CUR_VERSION\"/VERSION=\"$NEW_VERSION\"/" README.md
fi