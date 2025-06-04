import json
import boto3
from tempfile import TemporaryDirectory
from pgpcrypto.pgp import PgpWrapper


def get_secret(secret_name, region_name="us-east-1"):
    """Retrieve a plain text secret from AWS Secrets Manager"""
    client = boto3.client(service_name="secretsmanager", region_name=region_name)
    
    try:
        response = client.get_secret_value(SecretId=secret_name)
        if "SecretString" in response:
            return response["SecretString"]
        else:
            # Binary secrets are returned as base64-encoded data
            return response["SecretBinary"]
    except Exception as e:
        # Handle exceptions (in production, you'd want more specific error handling)
        print(f"Error retrieving secret {secret_name}: {str(e)}")
        return None


def lambda_handler(event, context):
    """Lambda function handler to encrypt and decrypt files using PGP."""
    
    # Extract PGP data from secrets
    recipient = get_secret("pgpcrypto/recipient") or "Test User"
    passphrase = get_secret("pgpcrypto/passphrase")
    pubkey = get_secret("pgpcrypto/public_key")
    seckey = get_secret("pgpcrypto/private_key")
    
    # Fallback to local files if secrets not available (for testing)
    if not pubkey or not seckey or not passphrase:
        print("Warning: Using local test files instead of secrets")
        passphrase = "Passphrase12345"
        with open("data/test.pub.asc", "r") as f:
            pubkey = f.read()
        with open("data/test.sec.asc", "r") as f:
            seckey = f.read()

    # Get input file path
    file_path = event.get("file_path", "data/test.txt")

    # response object
    response = {}

    # Should use a temporary directory
    with TemporaryDirectory(dir="/tmp") as tmpdir:
        # Initialize the pgp wrapper
        pgpw = PgpWrapper(
            gnupghome=f"{tmpdir}/.gnupghome",  # GnuPG stores keys here
            gpgbinary="/opt/python/gpg",  # default value (shown) works for lambda layer
        )

        # Import a public key for encryption
        pubkey_ids = pgpw.import_public_key(
            public_key=pubkey,
            recipient=recipient,  # Name, email, keyid, or fingerprint
            default=True,  # Optional, first key imported is default by default
        )

        # Encrypt files (use the default key)
        pgpw.encrypt_file(file_path, f"{tmpdir}/encrypted_file.pgp")

        # Verify the encrypted file
        with open(f"{tmpdir}/encrypted_file.pgp", "r") as f:
            enc_content = f.read()
        assert enc_content.startswith("-----BEGIN PGP MESSAGE-----")

        # Import a secret key for decryption
        seckey_ids = pgpw.import_secret_key(
            secret_key=seckey,
            passphrase=passphrase,
        )

        # Decrypt files
        pgpw.decrypt_file(
            f"{tmpdir}/encrypted_file.pgp", f"{tmpdir}/decrypted_file.txt"
        )

        # Verify the decrypted file
        with open(f"{tmpdir}/decrypted_file.txt", "r") as f:
            dec_content = f.read()
        assert dec_content == "Hello World!"

        # Access the underlying gpg interface from python-gnupg library for low level operations
        message_keys = pgpw.gpg.get_recipients(enc_content)
        assert message_keys == ["75188ED1"]

        response = {
            "result": "SUCCESS",
            "pubkey_ids": pubkey_ids,
            "seckey_ids": seckey_ids,
            "encrypted_content": enc_content,
            "decrypted_content": dec_content,
            "message_keys": message_keys,
            "count_keys": pgpw.count_keys(),
            "get_keys": pgpw.get_keys(),
        }

    return response
