#!/usr/bin/env bash

#
# Build the gnupg binary for Amazon Linux 2 from source. Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for latest versions of gnupg.
#
# Run ./build_gpg.sh for usage info
#

# Overridable environment vars
GNUPG_VERSION="${GNUPG_VERSION:-1.4.23}"
GNUPG_TARGET_OS="${GNUPG_TARGET_OS:-al2-x86_64}"

# Tarball location
GNUPG_TARBALL="gnupg-$GNUPG_VERSION.tar.bz2"

# Print usage info
print_help() {
    echo ""
    echo "Build the GnuPG binary (gpg) from source for a target OS. See https://www.gnupg.org/ftp/gcrypt/gnupg/ for versions of gnupg."
    echo "This will connect to a remote EC2 instance to build the gpg binary, for use in a lambda function this should be Amazon Linux 2 or Amazon Linux 2023"
    echo "Note that it is recommended you use the default version of gnupg, others have not been tested."
    echo ""
    echo "Configure with environment variables:"
    echo "  export GNUPG_EC2_HOST=\"10.10.10.10\"               EC2 host to build the gpg binary on"
    echo "  export GNUPG_EC2_SSH_KEY=\"~/.ssh/yourkey.pem\"     SSH key to use to connect to the EC2 host"
    echo "  export GNUPG_VERSION=\"1.4.23\"                     Filename of gnupg tarball to use (optional, current/default value is $GNUPG_VERSION)"
    echo "  export GNUPG_TARGET_OS=\"al2-x86_64\"               Target OS to build the gpg binary for (optional, current/default value is $GNUPG_TARGET_OS)"
    echo ""
    echo "Commands:"
    echo "  ./build_gpg.sh build        Build on a remote EC2 instance specified by env vars"
    echo "  ./build_gpg.sh build_ec2    Build gpg binary (if you are already on target EC2 instance)"
    echo "  ./build_gpg.sh release      Release the gpg binary to artifactory"
    echo ""
}

# Build the gpg binary (this part runs locally, connects to ec2 instance to build)
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

    # Create clean working dir and clean previous gpg build
    HOMEDIR="/home/ec2-user"
    WORKDIR="$HOMEDIR/gnupg-build"
    rm -rf $WORKDIR
    mkdir -p $WORKDIR
    rm -f $HOMEDIR/gpg
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

# Release the gpg binary to artifactory
release() {

    if [[ -z "$ARTIFACTORY_USER" || -z "$ARTIFACTORY_PASSWORD" ]]; then
        echo "Unable to publish to experian artifactory, ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD env vars are not set"
        exit 1
    fi

    # Build zip file name with version
    ZIP_FILE="gnupg-bin-$GNUPG_VERSION-$GNUPG_TARGET_OS.zip"

    echo "Are you sure you want to publish $ZIP_FILE to experian artifactory? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        echo "Aborting publish"
        exit 1
    fi

    # Zip up gpg binary
    echo "Creating zip file: $ZIP_FILE..."
    zip -r $ZIP_FILE ./gpg

    echo "Publishing gpg binary to experian artifactory batch-products-local repository..."
    curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -T $ZIP_FILE \
        https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/$ZIP_FILE

}

# Fetch the zip file from artifactory
fetch() {
    ZIP_FILE="gnupg-bin-$GNUPG_VERSION-$GNUPG_TARGET_OS.zip"
    echo "Fetching $ZIP_FILE from artifactory..."
    curl -f -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -O \
        https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/$ZIP_FILE
    unzip $ZIP_FILE
}

# Run the commands
if [[ "$1" == "build" ]]; then
    build
elif [[ "$1" == "build_ec2" ]]; then
    build_ec2
elif [[ "$1" == "release" ]]; then
    release
elif [[ "$1" == "fetch" ]]; then
    fetch
else
    print_help
    exit 1
fi
