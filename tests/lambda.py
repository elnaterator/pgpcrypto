import json
import os
import pgpcrypto.pgp as pgp

def lambda_handler(event, context):
    
    # Get the PGP input data
    key_id = "Test User"
    passphrase = "Passphrase12345"
    with open("data/test.pub.asc", "r") as f:
        public_key = f.read()
    with open("data/test.sec.asc", "r") as f:
        secret_key = f.read()
        
    # Initialize the PGP wrapper
    pgpw = pgp.PgpWrapper(key_id, passphrase, public_key, secret_key)
    
    # Encrypt the file
    pgpw.encrypt_file("data/test.txt", "data/test.txt.pgp")
    
    # Verify the encrypted file
    with open("data/test.txt.pgp", "r") as f:
        enc_content = f.read()
    assert enc_content.startswith("-----BEGIN PGP MESSAGE-----")
    
    # Decrypt the file
    pgpw.decrypt_file("data/test.txt.pgp", "data/test.txt.dec")
    
    # Verify the decrypted file
    with open("data/test.txt.dec", "r") as f:
        dec_content = f.read()
    assert dec_content == "Hello World!"
    
    return {
        'result': "SUCCESS",
        'count_keys': pgpw.count_keys(),
        'get_keys': pgpw.get_keys(),
        'enc_content': enc_content,
        'dec_content': dec_content,
    }
