#!/usr/bin/env bash

#
# Build the gnupg binary for Amazon Linux 2 and Amazon Linux 2023 from source.
# Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for latest versions of gnupg.
#
# Run ./build_gpg.sh for usage info
#

# Overridable environment vars
GNUPG_VERSION="${GNUPG_VERSION:-1.4.23}"

# Tarball location
GNUPG_TARBALL="gnupg-$GNUPG_VERSION.tar.bz2"

# Print usage info
print_help() {
    echo ""
    echo "Build the GnuPG binary (gpg) from source for Amazon Linux 2 and Amazon Linux 2023."
    echo "For use in a lambda function, the binary is built in Docker containers."
    echo "Note that it is recommended you use the default version of gnupg, others have not been tested."
    echo ""
    echo "Configure with environment variables:"
    echo "  export GNUPG_VERSION=\"1.4.23\"                     Filename of gnupg tarball to use (optional, current/default value is $GNUPG_VERSION)"
    echo ""
    echo "Commands:"
    echo "  ./build_gpg.sh build        Build GnuPG binaries using Docker"
    echo "  ./build_gpg.sh build_docker Build gpg binary inside a Docker container (used internally)"
    echo "  ./build_gpg.sh release      Release the gpg binary to artifactory"
    echo ""
}

# Build the gpg binary using Docker
build() {
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

    # Extract binaries to temp directories
    mkdir -p "${TEMP_DIR}/al2"
    mkdir -p "${TEMP_DIR}/al2023"
    
    echo "Extracting AL2 binary to ${TEMP_DIR}/al2/..."
    unzip -o "${OUTPUT_DIR}/gnupg-bin-${GNUPG_VERSION}-al2-x86_64.zip" -d "${TEMP_DIR}/al2"
    
    if [ -f "${OUTPUT_DIR}/gnupg-bin-${GNUPG_VERSION}-al2023-x86_64.zip" ]; then
        echo "Extracting AL2023 binary to ${TEMP_DIR}/al2023/..."
        unzip -o "${OUTPUT_DIR}/gnupg-bin-${GNUPG_VERSION}-al2023-x86_64.zip" -d "${TEMP_DIR}/al2023"
    fi

    echo "Build complete! Binaries are available in ${OUTPUT_DIR}/ and extracted to ${TEMP_DIR}/"
    ls -la "${OUTPUT_DIR}/"
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

# Release the gpg binaries to artifactory
release() {
    if [[ -z "$ARTIFACTORY_USER" || -z "$ARTIFACTORY_PASSWORD" ]]; then
        echo "Unable to publish to experian artifactory, ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD env vars are not set"
        exit 1
    fi

    # Get script dir and project root
    SCRIPT_DIR=$(dirname "$0")
    PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
    OUTPUT_DIR="${PROJECT_ROOT}/dist/gnupg"
    
    # Check if output directory exists
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo "Error: Output directory $OUTPUT_DIR not found. Run build first."
        exit 1
    fi
    
    # Check for zip files
    ZIP_FILES=("$OUTPUT_DIR"/gnupg-bin-*.zip)
    if [ ${#ZIP_FILES[@]} -eq 0 ] || [ ! -f "${ZIP_FILES[0]}" ]; then
        echo "Error: No zip files found in $OUTPUT_DIR. Run build first."
        exit 1
    fi
    
    echo "Found the following files to publish:"
    for file in "${ZIP_FILES[@]}"; do
        echo "  $(basename "$file")"
    done
    
    echo "Are you sure you want to publish these files to experian artifactory? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        echo "Aborting publish"
        exit 1
    fi

    # Publish each zip file
    for file in "${ZIP_FILES[@]}"; do
        filename=$(basename "$file")
        echo "Publishing $filename to experian artifactory batch-products-local repository..."
        curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -T "$file" \
            "https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/$filename"
        
        if [ $? -eq 0 ]; then
            echo "Successfully published $filename"
        else
            echo "Failed to publish $filename"
        fi
    done
    
    echo "All files published successfully!"
}

# Fetch the gpg binaries from artifactory
fetch() {
    if [[ -z "$ARTIFACTORY_USER" || -z "$ARTIFACTORY_PASSWORD" ]]; then
        echo "Unable to fetch from experian artifactory, ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD env vars are not set"
        exit 1
    fi

    # Get script dir and project root
    SCRIPT_DIR=$(dirname "$0")
    PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
    OUTPUT_DIR="${PROJECT_ROOT}/dist/gnupg"
    TEMP_DIR="${PROJECT_ROOT}/temp"
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "${TEMP_DIR}/al2"
    mkdir -p "${TEMP_DIR}/al2023"
    
    # Define the binaries to fetch
    AL2_ZIP="gnupg-bin-${GNUPG_VERSION}-al2-x86_64.zip"
    AL2023_ZIP="gnupg-bin-${GNUPG_VERSION}-al2023-x86_64.zip"
    
    # Fetch AL2 binary
    echo "Fetching $AL2_ZIP from artifactory..."
    curl -f -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" \
        -o "${OUTPUT_DIR}/${AL2_ZIP}" \
        "https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/${AL2_ZIP}"
    
    if [ $? -eq 0 ]; then
        echo "Successfully downloaded $AL2_ZIP"
        echo "Extracting AL2 binary to ${TEMP_DIR}/al2/..."
        unzip -o "${OUTPUT_DIR}/${AL2_ZIP}" -d "${TEMP_DIR}/al2"
    else
        echo "Failed to download $AL2_ZIP"
        exit 1
    fi
    
    # Fetch AL2023 binary
    echo "Fetching $AL2023_ZIP from artifactory..."
    curl -f -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" \
        -o "${OUTPUT_DIR}/${AL2023_ZIP}" \
        "https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/${AL2023_ZIP}"
    
    if [ $? -eq 0 ]; then
        echo "Successfully downloaded $AL2023_ZIP"
        echo "Extracting AL2023 binary to ${TEMP_DIR}/al2023/..."
        unzip -o "${OUTPUT_DIR}/${AL2023_ZIP}" -d "${TEMP_DIR}/al2023"
    else
        echo "Note: $AL2023_ZIP not found or failed to download (this is optional)"
    fi
    
    echo "Fetch complete! Binaries are available in ${OUTPUT_DIR}/ and extracted to ${TEMP_DIR}/"
    ls -la "${OUTPUT_DIR}/"
}

# Run the commands
if [[ "$1" == "build" ]]; then
    build
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