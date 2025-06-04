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
    echo "  export USE_DOCKER=\"true\"                           Set to true to build using Docker instead of EC2 (optional, default is false)"
    echo "  export GNUPG_EC2_HOST=\"10.10.10.10\"               EC2 host to build the gpg binary on (required for EC2 build)"
    echo "  export GNUPG_EC2_SSH_KEY=\"~/.ssh/yourkey.pem\"     SSH key to use to connect to the EC2 host (required for EC2 build)"
    echo "  export GNUPG_VERSION=\"1.4.23\"                     Filename of gnupg tarball to use (optional, current/default value is $GNUPG_VERSION)"
    echo "  export GNUPG_TARGET_OS=\"al2-x86_64\"               Target OS to build the gpg binary for (optional, current/default value is $GNUPG_TARGET_OS)"
    echo ""
    echo "Commands:"
    echo "  ./build_gpg.sh build        Build on a remote EC2 instance specified by env vars"
    echo "  ./build_gpg.sh build_ec2    Build gpg binary (if you are already on target EC2 instance)"
    echo "  ./build_gpg.sh build_docker Build gpg binary inside a Docker container"
    echo "  ./build_gpg.sh release      Release the gpg binary to artifactory"
    echo ""
}

# Build the gpg binary (this part runs locally, connects to ec2 instance to build)
build() {
    # Check if we should use Docker or EC2
    if [[ "${USE_DOCKER:-true}" == "true" ]]; then
        build_with_docker
    else
        build_with_ec2
    fi
}

