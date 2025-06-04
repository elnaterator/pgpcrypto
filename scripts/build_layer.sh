#!/bin/bash
set -e

# Get the package version
version=$(poetry version | awk '{print $2}')

# Check for required files
wheel_file="dist/pgpcrypto-$version-py3-none-any.whl"
gpg_binary="temp/al2/gpg"
layer_zip_file="lambda-layer-pgpcrypto-$version.zip"

if [ ! -f "$wheel_file" ]; then
    echo "Error: Wheel file not found: $wheel_file"
    echo "Run 'make lib-build' first to create the wheel"
    exit 1
fi

# Check for extracted binaries in temp directory
if [ ! -f "$gpg_binary" ]; then
    echo "Error: AL2 GnuPG binary not found: $gpg_binary"
    echo "Run 'make gpg-build' or 'make gpg-fetch' first"
    exit 1
fi

# Copy gpg binary, note that this was built for Amazon Linux 2, but works for Amazon Linux 2023 as well
echo "Copying gpg binary..."
mkdir -p dist/python
cp temp/al2/gpg dist/python/gpg

# Make sure the gpg binary is executable
chmod +x dist/python/gpg

# Create a common site-packages directory
mkdir -p dist/python/lib/python/site-packages

# Install the wheel once
echo "Installing wheel to common directory..."
.venv/bin/pip install "$wheel_file" -t ./dist/python/lib/python/site-packages

# Create the runtime-specific directories
mkdir -p dist/python/lib/python3.10
mkdir -p dist/python/lib/python3.11
mkdir -p dist/python/lib/python3.12

# Create symbolic links to the common site-packages
ln -sf ../python/site-packages dist/python/lib/python3.10/site-packages
ln -sf ../python/site-packages dist/python/lib/python3.11/site-packages
ln -sf ../python/site-packages dist/python/lib/python3.12/site-packages

# Create the Lambda layer zip
echo "Creating Lambda layer zip..."
cd dist
zip -r $layer_zip_file python

echo "Lambda layer created: dist/$layer_zip_file"