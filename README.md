# Python Library and Lambda Layer for PGP Encryption and Decryption

This is a project to simplify PGP encryption and decryption for python lambda functions, and especially to solve the problem of not having a full-featured `gpg` executable available. This is intended for python3.X runtimes up to python3.11 (tested with `python3.11` only).

* Python library with simple API for encryption and decryption of files.
* Lambda layer package ready to deploy for python3.X runtimes.
* Provides a GnuPG binary compatible with AWS lambda runtimes based on Amazon Linux 2 (build from source if different GnuPG version or OS needed)
* Test lambda locally via docker image for `python3.11` lambda runtime environment.
* Tools to release artifacts to artifactory
* Tools to deploy to AWS lambda layer

## Prerequisites

* **Python 3.11**
* **Poetry**
* **Docker** for testing only
* **AWS CLI** if you need to deploy to AWS lambda layer
* **EC2 instance running Amazon Linux 2** if you need to build the GnuPG binary from source

## Quick Start

*Note: See [Python Development Environment Setup](https://pages.experian.local/display/MABP/Python+Development+Environment+Setup) to configure access to artifactory.*

Build output is `dist/pgpcrypto-<version>-py3-none-any.whl` and `dist/lambda_layer.zip`.  Note that this will fetch an existing GnuPG binary `gpg` from artifactory. See below if you want to build GnuPG from source.

```bash
# Build the project
make build

# Run tests
make test # run unit tests and then docker-based lambda tests
make unittest # run unit tests only

# More options
make
```

## Install

### Lambda Layer

For a lambda function the quickest way is to create a layer from the lambda layer zip file, then add the layer to your function.

```bash
# Download lambda_layer.zip from artifactory
VERSION="0.1.1"
curl -o lambda_layer.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/lambda_layer/lambda_layer-pgpcrypto-$VERSION.zip
```

* Deploy this zip file as a lambda layer (compatible architectures: `x86_64`, compatible runtimes: `python3.11`).
* Create a lambda function (runtime: `python3.11`) and configure to use the layer.

### Python library

For other use cases (Glue, ECS, EC2, Lambda without a layer, etc.) you can download the GnuPG binary and add the pgpcrypto library to your project, then run in any Amazon Linux 2 based environment.

```bash
# Download GnuPG binary and unzip
VERSION="1.4.23-al2"
curl -o gnupg-bin.zip https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/gnupg-bin-$VERSION.zip
unzip gnupg-bin.zip # contains `gpg` binary file, run "chmod +x ./gpg" to use

# Poetry
poetry source add artifactory https://artifacts.experian.local/artifactory/api/pypi/pypi/simple
poetry add pgpcrypto

# Pip
pip install -i https://artifacts.experian.local/artifactory/api/pypi/pypi/simple pgpcrypto
```

For other runtimes you may also bring your own gpg binary or build from source (not tested, but should work).

## Usage

```python
from tempfile import TemporaryDirectory
from pgpcrypto.pgp import PgpWrapper

# Should use a temporary directory
with TemporaryDirectory(dir="/tmp") as tmpdir:

    # TODO Fetch your key data from secrets
    pubkey = f"{tmpdir}/test.pub.asc"
    seckey = f"{tmpdir}/test.sec.asc"
    recipient = 'test.user@example.com'
    passphrase = 'Passphrase12345'

    # TODO Fetch your input file
    file_path = "{tmpdir}/file.txt"

    # Initialize the pgp wrapper
    pgpw = PgpWrapper(
      gnupghome = f"{tmpdir}/.gnupghome", # GnuPG stores keys here
      gpgbinary = '/opt/python/gpg', # default value (shown) works for lambda layer
    )

    # Import a public key for encryption
    pgpw.import_public_key(
        public_key = open(pubkey).read(),
        recipient = recipient, # Name, email, keyid, or fingerprint
        default = True, # Optional, first key imported is default by default
    )

    # Encrypt files (use the default key)
    pgpw.encrypt_file(file_path, f"{tmpdir}/encrypted_file.pgp")

    # Import a secret key for decryption
    pgpw.import_secret_key(
        secret_key: open(seckey).read(),
        passphrase: passphrase,
    )

    # Decrypt files
    pgpw.decrypt_file(f"{tmpdir}/encrypted_file.pgp", f"{tmpdir}/decrypted_file.txt")

    # Import additional secret keys, useful for key rotation
    pgpw.import_secret_key(
        secret_key: open(f"{tmpdir}/old.sec.asc").read(),
        passphrase: 'OldPassphrase12345',
    )

    # Decrypt using either key
    pgpw.decrypt_file(f"{tmpdir}/new_encrypted_file.pgp", f"{tmpdir}/decrypted_file1.txt")
    pgpw.decrypt_file(f"{tmpdir}/old_encrypted_file.pgp", f"{tmpdir}/decrypted_file2.txt")

    # Import additional public keys
    pgpw.import_public_key(
        public_key: open(f"{tmpdir}/fred.pub.asc").read(),
        recipient: "fred@example.com", # Name, email, keyid, or fingerprint
        default: False, # Optional, subsequent keys are not default by default
    )

    # Encrypt files for specific recipients
    # Recipient is optional for test user's key, since it is the default key
    pgpw.encrypt_file(file_path, f"{tmpdir}/for_fred.pgp", "fred@example.com")
    pgpw.encrypt_file(file_path, f"{tmpdir}/for_test_user.pgp", "test.user@example.com")

    #
    # Other things you can do
    #

    # Fetch metadata on all keys in keystore
    pgpw.get_keys()

    # Get the instance of gnupg.GPG() from the python-gnupg library to do more things if needed
    pgpw.gpg.get_recipients(ascii_encrypted_message)
```

## Release

The release process pushes the python library to [pypi-local PyPI repo in Artifactory](https://artifacts.experian.local/ui/repos/tree/General/pypi-local/pgpcrypto), and the lambda layer zip file to [batch-products-local Generic repo in Artifactory](https://artifacts.experian.local/ui/repos/tree/General/batch-products-local/pgpcrypto).

```bash
# Set creds for artifactory (must have permission to publish to repos)
export ARTIFACTORY_USER="<lanid>"
export ARTIFACTORY_PASSWORD="<artifactory-api-key>"

# Release `pgpcrypto` and `lambda_layer.zip` to experian artifactory
make release VERSION="0.1.1"
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
artifacts: https://artifacts.experian.local/ui/repos/tree/General/batch-products-local/pgpcrypto/lambda_layer
docs: https://pages.experian.local/display/ARCCOE/PGP+Encryption+and+Decryption+with+Python
contacts:
  technical: Hadzariga, Nathan <nathan.mhadzariga@experian.com>
  product: Hadzariga, Nathan <nathan.mhadzariga@experian.com>
links:
  lambda_layer_artifactory: https://artifacts.experian.local/ui/repos/tree/General/batch-products-local/pgpcrypto/lambda_layer
  pypi_lib_artifactory: https://artifacts.experian.local/ui/repos/tree/General/pypi-local/pgpcrypto
```