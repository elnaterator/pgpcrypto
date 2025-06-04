# PGPCrypto: Python Library and Lambda Layer for PGP Encryption

PGPCrypto simplifies PGP encryption and decryption in Python applications running on AWS environments. It provides a clean API wrapper around GnuPG, bundled with a compatible binary for Amazon Linux environments. This makes it particularly valuable for serverless applications like AWS Lambda functions where installing system dependencies is challenging. The library supports key management, file encryption/decryption, and works across all Python 3.10+ Lambda runtimes.

## Table of Contents
- [PGPCrypto: Python Library and Lambda Layer for PGP Encryption](#pgpcrypto-python-library-and-lambda-layer-for-pgp-encryption)
  - [Table of Contents](#table-of-contents)
  - [Usage](#usage)
  - [Installation](#installation)
    - [Lambda Layer](#lambda-layer)
    - [Python Library](#python-library)
  - [Contributing](#contributing)
    - [Development Setup](#development-setup)
    - [Building](#building)
    - [Testing](#testing)
    - [Releasing](#releasing)
  - [Metadata](#metadata)

## Usage

```python
from tempfile import TemporaryDirectory
from pgpcrypto.pgp import PgpWrapper

# Create a temporary directory for working files
with TemporaryDirectory(dir="/tmp") as tmpdir:
    # Initialize the PGP wrapper
    pgpw = PgpWrapper(
        gnupghome=f"{tmpdir}/.gnupghome",
        gpgbinary='/opt/python/gpg'  # Path to the bundled gpg binary
    )
    
    # Import keys
    pgpw.import_public_key(
        public_key=open("recipient.pub.asc").read(),
        recipient="user@example.com",
        default=True
    )
    
    # Encrypt a file
    pgpw.encrypt_file("plaintext.txt", "encrypted.pgp")
    
    # Import secret key for decryption
    pgpw.import_secret_key(
        secret_key=open("secret.key.asc").read(),
        passphrase="your-secure-passphrase"
    )
    
    # Decrypt the file
    pgpw.decrypt_file("encrypted.pgp", "decrypted.txt")
```

This example demonstrates how to use PGPCrypto to encrypt and decrypt files using PGP keys. The library handles key management, encryption, and decryption making it easy to integrate PGP functionality into your Python applications.

For more usage instructions, refer to examples in the `examples/` directory or the [documentation](https://pages.experian.local/display/ARCCOE/PGP+Encryption+and+Decryption+with+Python).

## Installation

### Lambda Layer

The easiest way to use PGPCrypto in AWS Lambda is to deploy it as a Lambda layer:

1. Download the Lambda layer zip file:
   ```bash
   VERSION="1.0.0"  # Replace with the desired version
   curl -o lambda_layer.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/lambda_layer-pgpcrypto-$VERSION.zip
   ```

2. Deploy as a Lambda layer (compatible with Python 3.10, 3.11, and 3.12 runtimes on x86_64 architecture)

3. Attach the layer to your Lambda function

### Python Library

For other AWS environments (EC2, ECS, Glue, etc.):

```bash
# Using Poetry
poetry source add artifactory https://artifacts.experian.local/artifactory/api/pypi/pypi/simple
poetry add pgpcrypto

# Using Pip
pip install -i https://artifacts.experian.local/artifactory/api/pypi/pypi/simple pgpcrypto

# Download and extract the GnuPG binary
curl -o gnupg-bin.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/gnupg-bin-1.4.23-al2-x86_64.zip
unzip gnupg-bin.zip
chmod +x ./gpg
```

## Contributing

### Development Setup

Prerequisites:
- Python 3.10 or newer
- Poetry for dependency management
- Docker for testing
- Access to Experian Artifactory for releasing

```bash
# Clone the repository
git clone <repository-url>
cd pgpcrypto

# Install dependencies
poetry install
```

### Building

```bash
# Build the Python package and Lambda layer
make build

# Build just the Python package
make build-lib

# Build just the Lambda layer
make build-layer
```

### Testing

```bash
# Run all tests including dockerized Lambda tests
make test

# Run unit tests only
make test-unit

# Run lambda integration tests only (requires Docker)
make test-lambda
```

### Releasing

```bash
# Set Artifactory credentials
export ARTIFACTORY_USER="<username>"
export ARTIFACTORY_PASSWORD="<api-key>"

# Release the Python library
make release VERSION="1.2.3"  # Replace with the desired version

# Release the python library and Lambda layer separately
make lib-release VERSION="1.2.3"  # Replace with the desired version
make layer-release VERSION="1.2.3"  # Replace with the desired version
```

## Metadata

```discoveryhub
region: NA
bu: FSD
artifacts: https://artifacts.experian.local/ui/repos/tree/General/pypi-local/pgpcrypto
docs: https://pages.experian.local/display/ARCCOE/PGP+Encryption+and+Decryption+with+Python
contacts:
  technical: Hadzariga, Nathan <nathan.mhadzariga@experian.com>
  product: Hadzariga, Nathan <nathan.mhadzariga@experian.com>
links:
  lambda_layer_artifactory: https://artifacts.experian.local/ui/repos/tree/General/batch-products-local/pgpcrypto/lambda_layer
  pypi_artifactory: https://artifacts.experian.local/ui/repos/tree/General/pypi-local/pgpcrypto
  gnupg_artifactory: https://artifacts.experian.local/ui/repos/tree/General/batch-products-local/pgpcrypto/gnupg-binary
```