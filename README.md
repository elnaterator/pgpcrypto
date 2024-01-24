# Build GPG Binary for Amazon Linux 2

## Prerequisites

* A running `Amazon Linux 2` EC2 instance that you have access to via ssh
* An s3 bucket that you have access to locally and from your ec2 instance that uses kms object encryption

## Build and Test

This will build the GnuPG binary from source for the Amazon Linux 2 environment, then package the binary up with the lambda layer.

The build output is `dist/lambda_layer.zip`.

Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for versions of gnupg, and update `build_gpg.sh` file `GNUPG_TARBALL` var if you want a different version.  Note that the version was chosen because it builds successfully, newer versions do not have the right dependency library versions available for `Amazon Linux 2`.

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
make deploy LAYER_NAME=my-layer

# Help for more options
make

```


    


