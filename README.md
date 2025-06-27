# PGPCrypto: Python Library and Lambda Layer for PGP Encryption

PGPCrypto solves the challenge of implementing PGP encryption in AWS environments, especially Lambda functions. It bundles a compatible GnuPG binary with a simple Python API that handles key management, file encryption/decryption, and secure cleanup. Deploy as a Lambda layer for serverless applications or use as a library in any AWS environment (EC2, ECS, Glue, EMR). With just a few lines of code, securely encrypt and decrypt files using industry-standard PGP encryption across all Python 3.10+ runtimes.

## Table of Contents
- [Usage](#usage)
- [Installation](#installation)
  - [Lambda Layer](#lambda-layer)
  - [Python Library](#python-library)
- [Contributing](#contributing)
  - [Development Setup](#development-setup)
  - [Building](#building)
  - [Testing](#testing)
  - [Releasing](#releasing)
  - [Building GPG Binary](#building-gpg-binary)
- [Metadata](#metadata)

<a name="usage"></a>
## Usage

```python
from tempfile import TemporaryDirectory
from pgpcrypto.pgp import PgpWrapper

# Fetch the PGP keys from a secure location (e.g., AWS Secrets Manager)
public_key = get_secret("pgpcrypto/recipient/public_key")  # Public key for encryption
secret_key = get_secret("pgpcrypto/recipient/secret_key")  # Secret key for decryption
passphrase = get_secret("pgpcrypto/recipient/passphrase")  # Passphrase for the secret key

# Create a temporary directory for working files
# This ensures all keys and files are isolated and cleaned up after use
with TemporaryDirectory(dir="/tmp") as tmpdir:
  
    # Initialize the PGP wrapper
    pgpw = PgpWrapper(
        gnupghome=f"{tmpdir}/.gnupghome",
        gpgbinary='/opt/python/gpg'  # Path to the bundled gpg binary
        # gpgbinary='/opt/python/gpg' is the default path in Lambda layers
        # if using the library outside of Lambda, adjust the path accordingly
    )
    
    # Import keys
    pgpw.import_public_key(
        public_key=public_key,
        recipient="user@example.com",
        default=True  # Set as default key for encryption
        # When working with multiple keys you may set default=False and specify the recipient explicitly on encryption
        # (See examples for more details)
    )
    
    # Encrypt a file
    pgpw.encrypt_file(f"{tmpdir}/plaintext.txt", f"{tmpdir}/encrypted.pgp")
    
    # Import secret key for decryption
    pgpw.import_secret_key(
        secret_key=secret_key,
        passphrase=passphrase,
    )
    
    # Decrypt the file
    pgpw.decrypt_file(f"{tmpdir}/encrypted.pgp", f"{tmpdir}/decrypted.txt")
    # When working with multiple keys, the correct key will be automatically selected based on the encrypted file's metadata

```

This example demonstrates how to use PGPCrypto to encrypt and decrypt files using PGP keys. The library handles key management, encryption, and decryption making it easy to integrate PGP functionality into your Python applications.

See the `examples/` directory for more complete examples and uses cases such as AWS Lambda functions.  See also the [documentation](https://pages.experian.local/display/ARCCOE/PGP+Encryption+and+Decryption+with+Python).

<a name="installation"></a>
## Installation

<a name="lambda-layer"></a>
### Lambda Layer

The easiest way to use PGPCrypto in AWS Lambda is to deploy it as a Lambda layer:

1. Download the Lambda layer zip file:
   ```bash
   VERSION="0.2.0"  # Replace with the desired version
   curl -o lambda_layer.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/lambda-layer-pgpcrypto-$VERSION.zip
   ```

2. Deploy as a Lambda layer (compatible with Python 3.10, 3.11, 3.12, and 3.13 runtimes on x86_64 architecture)

3. Attach the layer to your Lambda function

<a name="python-library"></a>
### Python Library

For other AWS environments (EC2, ECS, Glue, etc.), add the library to your Python project using one of the following methods, and ensure the GnuPG binary is available in your environment:

```bash
# Using Pip
pip install -i https://artifacts.experian.local/artifactory/api/pypi/pypi/simple pgpcrypto

# Usinv uv
uv add pgpcrypto --index-url https://artifacts.experian.local/artifactory/api/pypi/pypi/simple

# Using Poetry
poetry source add artifactory https://artifacts.experian.local/artifactory/api/pypi/pypi/simple
poetry add pgpcrypto

# Download and extract the GnuPG binary
curl -o gnupg-bin.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/gnupg-bin-1.4.23-al2-x86_64.zip
unzip gnupg-bin.zip
chmod +x ./gpg
```

<a name="contributing"></a>
## Contributing

We welcome contributions to PGPCrypto! Please follow these steps to contribute:
1. Fork the repository
2. Create a new branch for your feature or bug fix
3. Make your changes and commit them with clear messages
4. Push your changes to your fork
5. Create a pull request against the `main` branch of the original repository

Try `make help` to see all available commands and targets.

<a name="development-setup"></a>
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

<a name="building"></a>
### Building

```bash
# Build the Python package and Lambda layer
make build

# Build just the Python package
make lib-build

# Build just the Lambda layer
make layer-build
```

<a name="testing"></a>
### Testing

```bash
# Run all tests including dockerized Lambda tests
make test

# Run unit tests only
make test-unit

# Run lambda integration tests only (requires Docker)
make test-lambda
```

<a name="releasing"></a>
### Releasing

```bash
# Set Artifactory credentials
export ARTIFACTORY_USER="<username>"
export ARTIFACTORY_PASSWORD="<api-key>"

# Release the Python library
make release VERSION="0.2.0"  # Replace with the desired version

# Release the python library and Lambda layer separately
make lib-release VERSION="0.2.0"  # Replace with the desired version
make layer-release                # Version is automatically set based on the Python package version
```

<a name="building-gpg-binary"></a>
### Building GPG Binary

> Note: Building the GPG binary is rarely needed. The binary will be automatically fetched from Artifactory when needed for building, testing, and releasing the Lambda layer.

```bash
# Build the GPG binary for Amazon Linux 2
make gpg-build

# Release the GPG binary to Artifactory
make gpg-release
```

<a name="metadata"></a>
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