from tempfile import TemporaryDirectory
from pgpcrypto.pgp import PgpWrapper


def lambda_handler(event, context):
    # Get the PGP input data
    recipient = "Test User"
    passphrase = "Passphrase12345"
    with open("data/test.pub.asc", "r") as f:
        pubkey = f.read()
    with open("data/test.sec.asc", "r") as f:
        seckey = f.read()

    # Get input file path
    file_path = "data/test.txt"

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

        # Should get the key ids used to encrypt the message
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
