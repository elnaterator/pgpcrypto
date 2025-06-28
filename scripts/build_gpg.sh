#!/usr/bin/env bash

#
# Build the gnupg binary for Amazon Linux 2 from source.
# Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for latest versions of gnupg.
#
# Run ./build_gpg.sh for usage info
#

# Set default GnuPG version and target OS
GNUPG_VERSION="2.0.22"
GNUPG_TARGET_OS="al2-x86_64"

# Dependency versions compatible with GnuPG 2.0.22
LIBGPG_ERROR_VERSION="1.27"
LIBGCRYPT_VERSION="1.5.3"
LIBASSUAN_VERSION="2.1.1"
LIBKSBA_VERSION="1.3.0"
LIBPTH_VERSION="2.0.7"

# Tarball locations
GNUPG_TARBALL="gnupg-$GNUPG_VERSION.tar.bz2"
LIBGPG_ERROR_TARBALL="libgpg-error-$LIBGPG_ERROR_VERSION.tar.bz2"
LIBGCRYPT_TARBALL="libgcrypt-$LIBGCRYPT_VERSION.tar.bz2"
LIBASSUAN_TARBALL="libassuan-$LIBASSUAN_VERSION.tar.bz2"
LIBKSBA_TARBALL="libksba-$LIBKSBA_VERSION.tar.bz2"
LIBPTH_TARBALL="pth-$LIBPTH_VERSION.tar.gz"

# Print usage info
print_help() {
    echo ""
    echo "Build the GnuPG binary (gpg) from source for Amazon Linux 2."
    echo "For use in a lambda function, the binary is built in Docker containers."
    echo "Note that it is recommended you use the default version of gnupg, others have not been tested."
    echo ""
    echo "Configure with environment variables:"
    echo "  export GNUPG_VERSION=\"2.0.22\"                     Filename of gnupg tarball to use (optional, current/default value is $GNUPG_VERSION)"
    echo ""
    echo "Commands:"
    echo "  ./build_gpg.sh build        Build GnuPG binary using Docker"
    echo "  ./build_gpg.sh build_docker Build gpg binary inside a Docker container (used internally)"
    echo "  ./build_gpg.sh release      Release the gpg binary to artifactory"
    echo "  ./build_gpg.sh fetch        Fetch the gpg binary from artifactory"
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

    # Download all source tarballs if they don't exist
    download_tarball() {
        local tarball=$1
        local url=$2
        if [ ! -f "${TEMP_DIR}/${tarball}" ]; then
            echo "Downloading ${tarball}..."
            curl -o "${TEMP_DIR}/${tarball}" "${url}"
        else
            echo "Found existing tarball: ${TEMP_DIR}/${tarball}"
        fi
    }
    
    download_tarball "$GNUPG_TARBALL" "https://www.gnupg.org/ftp/gcrypt/gnupg/${GNUPG_TARBALL}"
    download_tarball "$LIBGPG_ERROR_TARBALL" "https://www.gnupg.org/ftp/gcrypt/libgpg-error/${LIBGPG_ERROR_TARBALL}"
    download_tarball "$LIBGCRYPT_TARBALL" "https://www.gnupg.org/ftp/gcrypt/libgcrypt/${LIBGCRYPT_TARBALL}"
    download_tarball "$LIBASSUAN_TARBALL" "https://www.gnupg.org/ftp/gcrypt/libassuan/${LIBASSUAN_TARBALL}"
    download_tarball "$LIBKSBA_TARBALL" "https://www.gnupg.org/ftp/gcrypt/libksba/${LIBKSBA_TARBALL}"
    download_tarball "$LIBPTH_TARBALL" "https://ftp.gnu.org/gnu/pth/${LIBPTH_TARBALL}"

    # Build for Amazon Linux 2
    echo "Building GnuPG binary for Amazon Linux 2..."
    
    # Try with network host mode first (helps with corporate proxies)
    DOCKER_BUILDKIT=1 docker build \
        --network=host \
        --build-arg GNUPG_VERSION=${GNUPG_VERSION} \
        --build-arg GNUPG_TARGET_OS=${GNUPG_TARGET_OS} \
        --progress=plain \
        -t pgpcrypto-gnupg-al2 \
        -f "${PROJECT_ROOT}/Dockerfile.build.al2" \
        "${PROJECT_ROOT}" || {
            
        # If that fails, try with bridge network
        echo "Retrying build with bridge network..."
        DOCKER_BUILDKIT=1 docker build \
            --network=bridge \
            --build-arg GNUPG_VERSION=${GNUPG_VERSION} \
            --build-arg GNUPG_TARGET_OS=${GNUPG_TARGET_OS} \
            --progress=plain \
            -t pgpcrypto-gnupg-al2 \
            -f "${PROJECT_ROOT}/Dockerfile.build.al2" \
            "${PROJECT_ROOT}"
    }
    
    if [ $? -eq 0 ]; then
        docker run --rm \
            -v "${OUTPUT_DIR}:/output" \
            -v "${TEMP_DIR}/${GNUPG_TARBALL}:/build/${GNUPG_TARBALL}" \
            -v "${TEMP_DIR}/${LIBGPG_ERROR_TARBALL}:/build/${LIBGPG_ERROR_TARBALL}" \
            -v "${TEMP_DIR}/${LIBGCRYPT_TARBALL}:/build/${LIBGCRYPT_TARBALL}" \
            -v "${TEMP_DIR}/${LIBASSUAN_TARBALL}:/build/${LIBASSUAN_TARBALL}" \
            -v "${TEMP_DIR}/${LIBKSBA_TARBALL}:/build/${LIBKSBA_TARBALL}" \
            -v "${TEMP_DIR}/${LIBPTH_TARBALL}:/build/${LIBPTH_TARBALL}" \
            pgpcrypto-gnupg-al2
    else
        echo "Error: Failed to build Amazon Linux 2 image"
        exit 1
    fi

    # Extract binary to temp directory
    mkdir -p "${TEMP_DIR}/al2"
    
    echo "Extracting binary to ${TEMP_DIR}/al2/..."
    unzip -o "${OUTPUT_DIR}/gnupg-bin-${GNUPG_VERSION}-${GNUPG_TARGET_OS}.zip" -d "${TEMP_DIR}/al2"

    echo "Build complete! Binary is available in ${OUTPUT_DIR}/ and extracted to ${TEMP_DIR}/al2/"
    ls -la "${OUTPUT_DIR}/"
}

