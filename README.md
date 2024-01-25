# Library and Lambda Layer for PGP Encryption and Decryption

This is a project around python-gnupg to simplify PGP encryption and decryption, especially within a lambda function.

This will build the gpg binary from source on an Amazon Linux 2 environment, since lambda containers do not have a full gpg implementation available.

## Prerequisites

* An `Amazon Linux 2` EC2 instance that you have access to via ssh
* An s3 bucket that you have access to locally and from your ec2 instance that uses kms object encryption

## Build, Test, Deploy

This will build the GnuPG binary from source for the Amazon Linux 2 environment, then package the binary up with the lambda layer.

The build output is `dist/lambda_layer.zip`.

Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for versions of gnupg, and update `build_gpg.sh` file `GNUPG_TARBALL` var if you want a different version.  Note that the version was chosen because it builds successfully, newer versions do not have the right dependency library versions available for `Amazon Linux 2`.

*Note: you must have valid aws credentials and the aws cli installed to run many of these commands.*

```bash

# Set environment variables for fetching the gpg binary (will look for object named "gpg" at this location)
export GNUPG_S3_LOCATION="s3://mybucket/gnupg-python-lambda"
export GNUPG_S3_KMS_KEY="arn:aws:kms:us-east-1:123456789012:key/123456"

# Set environment variables for building the gpg binary from scratch on ec2
export GNUPG_EC2_HOST="10.10.111.222"
export GNUPG_EC2_SSH_KEY="~/.ssh/id_rsa"

# Build the project
make build

# Run all tests (local and in docker)
make test

# Deploy the lambda layer
make deploy LAYER_NAME=my-lambda-layer

# Help for more options
make
```

## Usage

Simplify the usage and setup for basic encryption / decryption of files.

```python
from pgpcrypto import pgp

pgpw = pgp.PgpWrapper(
    key_id: 'Test User', # recipient name, email, or key id, fingerprint
    passphrase: 'Passphrase12345',
    public_key: open('test.pub.asc').read(),
    secret_key: open('test.sec.asc').read(),
)

pgpw.encrypt_file("file.txt", "encrypted_file.txt.pgp")

pgpw.decrypt_file("encrypted_file.txt.pgp", "decrypted_file.txt")
```

You can also import additional keys.

```python
# Import keys from a file
pgpw.import_key_file('path/to/ascii_key.pem')

# Import keys from a string
ascii_str = open('path/to/ascii_key.pem').read()
pgpw.import_keys(ascii_str)

# Fetch metadata on keys
pgpw.count_keys()
pgpw.get_keys()
```

The `gpg` binary comes bundled with the `lambda_layer.zip` file.  The default values for gpgbinary and gnupghome are for use as a lambda layer, but you can override them if using as a library in another location.

```python
pgpw = pgp.PgpWrapper(
    key_id: 'Test User', # recipient name, email, or key id, fingerprint
    passphrase: 'Passphrase12345',
    public_key: open('test.pub.asc').read(),
    secret_key: open('test.sec.asc').read(),
    gpgbinary: '/opt/python/gpg', # showing default value
    gnupghome: '/tmp/.gnupghome', # showing default value
)
```