# PGPCrypto: Python Library and Lambda Layer for PGP Encryption

PGPCrypto simplifies PGP encryption and decryption in Python applications running on AWS environments. It provides a clean API wrapper around GnuPG, bundled with a compatible binary for Amazon Linux environments. This makes it particularly valuable for serverless applications like AWS Lambda functions where installing system dependencies is challenging. The library supports key management, file encryption/decryption, and works across all Python 3.10+ Lambda runtimes.

## Table of Contents
* [Usage](#usage-section)
* [Installation](#installation-section)
  * [Lambda Layer](#lambda-layer-section)
  * [Python Library](#python-library-section)
* [Contributing](#contributing-section)
  * [Development Setup](#development-setup-section)
  * [Building](#building-section)
  * [Testing](#testing-section)
  * [Releasing](#releasing-section)
* [Metadata](#metadata-section)

<a name="usage-section"></a>
## Usage

```python
from tempfile import TemporaryDirectory
from pgpcrypto.pgp import PgpWrapper

# Fetch the PGP keys from a secure location (e.g., AWS Secrets Manager)
public_key = get_secret("pgpcrypto/recipient/public_key")  # Public key for encryption
secret_key = get_secret("pgpcrypto/recipient/secret_key")  # Secret key for decryption

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
    )
    
    # Encrypt a file
    pgpw.encrypt_file("plaintext.txt", "encrypted.pgp")
    
    # Import secret key for decryption
    pgpw.import_secret_key(
        secret_key=secret_key,
        passphrase="your-secure-passphrase"
    )
    
    # Decrypt the file
    pgpw.decrypt_file("encrypted.pgp", "decrypted.txt")
    # When working with multiple keys, the correct key will be automatically selected based on the encrypted file's metadata

```

This example demonstrates how to use PGPCrypto to encrypt and decrypt files using PGP keys. The library handles key management, encryption, and decryption making it easy to integrate PGP functionality into your Python applications.

See the `examples/` directory for more complete examples and uses cases such as AWS Lambda functions.  See also the [documentation](https://pages.experian.local/display/ARCCOE/PGP+Encryption+and+Decryption+with+Python).

<a name="installation-section"></a>
## Installation

<a name="lambda-layer-section"></a>
### Lambda Layer

The easiest way to use PGPCrypto in AWS Lambda is to deploy it as a Lambda layer:

1. Download the Lambda layer zip file:
   ```bash
   VERSION="0.2.0"  # Replace with the desired version
   curl -o lambda_layer.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/lambda-layer-pgpcrypto-$VERSION.zip
   ```

2. Deploy as a Lambda layer (compatible with Python 3.10, 3.11, and 3.12 runtimes on x86_64 architecture)

3. Attach the layer to your Lambda function

<a name="python-library-section"></a>
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

<a name="contributing-section"></a>
## Contributing

<a name="development-setup-section"></a>
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

<a name="building-section"></a>
### Building

```bash
# Build the Python package and Lambda layer
make build

# Build just the Python package
make build-lib

# Build just the Lambda layer
make build-layer
```

<a name="testing-section"></a>
### Testing

```bash
# Run all tests including dockerized Lambda tests
make test

# Run unit tests only
make test-unit

# Run lambda integration tests only (requires Docker)
make test-lambda
```

<a name="releasing-section"></a>
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

<a name="metadata-section"></a>
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