# Build a dependency from pre-downloaded tarball
build_dependency() {
    local name=$1
    local version=$2
    local tarball=$3
    local configure_opts=$4
    
    echo "Building $name $version..."
    
    # Check tarball exists
    if [ ! -f "$tarball" ]; then
        echo "Error: Tarball $tarball not found"
        exit 1
    fi
    
    # Extract
    if [[ "$tarball" == *.tar.gz ]]; then
        tar -xzf "$tarball"
    else
        tar -xjf "$tarball"
    fi
    
    # Build
    local dirname=$(echo "$tarball" | sed 's/\.tar\.[gb]z2\?$//')
    cd "$dirname"
    
    ./configure --prefix=/usr/local $configure_opts
    make -j$(nproc)
    make install
    
    cd ..
    echo "$name $version built and installed successfully"
}

# Build the gpg binary (this part runs inside docker container)
build_docker() {
    # Create working directory
    WORKDIR="/build"
    OUTPUT_DIR="${OUTPUT_DIR:-/output}"
    mkdir -p $OUTPUT_DIR
    
    # Set build environment for static linking
    export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
    export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
    export CPPFLAGS="-I/usr/local/include"
    export LDFLAGS="-L/usr/local/lib -static"
    export CFLAGS="-static"

    # Check for required commands
    for cmd in bzip2 make gcc tar; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: Required command '$cmd' not found"
            exit 1
        fi
    done
    
    # Build dependencies in order
    echo "Building GnuPG dependencies..."
    
    # 1. libgpg-error
    build_dependency "libgpg-error" "$LIBGPG_ERROR_VERSION" "$LIBGPG_ERROR_TARBALL" \
        "--enable-static --disable-shared --disable-nls --disable-languages"
    
    # 2. libgcrypt
    build_dependency "libgcrypt" "$LIBGCRYPT_VERSION" "$LIBGCRYPT_TARBALL" \
        "--enable-static --disable-shared --with-gpg-error-prefix=/usr/local"
    
    # 3. libassuan
    build_dependency "libassuan" "$LIBASSUAN_VERSION" "$LIBASSUAN_TARBALL" \
        "--enable-static --disable-shared --with-gpg-error-prefix=/usr/local"
    
    # 4. libksba
    build_dependency "libksba" "$LIBKSBA_VERSION" "$LIBKSBA_TARBALL" \
        "--enable-static --disable-shared --with-gpg-error-prefix=/usr/local"
    
    # 5. libpth (GNU Portable Threads)
    build_dependency "pth" "$LIBPTH_VERSION" "$LIBPTH_TARBALL" \
        "--enable-static --disable-shared"
    
    # Update library cache
    ldconfig

    # Now build GnuPG
    echo "Building GnuPG $GNUPG_VERSION..."
    
    # Check GnuPG tarball is mounted
    if [ ! -f "$GNUPG_TARBALL" ]; then
        echo "Error: GnuPG tarball $GNUPG_TARBALL not found"
        exit 1
    fi
    
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
    ./configure \
        --prefix=/usr/local \
        --disable-card-support \
        --disable-agent-support \
        --disable-asm \
        --enable-static-rnd=linux \
        --disable-shared \
        --enable-static \
        --without-readline \
        --with-libgpg-error-prefix=/usr/local \
        --with-libgcrypt-prefix=/usr/local \
        --with-libassuan-prefix=/usr/local \
        --with-ksba-prefix=/usr/local \
        --with-pth-prefix=/usr/local || {
        echo "Configure failed. Contents of directory:"
        ls -la
        echo "Config.log contents:"
        cat config.log 2>/dev/null || echo "No config.log found"
        exit 1
    }
    
    echo "Building GnuPG..."
    make

    # Check if build succeeded (GnuPG 2.0.22 creates gpg2, not gpg)
    if [ ! -f "$WORKDIR/$GNUPG_DIRNAME/g10/gpg2" ]; then
        echo "Error: Build failed, gpg2 binary not found"
        echo "Checking for any gpg/gpg2 binary in the build directory..."
        find $WORKDIR -name "gpg*" -type f
        exit 1
    fi

    # Copy the gpg2 binary to the output location as gpg
    cp $WORKDIR/$GNUPG_DIRNAME/g10/gpg2 $WORKDIR/gpg
    
    # Check if the binary is statically linked
    echo "Checking binary information..."
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

    # Get script dir and project root
    SCRIPT_DIR=$(dirname "$0")
    PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
    OUTPUT_DIR="${PROJECT_ROOT}/dist/gnupg"
    
    # Check if output directory exists
    if [ ! -d "$OUTPUT_DIR" ]; then
        echo "Error: Output directory $OUTPUT_DIR not found. Run build first."
        exit 1
    fi
    
    # Define the binary to release
    ZIP_FILE="$OUTPUT_DIR/gnupg-bin-$GNUPG_VERSION-$GNUPG_TARGET_OS.zip"
    
    if [ ! -f "$ZIP_FILE" ]; then
        echo "Error: Binary zip file not found: $ZIP_FILE"
        echo "Run './scripts/build_gpg.sh build' first"
        exit 1
    fi
    
    echo "Are you sure you want to publish $(basename $ZIP_FILE) to experian artifactory? (y/n)"
    read -r response
    if [[ "$response" != "y" ]]; then
        echo "Aborting publish"
        exit 1
    fi

    # Publish the zip file
    echo "Publishing $(basename $ZIP_FILE) to experian artifactory batch-products-local repository..."
    curl -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" -T "$ZIP_FILE" \
        "https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/$(basename $ZIP_FILE)"
    
    if [ $? -eq 0 ]; then
        echo "Successfully published $(basename $ZIP_FILE)"
    else
        echo "Failed to publish $(basename $ZIP_FILE)"
        exit 1
    fi
}

