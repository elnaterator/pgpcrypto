#!/usr/bin/env bash

CUR_VERSION=$(poetry version | awk '{print $2}')
NEW_VERSION=$1
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