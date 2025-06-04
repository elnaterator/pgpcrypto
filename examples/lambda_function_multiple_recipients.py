import boto3
import os
from tempfile import TemporaryDirectory
from pgpcrypto.pgp import PgpWrapper

def get_secret(secret_name, region_name="us-east-1"):
    """Retrieve a plain text secret from AWS Secrets Manager"""
    client = boto3.client(service_name="secretsmanager", region_name=region_name)
    try:
        response = client.get_secret_value(SecretId=secret_name)
        return response.get("SecretString")
    except Exception as e:
        print(f"Error retrieving secret {secret_name}: {str(e)}")
        return None

def lambda_handler(event, context):
    # Get input parameters
    input_file = event.get("file_path", "data/test.txt")
    recipients = event.get("recipients", ["clientA", "clientB", "clientC"])
    
    # Create a temporary directory for working files
    with TemporaryDirectory(dir="/tmp") as tmpdir:
        # Initialize the PGP wrapper
        pgpw = PgpWrapper(
            gnupghome=f"{tmpdir}/.gnupghome",
            gpgbinary="/opt/python/gpg"
        )
        
        # Import public keys for all recipients
        for recipient in recipients:
            # Get public key from Secrets Manager
            pubkey = get_secret(f"pgpcrypto/{recipient}/public_key")
            if not pubkey:
                print(f"Warning: Public key for {recipient} not found")
                continue
                
            # Import the public key
            pgpw.import_public_key(
                public_key=pubkey,
                recipient=recipient
            )
            print(f"Imported key for {recipient}")
        
        # Encrypt the file for each recipient
        encrypted_files = {}
        for recipient in recipients:
            output_file = f"{tmpdir}/{recipient}_encrypted.pgp"
            
            # Encrypt specifically for this recipient
            pgpw.encrypt_file(
                input_file,
                output_file,
                recipient=recipient  # Specify recipient to use their key
            )
            
            # Read the encrypted content
            with open(output_file, "rb") as f:
                encrypted_size = len(f.read())
            
            # Store the encrypted file (in a real scenario, you might upload to S3)
            encrypted_files[recipient] = {
                "file_path": output_file,
                "size": encrypted_size
            }
        
        return {
            "status": "SUCCESS",
            "encrypted_files": encrypted_files,
            "total_keys": pgpw.count_keys()
        }