# Build using EC2 instance
build_with_ec2() {
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

# Build using Docker containers
build_with_docker() {
    # Get script dir and project root
    SCRIPT_DIR=$(dirname "$0")
    PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
    
    # Create temp and output directories
    TEMP_DIR="${PROJECT_ROOT}/temp"
    OUTPUT_DIR="${PROJECT_ROOT}/dist/gnupg"
    mkdir -p "$TEMP_DIR"
    mkdir -p "$OUTPUT_DIR"

    # Download GnuPG source tarball if it doesn't exist
    if [ ! -f "${TEMP_DIR}/${GNUPG_TARBALL}" ]; then
        echo "Downloading GnuPG source tarball..."
        curl -o "${TEMP_DIR}/${GNUPG_TARBALL}" "https://www.gnupg.org/ftp/gcrypt/gnupg/${GNUPG_TARBALL}"
    else
        echo "Found existing tarball: ${TEMP_DIR}/${GNUPG_TARBALL}"
    fi

    # Function to build for a specific OS
    build_for_os() {
        local os_name=$1
        local os_tag=$2
        local dockerfile=$3
        local is_required=$4
        
        echo "Building GnuPG binary for ${os_name}..."
        
        # Try with network host mode and increased timeout
        DOCKER_BUILDKIT=1 docker build \
            --network=host \
            --build-arg GNUPG_VERSION=${GNUPG_VERSION} \
            --build-arg GNUPG_TARGET_OS=${os_tag} \
            --progress=plain \
            -t pgpcrypto-gnupg-${os_tag} \
            -f "${PROJECT_ROOT}/${dockerfile}" \
            "${PROJECT_ROOT}" || {
                
            # If that fails, try with bridge network and increased timeout
            echo "Retrying ${os_name} build with bridge network..."
            DOCKER_BUILDKIT=1 docker build \
                --network=bridge \
                --build-arg GNUPG_VERSION=${GNUPG_VERSION} \
                --build-arg GNUPG_TARGET_OS=${os_tag} \
                --progress=plain \
                -t pgpcrypto-gnupg-${os_tag} \
                -f "${PROJECT_ROOT}/${dockerfile}" \
                "${PROJECT_ROOT}"
        }
        
        if [ $? -eq 0 ]; then
            docker run --rm \
                -v "${OUTPUT_DIR}:/output" \
                -v "${TEMP_DIR}/${GNUPG_TARBALL}:/build/${GNUPG_TARBALL}" \
                pgpcrypto-gnupg-${os_tag}
            return 0
        else
            if [ "$is_required" = "true" ]; then
                echo "Error: Failed to build ${os_name} image"
                return 1
            else
                echo "Warning: Failed to build ${os_name} image, skipping this build"
                return 0
            fi
        fi
    }
    
    # Build for Amazon Linux 2
    build_for_os "Amazon Linux 2" "al2-x86_64" "Dockerfile.build.al2" "true" || exit 1
    
    # Build for Amazon Linux 2023
    build_for_os "Amazon Linux 2023" "al2023-x86_64" "Dockerfile.build.al2023" "false"

    echo "Build complete! Binaries are available in ${OUTPUT_DIR}/"
    ls -la "${OUTPUT_DIR}/"
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

# Build the gpg binary (this part runs inside docker container)
build_docker() {
    # Create working directory
    WORKDIR="/build"
    OUTPUT_DIR="${OUTPUT_DIR:-/output}"
    mkdir -p $OUTPUT_DIR

    # The tarball should already be mounted in the container
    if [ ! -f "$GNUPG_TARBALL" ]; then
        echo "Error: Tarball $GNUPG_TARBALL not found in container"
        echo "It should be mounted from the host system"
        exit 1
    fi

    # Check for required commands
    for cmd in bzip2 make gcc tar; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: Required command '$cmd' not found"
            exit 1
        fi
    done

    # Extract the tarball and build gnupg
    echo "Extracting tarball: $GNUPG_TARBALL..."
    tar -xjf $GNUPG_TARBALL || { 
        echo "Failed to extract tarball with tar -xjf, trying bzip2 and tar separately"; 
        bzip2 -dc $GNUPG_TARBALL | tar -xf -; 
    }
    
    GNUPG_DIRNAME=$(tar -tf $GNUPG_TARBALL 2>/dev/null | head -1 | cut -f1 -d"/") || \
    GNUPG_DIRNAME="gnupg-$GNUPG_VERSION"
    
    if [ ! -d "$WORKDIR/$GNUPG_DIRNAME" ]; then
        echo "Error: Directory $WORKDIR/$GNUPG_DIRNAME not found after extraction"
        ls -la $WORKDIR
        exit 1
    fi
    
    cd $WORKDIR/$GNUPG_DIRNAME
    echo "Configuring GnuPG..."
    ./configure --disable-card-support --disable-agent-support --disable-asm || {
        echo "Configure failed. Contents of directory:"
        ls -la
        exit 1
    }
    
    # Check if we're on AL2023 and need the -fcommon flag
    if [[ "$GNUPG_TARGET_OS" == *"al2023"* ]]; then
        echo "Building GnuPG with -fcommon flag for AL2023..."
        make CFLAGS="-fcommon"
    else
        echo "Building GnuPG..."
        make
    fi

    # Check if build succeeded
    if [ ! -f "$WORKDIR/$GNUPG_DIRNAME/g10/gpg" ]; then
        echo "Error: Build failed, gpg binary not found"
        echo "Checking for any gpg binary in the build directory..."
        find $WORKDIR -name gpg -type f
        exit 1
    fi

    # Copy the gpg binary to the output location
    cp $WORKDIR/$GNUPG_DIRNAME/g10/gpg $WORKDIR/gpg
    
    # Check if the binary is statically linked
    echo "Checking if binary is statically linked..."
    file $WORKDIR/gpg
    
    # Create zip file with version
    ZIP_FILE="$OUTPUT_DIR/gnupg-bin-$GNUPG_VERSION-$GNUPG_TARGET_OS.zip"
    echo "Creating zip file: $ZIP_FILE..."
    zip -j $ZIP_FILE $WORKDIR/gpg
    
    echo "GnuPG binary built and packaged: $ZIP_FILE"
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
elif [[ "$1" == "build_docker" ]]; then
    build_docker
elif [[ "$1" == "release" ]]; then
    release
elif [[ "$1" == "fetch" ]]; then
    fetch
else
    print_help
    exit 1
fi
