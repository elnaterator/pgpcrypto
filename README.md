# Python Library and Lambda Layer for PGP Encryption and Decryption

Simplify common PGP encryption and decryption of files in Python3 / AWS / Amazon Linux environments, especially when a full-featured `gpg` executable is not available such the AWS Lambda python runtimes. Tested for AWS Lambda `python3.11` runtime, but should work in many other AWS environments such as AWS Glue, Fargate, EC2, AL2 Docker images, etc.

* Python package with simple API for encryption and decryption of files.
* Lambda layer zip ready to deploy for python3.X runtimes.
* Bundled GnuPG binary compatible with AWS lambda and tools to re-build from source.
* Tested for `python3.11` lambda runtime.
* CLI tools to release to artifactory.

*Note: depends on the [python-gnupg](https://gnupg.readthedocs.io/en/latest/) library*

## Install

### Lambda Layer

Download the lambda layer zip file and deploy, this is the easiest way to use for a lambda function.

```bash
# Download lambda_layer.zip from artifactory
VERSION=""
curl -o lambda_layer.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/lambda_layer-pgpcrypto-$VERSION.zip
```

* Deploy this zip file as a lambda layer (compatible architectures: `x86_64`, compatible runtimes: `python3.11`).
* Create a lambda function (runtime: `python3.11`) and configure to use the layer.

### Python library

For other use cases (Glue, ECS, EC2, Lambda without a layer, etc.) you can download the GnuPG binary and add the pgpcrypto library to your project, then run in any Amazon Linux 2 based environment.

```bash
# Poetry
poetry source add artifactory https://artifacts.experian.local/artifactory/api/pypi/pypi/simple
poetry add pgpcrypto

# Pip
pip install -i https://artifacts.experian.local/artifactory/api/pypi/pypi/simple pgpcrypto

# Download GnuPG binary and unzip
VERSION="1.4.23-al2-x86_64"
curl -o gnupg-bin.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/gnupg-bin-$VERSION.zip
unzip gnupg-bin.zip # contains `gpg` binary file
chmod +x ./gpg
```

For other runtimes you may also bring your own gpg binary or build from source (not tested, but should work).

## Usage

```python
from tempfile import TemporaryDirectory
from pgpcrypto.pgp import PgpWrapper

# Should use a temporary directory
with TemporaryDirectory(dir="/tmp") as tmpdir:

    # TODO Fetch your key data (i.e. from secrets manager)
    pubkey = open(f"{tmpdir}/test.pub.asc").read() # ascii armored public key
    seckey = open(f"{tmpdir}/test.sec.asc").read() # ascii armored secret key
    recipient = 'test.user@example.com'
    passphrase = 'Passphrase12345'

    # TODO Fetch your input file
    file_path = f"{tmpdir}/file.txt"

    # Initialize the pgp wrapper
    pgpw = PgpWrapper(
      gnupghome = f"{tmpdir}/.gnupghome", # GnuPG stores keys here
      gpgbinary = '/opt/python/gpg', # default value (shown) works for lambda layer
    )

    # Import a public key for encryption
    pgpw.import_public_key(
        public_key = pubkey,
        recipient = recipient, # Name, email, keyid, or fingerprint
        default = True, # Optional, first key imported is default by default
    )

    # Encrypt files (using the default key)
    pgpw.encrypt_file(file_path, f"{tmpdir}/encrypted_file.pgp")

    # Import a secret key for decryption
    pgpw.import_secret_key(
        secret_key = seckey,
        passphrase = passphrase,
    )

    # Decrypt files
    pgpw.decrypt_file(f"{tmpdir}/encrypted_file.pgp", f"{tmpdir}/decrypted_file.txt")

    #
    # Multiple key support
    #

    # Import additional secret keys (i.e. for key rotation)
    pgpw.import_secret_key(
        secret_key = open(f"{tmpdir}/previous.sec.asc").read(),
        passphrase = 'PreviousPassphrase12345',
    )

    # Decrypt using either key, keyid to use will be extracted from encrypted message
    pgpw.decrypt_file(f"{tmpdir}/new_encrypted_file.pgp", f"{tmpdir}/decrypted_file1.txt")
    pgpw.decrypt_file(f"{tmpdir}/old_encrypted_file.pgp", f"{tmpdir}/decrypted_file2.txt")

    # Import additional public keys
    pgpw.import_public_key(
        public_key: open(f"{tmpdir}/fred.pub.asc").read(),
        recipient: "fred@example.com", # Name, email, keyid, or fingerprint
        default: False, # Optional, subsequent keys are not default by default
    )

    # Encrypt files for specific recipients
    # Note: recipient is optional for test user's key, since it is the default key
    pgpw.encrypt_file(file_path, f"{tmpdir}/for_fred.pgp", "fred@example.com") # can be name, email, keyid, or fingerprint
    pgpw.encrypt_file(file_path, f"{tmpdir}/for_test_user.pgp", "test.user@example.com")

    #
    # Other things you can do
    #

    # Fetch metadata on all keys in keystore
    keys = pgpw.get_keys()
    print(keys) # [{'type': 'pub', ... },{'type': 'sec', ... }]

    # Get the instance of gnupg.GPG() from the python-gnupg library to do more things if needed
    keyids = pgpw.gpg.get_recipients(open(f"{tmpdir}/encrypted_file.pgp").read())
    print(keyids) # ["75188ED1"]
```

# Contributing

## Prerequisites

* **Python 3.11**
* **Poetry**
* **Docker** for testing locally
* **AWS CLI** to deploy to AWS Lambda layer
* **EC2 instance running Amazon Linux 2** to build GnuPG binary from source (optional)

## Quick Start

*Note: See [Python Development Environment Setup](https://pages.experian.local/display/MABP/Python+Development+Environment+Setup) to configure access to artifactory.*

Build output is `dist/pgpcrypto-<version>-py3-none-any.whl` and `dist/lambda_layer.zip`.  Note that this will fetch an existing GnuPG binary `gpg` from artifactory. See below if you want to build GnuPG from source.

```bash
# Build the project
make build

# Run tests
make test # run unit tests and then local lambda test via docker
make unittest # run unit tests only

# More options
make
```


## Release

The release process pushes the python library to [pypi-local PyPI repo in Artifactory](https://artifacts.experian.local/ui/repos/tree/General/pypi-local/pgpcrypto), and the lambda layer zip file to [batch-products-local Generic repo in Artifactory](https://artifacts.experian.local/ui/repos/tree/General/batch-products-local/pgpcrypto).

```bash
# Set creds for artifactory (must have permission to publish to repos)
export ARTIFACTORY_USER="<lanid>"
export ARTIFACTORY_PASSWORD="<artifactory-api-key>"

# Release `pgpcrypto` and `lambda_layer.zip` to experian artifactory
make release VERSION=""
```

This will
* Update the project version
* Build
* Publish `pgpcrypto` python package to `pypi-local` repo in Experian Artifactory
* Publish `lambda_layer.zip` to `batch-products-local` repo in Experian Artifactory
* Tag the git repo with the version number
* Push the tags to origin


## Build and Release GnuPG Binary

Build a GnuPG binary from source that works in a target OS, zip up the binary and publish to [batch-products-local Generic repo in Artifactory](https://artifacts.experian.local/ui/repos/tree/General/batch-products-local/pgpcrypto).  An EC2 instance running the target OS is required.

Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for versions of GnuPG, and update `scripts/build_gpg.sh` file, `GNUPG_TARBALL` var, to update the version.  Note that the version was chosen for compatibility with AWS Lambda, other versions may not work as expected.

The released zip file will be versioned like `gnupg-bin-$GNUPG_VERSION-$GNUPG_TARGET_OS.zip` for example `gnupg-bin-1.4.23-al2-x86_64.zip`.  The publish will fail if it this version already exists.

```bash
# Set EC2 vars for building the gpg binary from source
export GNUPG_EC2_HOST="10.10.111.222"
export GNUPG_EC2_SSH_KEY="~/.ssh/id_rsa"

# Optionally override the version of gnupg and target OS tag
export GNUPG_VERSION="1.4.23" # determines gnupg source tarball to download, also used in released zip file version
export GNUPG_TARGET_OS="al2-x86_64" # used in released zip file version, should indicate OS of ec2 instance used for build

# Build the gpg binary on the EC2 instance specified
make gpg-build

# Release the updated version of the gpg binary
make gpg-release
```

## Metadata

```discoveryhub
region: NA
bu: CIS
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