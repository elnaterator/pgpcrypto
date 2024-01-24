#!/usr/bin/env bash

#
# Build the gnupg binary for Amazon Linux 2 from source. Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for latest versions of gnupg.
#
# Run ./build_gpg.sh for usage info
#

# Print usage info
print_help() {
    echo ""
    echo "Build the gnupg binary for Amazon Linux 2 from source. Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for latest versions of gnupg."
    echo ""
    echo "Configure:"
    echo "  export GNUPG_S3_LOCATION=\"s3://yourbucket/yourprefix\"                         S3 location to for exchange of gnupg tarball and gpg binary"
    echo "  export GNUPG_S3_KMS_KEY=\"arn:aws:kms:us-east-1:123456789012:key/123456...\"    KMS key used to encrypt the s3 object"
    echo "  export GNUPG_EC2_HOST=\"10.10.10.10\"                                           EC2 host to build the gpg binary on"
    echo "  export GNUPG_EC2_SSH_KEY=\"~/.ssh/yourkey.pem\"                                 SSH key to use to connect to the EC2 host"
    echo ""
    echo "Commands:"
    echo "  ./build_gpg.sh setup        Download the gnupg tarball and push to s3 (run locally)"
    echo "  ./build_gpg.sh build        Build the gpg binary and push to s3 (run on amazon Linux 2 EC2 instance)"
    echo "  ./build_gpg.sh all          Run setup locally, build on remote ec2, then download gpg binary from s3"
    echo ""
    echo "Notes:"
    echo "  - Update GNUPG_TARBALL to point to the correct gnupg version (see https://www.gnupg.org/ftp/gcrypt/gnupg/)"
    echo ""
}

# Update these to the location of the gnupg tarball
GNUPG_TARBALL="gnupg-1.4.23.tar.bz2"
if [[ -z "${GNUPG_S3_LOCATION}" || -z "${GNUPG_S3_KMS_KEY}" || -z "${GNUPG_EC2_HOST}" || -z "${GNUPG_EC2_SSH_KEY}" ]]; then
    echo -e "\nError: missing environment vars: GNUPG_S3_LOCATION, GNUPG_S3_KMS_KEY, GNUPG_EC2_HOST, GNUPG_EC2_SSH_KEY"
    print_help
    exit 1
fi

# If the all arg is passed in, first run setup, then build remotely, then pull the binary down
if [ "$1" == "all" ]; then

    # Run setup locally
    SCRIPT_DIR=$(dirname "$0")
    $SCRIPT_DIR/build_gpg.sh setup

    # Transfer the build script to ec2 instance
    scp -i $GNUPG_EC2_SSH_KEY $SCRIPT_DIR/build_gpg.sh ec2-user@$GNUPG_EC2_HOST:/home/ec2-user/

    # Run build script remotely
    SET_VARS_CMD="export GNUPG_S3_LOCATION=$GNUPG_S3_LOCATION; export GNUPG_S3_KMS_KEY=$GNUPG_S3_KMS_KEY; export GNUPG_EC2_HOST=$GNUPG_EC2_HOST; export GNUPG_EC2_SSH_KEY=$GNUPG_EC2_SSH_KEY"
    BUILD_CMD="chmod +x build_gpg.sh && ./build_gpg.sh build"
	ssh -i $GNUPG_EC2_SSH_KEY ec2-user@$GNUPG_EC2_HOST "$SET_VARS_CMD && $BUILD_CMD"

    # Download the binary from s3
    aws s3 cp $GNUPG_S3_LOCATION/gpg .

    exit $?

fi

# THIS PART RUNS ON YOUR LOCAL MACHINE
# Download the gnupg tarball and push to s3 if the download arg is passed in
if [ "$1" == "setup" ]; then

    # Download tarball if it doesn't exist
    if [ ! -f "$GNUPG_TARBALL" ]; then
        echo "Downloading tarball: $GNUPG_TARBALL..."
        wget https://www.gnupg.org/ftp/gcrypt/gnupg/$GNUPG_TARBALL
    else
        echo "Tarball already exists: $GNUPG_TARBALL. Delete it if you want to download again."
    fi

    echo "Pushing tarball to s3: $GNUPG_S3_LOCATION/$GNUPG_TARBALL..."
    aws s3 cp $GNUPG_TARBALL $GNUPG_S3_LOCATION/ --sse aws:kms --sse-kms-key-id $GNUPG_S3_KMS_KEY

    exit $?

fi

# THIS PART RUNS ON AN AMAZON LINUX 2 EC2 INSTANCE
# Build the gpg binary if the install arg is passed in
if [ "$1" == "build" ]; then

    # Install dependencies
    sudo yum -y groupinstall "Development Tools"
    sudo yum -y install openssl-devel bzip2-devel libffi-devel libgpg-error libgcrypt libassuan libksba npth

    # Create the working dir
    WORKDIR="/home/ec2-user/gnupg-python-lambda"
    mkdir -p $WORKDIR
    cd $WORKDIR

    # Download the gnupg tarball from s3
    aws s3 cp $GNUPG_S3_LOCATION/$GNUPG_TARBALL .

    # Extract the tarball and build gnupg
    tar -xjf $GNUPG_TARBALL
    GNUPG_DIRNAME=$(tar -tf $GNUPG_TARBALL | head -1 | cut -f1 -d"/")
    cd $GNUPG_DIRNAME
    /bin/bash $WORKDIR/$GNUPG_DIRNAME/configure
    make CLFAGS='-static'

    # Push the gpg binary back to s3
    aws s3 cp $WORKDIR/$GNUPG_DIRNAME/g10/gpg $GNUPG_S3_LOCATION/ --sse aws:kms --sse-kms-key-id $GNUPG_S3_KMS_KEY

    exit $?

fi

print_help
exit 1
