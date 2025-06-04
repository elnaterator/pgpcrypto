#!/bin/bash
set -e

# Get the package version
version=$(poetry version | awk '{print $2}')

# Check for required files
wheel_file="dist/pgpcrypto-$version-py3-none-any.whl"
al2_binary="temp/al2/gpg"
al2023_binary="temp/al2023/gpg"

if [ ! -f "$wheel_file" ]; then
    echo "Error: Wheel file not found: $wheel_file"
    echo "Run 'make lib-build' first to create the wheel"
    exit 1
fi

# Check for extracted binaries in temp directory
if [ ! -f "$al2_binary" ]; then
    echo "Error: AL2 GnuPG binary not found: $al2_binary"
    echo "Run 'make gpg-build' or 'make gpg-fetch' first"
    exit 1
fi

if [ ! -f "$al2023_binary" ]; then
    echo "Error: AL2023 GnuPG binary not found: $al2023_binary"
    echo "Run 'make gpg-build' or 'make gpg-fetch' first"
    exit 1
fi

# Copy the appropriate gpg binary for each Python version
echo "Copying AL2 binary for Python 3.10..."
cp temp/al2/gpg dist/python/gpg_al2
echo "Copying AL2023 binary for Python 3.11 and 3.12..."
cp temp/al2023/gpg dist/python/gpg_al2023

# Create wrapper script to select the right binary based on runtime
cat > dist/python/gpg << 'EOF'
#!/bin/bash
# Detect Python version and use appropriate binary
PYTHON_VERSION=$(python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")

if [[ "$PYTHON_VERSION" == "3.10" ]]; then
    exec "$(dirname "$0")/gpg_al2" "$@"
else
    exec "$(dirname "$0")/gpg_al2023" "$@"
fi
EOF

# Make the wrapper script executable
chmod +x dist/python/gpg
chmod +x dist/python/gpg_al2
chmod +x dist/python/gpg_al2023

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
zip -r lambda_layer.zip python

echo "Lambda layer created: dist/lambda_layer.zip"