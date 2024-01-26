#!/usr/bin/env bash

#
# Build the gnupg binary for Amazon Linux 2 from source. Check https://www.gnupg.org/ftp/gcrypt/gnupg/ for latest versions of gnupg.
#
# Run ./scripts/s3_gpg_cache.sh for usage info
#

# Print usage info
print_help() {
    echo ""
    echo "Push or pull gpg binary from s3 bucket. See https://www.gnupg.org/ftp/gcrypt/gnupg/ for versions of gnupg."
    echo ""
    echo "Configure with environment variables:"
    echo "  export GNUPG_S3_LOCATION=\"s3://yourbucket/yourprefix\"                         S3 location for the gpg binary"
    echo "  export GNUPG_S3_KMS_KEY=\"arn:aws:kms:us-east-1:123456789012:key/123456...\"    KMS key used to encrypt the s3 objects (optional, will encrypt on push if provided)"
    echo ""
    echo "Commands:"
    echo "  ./scripts/s3_gpg_cache.sh pull          Download the gpg binary from s3 location"
    echo "  ./scripts/s3_gpg_cache.sh push          Upload the gpg binary from s3 location"
    echo ""
}

pull() {

    if [[ -z "${GNUPG_S3_LOCATION}" ]]; then
        echo -e "\nMissing environment var: GNUPG_S3_LOCATION, skipping pull of 'gpg' binary from s3."
        print_help
        exit 1
    fi

    aws s3 cp $GNUPG_S3_LOCATION/gpg .

}

push() {

    # If we have a s3 location, push the gpg binary to s3
    if [[ -n "${GNUPG_S3_LOCATION}" ]]; then
        echo "Pushing gpg binary to s3: $GNUPG_S3_LOCATION/gpg..."
        if [ -n "$GNUPG_S3_KMS_KEY" ]; then
            aws s3 cp ./gpg $GNUPG_S3_LOCATION/gpg --sse aws:kms --sse-kms-key-id $GNUPG_S3_KMS_KEY
        else
            aws s3 cp ./gpg $GNUPG_S3_LOCATION/gpg
        fi
    else
        echo -e "\nMissing environment var: GNUPG_S3_LOCATION, skipping push of 'gpg' binary to s3."
    fi

    exit $?

}

# Run the commands
if [[ "$1" == "push" ]]; then
    push
elif [[ "$1" == "pull" ]]; then
    pull
else
    print_help
    exit 1
fi