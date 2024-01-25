#!/usr/bin/env bash

#
# Build the gnupg binary for Amazon Linux 2 from source. Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for latest versions of gnupg.
#
# Run ./build_gpg.sh for usage info
#

# Update these to the location of the gnupg tarball
GNUPG_TARBALL="gnupg-1.4.23.tar.bz2"

# Print usage info
print_help() {
    echo ""
    echo "Build the gpg binary for Amazon Linux 2 from source. See https://www.gnupg.org/ftp/gcrypt/gnupg/ for versions of gnupg."
    echo ""
    echo "Configure with environment variables:"
    echo "  export GNUPG_S3_LOCATION=\"s3://yourbucket/yourprefix\"                         S3 location for the gpg binary"
    echo "  export GNUPG_S3_KMS_KEY=\"arn:aws:kms:us-east-1:123456789012:key/123456...\"    KMS key used to encrypt the s3 objects"
    echo "  export GNUPG_EC2_HOST=\"10.10.10.10\"                                           EC2 host to build the gpg binary on"
    echo "  export GNUPG_EC2_SSH_KEY=\"~/.ssh/yourkey.pem\"                                 SSH key to use to connect to the EC2 host"
    echo ""
    echo "Commands:"
    echo "  ./build_gpg.sh fetch        Download the gpg binary from s3 location"
    echo "  ./build_gpg.sh build        Build the gpg binary on the EC2 host"
    echo ""
    echo "Notes:"
    echo "  - Update GNUPG_TARBALL to point to the correct gnupg version (see https://www.gnupg.org/ftp/gcrypt/gnupg/)"
    echo ""
}

fetch() {

    if [[ -z "${GNUPG_S3_LOCATION}" ]]; then
        echo -e "\nError: missing environment var: GNUPG_S3_LOCATION"
        print_help
        exit 1
    fi

    aws s3 cp $GNUPG_S3_LOCATION/gpg .

}

push() {

    # If we have a s3 location, push the tarball to s3
    if [[ -n "${GNUPG_S3_LOCATION}" ]]; then
        echo "Pushing gpg binary to s3: $GNUPG_S3_LOCATION/gpg..."
        if [ -n "$GNUPG_S3_KMS_KEY" ]; then
            aws s3 cp ./gpg $GNUPG_S3_LOCATION/gpg --sse aws:kms --sse-kms-key-id $GNUPG_S3_KMS_KEY
        else
            aws s3 cp ./gpg $GNUPG_S3_LOCATION/gpg
        fi
    else
        echo "Missing environment var: GNUPG_S3_LOCATION, skipping push to s3."
    fi

    exit $?

}

build() {

    if [[ -z "${GNUPG_EC2_HOST}" || -z "${GNUPG_EC2_SSH_KEY}" ]]; then
        echo -e "\nError: missing environment vars: GNUPG_EC2_HOST, GNUPG_EC2_SSH_KEY"
        print_help
        exit 1
    fi

    # Get script dir
    SCRIPT_DIR=$(dirname "$0")

    # Download tarball if it doesn't exist
    if [ ! -f "$GNUPG_TARBALL" ]; then
        echo "Download tarball: $GNUPG_TARBALL..."
        wget https://www.gnupg.org/ftp/gcrypt/gnupg/$GNUPG_TARBALL
    else
        echo "Found existing tarball: $GNUPG_TARBALL. Delete it if you want to download again."
    fi

    echo "Copy tarball and build script to ec2 instance: $GNUPG_TARBALL, $SCRIPT_DIR/build_gpg.sh -> $GNUPG_EC2_HOST:/home/ec2-user/"
    scp -i $GNUPG_EC2_SSH_KEY $GNUPG_TARBALL $SCRIPT_DIR/build_gpg.sh ec2-user@$GNUPG_EC2_HOST:/home/ec2-user/

    echo "Run build on ec2 instance: $GNUPG_EC2_HOST..."
	ssh -i $GNUPG_EC2_SSH_KEY ec2-user@$GNUPG_EC2_HOST "chmod +x build_gpg.sh && ./build_gpg.sh build_ec2"

    echo "Fetch gpg binary from ec2 instance: $GNUPG_EC2_HOST -> ./gpg"
    scp -i $GNUPG_EC2_SSH_KEY ec2-user@$GNUPG_EC2_HOST:/home/ec2-user/gpg ./gpg

}

# Build the gpg binary (this part runs on ec2 instance)
build_ec2() {

    # Install dependencies
    sudo yum -y groupinstall "Development Tools"
    sudo yum -y install openssl-devel bzip2-devel libffi-devel libgpg-error libgcrypt libassuan libksba npth

    # Create the working dir
    HOMEDIR="/home/ec2-user"
    WORKDIR="$HOMEDIR/gnupg-python-lambda"
    mkdir -p $WORKDIR
    cd $WORKDIR

    # Move the tarball to the working dir
    mv /home/ec2-user/$GNUPG_TARBALL $WORKDIR/

    # Extract the tarball and build gnupg
    tar -xjf $GNUPG_TARBALL
    GNUPG_DIRNAME=$(tar -tf $GNUPG_TARBALL | head -1 | cut -f1 -d"/")
    cd $WORKDIR/$GNUPG_DIRNAME
    /bin/bash $WORKDIR/$GNUPG_DIRNAME/configure
    make CLFAGS='-static'

    # Copy the gpg binary to the home dir
    cp $WORKDIR/$GNUPG_DIRNAME/g10/gpg $HOMEDIR/

}

# Run the commands
if [[ "$1" == "fetch" ]]; then
    fetch
elif [[ "$1" == "build" ]]; then
    build
    push
elif [[ "$1" == "build_ec2" ]]; then
    build_ec2
else
    print_help
    exit 1
fi