# Fetch the gpg binary from artifactory
fetch() {
    if [[ -z "$ARTIFACTORY_USER" || -z "$ARTIFACTORY_PASSWORD" ]]; then
        echo "Unable to fetch from experian artifactory, ARTIFACTORY_USERNAME and ARTIFACTORY_PASSWORD env vars are not set"
        exit 1
    fi

    # Get script dir and project root
    SCRIPT_DIR=$(dirname "$0")
    PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
    TEMP_DIR="${PROJECT_ROOT}/temp"
    mkdir -p "${TEMP_DIR}/al2"
    
    # Define the binary to fetch
    ZIP_FILE="gnupg-bin-${GNUPG_VERSION}-${GNUPG_TARGET_OS}.zip"
    TEMP_ZIP="${TEMP_DIR}/${ZIP_FILE}"
    
    # Fetch binary directly to temp directory
    echo "Fetching $ZIP_FILE from artifactory to temp directory..."
    curl -f -u "$ARTIFACTORY_USER:$ARTIFACTORY_PASSWORD" \
        -o "${TEMP_ZIP}" \
        "https://artifacts.experian.local/artifactory/batch-products-local/pgpcrypto/gnupg-binary/${ZIP_FILE}"
    
    if [ $? -eq 0 ]; then
        echo "Successfully downloaded $ZIP_FILE to ${TEMP_DIR}"
        echo "Extracting binary to ${TEMP_DIR}/al2/..."
        unzip -o "${TEMP_ZIP}" -d "${TEMP_DIR}/al2"
        echo "Fetch complete! Binary extracted to ${TEMP_DIR}/al2/"
    else
        echo "Failed to download $ZIP_FILE"
        exit 1
    fi
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