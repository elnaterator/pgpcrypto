# Library and Lambda Layer for PGP Encryption and Decryption

This is a project to simplify PGP encryption and decryption for lambda functions, and especially to solve the problem of not having a full-featured `gpg` executable available. This is intended for python3.10 or python3.11 runtimes.

* Library `pgpcrypto` with simple API for encryption and decryption of files.
* Build a `gpg` binary from source for `Amazon Linux 2` and package with `lambda_layer.zip`.
* Test in lambda docker image locally.
* Deploy to lambda layer.

## Prerequisites

* To deploy lambda layers or store your pre-built gpg binary in s3:
  * AWS CLI
* To build the `gpg` binary from source:
  * An EC2 instance with `Amazon Linux 2`.

## Build, Test, Deploy

This will build the GnuPG binary from source for the Amazon Linux 2 environment, then package the binary up with the lambda layer.

The build output is `dist/lambda_layer.zip`.

Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for versions of gnupg, and update `build_gpg.sh` file `GNUPG_TARBALL` var if you want a different version.  Note that the version was chosen because it builds successfully, newer versions do not have the right dependency library versions available for `Amazon Linux 2`.

*Note: you must have valid aws credentials and the aws cli installed to run many of these commands.*

```bash
# Set S3 vars of gpg binary if you have one already
export GNUPG_S3_LOCATION="s3://mybucket/gnupg-python-lambda/gpg"
export GNUPG_S3_KMS_KEY="arn:aws:kms:us-east-1:123456789012:key/123456"

# Set EC2 vars for building the gpg binary from source
export GNUPG_EC2_HOST="10.10.111.222"
export GNUPG_EC2_SSH_KEY="~/.ssh/id_rsa"

# Build the project
make build

# Run all tests (unittests and then run tests/lambda.py in docker container)
make test

# Deploy to layer
make deploy LAYER=my-lambda-layer

# Release to experian artifactory
make release-experian

# More options
make
```

To publish you can do something like the following

```bash
# Deploy python library to pypi repo such as artifactory (must configure poetry with repo named my-artifactory)
poetry publish --repository my-artifactory

# Upload lambda layer zip file to central location
curl -u YourUsername:YourPassword -T dist/lambda_layer.zip https://my-artifactory/artifactory/my-generic-repo/gnupg-python-lambda-layer/gnupg-python-lambda-layer-0.1.0.zip
```

## Usage

Simplify the usage and setup for basic encryption / decryption of files.

```python
from pgpcrypto import pgp

# No arguments needed when using as a lambda layer (see below for other use cases)
pgpw = pgp.PgpWrapper()

# Import a public key for encryption
pgpw.import_public_key(
    public_key: open('test.pub.asc').read(),
    recipient: 'test.user@example.com', # Name, email, keyid, or fingerprint
)

# Encrypt files
pgpw.encrypt_file("file.txt", "encrypted_file.pgp")

# Import a secret key for decryption
pgpw.import_secret_key(
    secret_key: open('test.sec.asc').read(),
    passphrase: 'Passphrase12345',
)

# Decrypt files
pgpw.decrypt_file("encrypted_file.pgp", "decrypted_file.txt")
```

The `gpg` binary comes bundled inside `dist/lambda_layer.zip` file.  The default values for gpgbinary and gnupghome are for use as a lambda layer, but you can override them if using as a library in another location.

```python
pgpw = pgp.PgpWrapper(
    gpgbinary = '/opt/python/gpg', # default value shown
    gnupghome = '/tmp/.gnupghome', # default value shown
)
```

You can add additional secret keys.

```python
# Import more secret keys
pgpw.import_secret_key(
    secret_key: open('another.sec.asc').read(),
    passphrase: 'AnotherPassphrase12345',
)

# Decrypt using either key
pgpw.decrypt_file("encrypted_file.pgp", "decrypted_file.txt")
pgpw.decrypt_file("another_file.pgp", "another_file.txt")
```

Other things you can do

```python
# Fetch metadata on all keys in keystore
pgpw.get_keys()
```

If you need to do more than the wrapper library offers, you can access the underlying gpg instance from the `python-gnupg` library as well.

```python
# Get the instance of gnupg.GPG() from the python-gnupg library
pgpw.gpg.get_recipients(ascii_encrypted_message)
```