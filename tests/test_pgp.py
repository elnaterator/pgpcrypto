import unittest
from pgpcrypto import pgp
import shutil
import os
from datetime import datetime
import json
from unittest.mock import patch


class TestGpgWrapper(unittest.TestCase):
    def setUp(self) -> None:
        self.gnupghome = "./.gnupghome"
        self.tmpdatadir = "./data/tmp"
        if not os.path.isdir(self.tmpdatadir):
            os.makedirs(self.tmpdatadir)
        return super().setUp()

    def tearDown(self) -> None:
        shutil.rmtree(self.gnupghome)
        shutil.rmtree(self.tmpdatadir)
        return super().tearDown()

    def test_import_key_file(self):
        s = get_pgp_secrets()
        pgpw = pgp.PgpWrapper(
            s["key_id"],
            s["passphrase"],
            s["public_key"],
            s["secret_key"],
            gnupghome=self.gnupghome,
            gpgbinary="gpg",
        )
        cnt_before = pgpw.count_keys()
        assert cnt_before == 2

        # import public key
        pub_res = pgpw.import_key_file("./data/test.pub.asc")
        assert pub_res["keys_found"] == 1
        assert pub_res["pub_keys_imported"] == 0
        assert pub_res["sec_keys_imported"] == 0

        # import secret key
        sec_res = pgpw.import_key_file("./data/test.sec.asc")
        assert sec_res["keys_found"] == 1
        assert sec_res["pub_keys_imported"] == 0
        assert sec_res["sec_keys_imported"] == 0

        # should have 2 keys, 1 pub, 1 sec
        print_keys(pgpw)
        cnt_after = pgpw.count_keys()
        assert cnt_after == 2

    def test_encrypt_decrypt_file(self):
        s = get_pgp_secrets()
        pgpw = pgp.PgpWrapper(
            s["key_id"],
            s["passphrase"],
            s["public_key"],
            s["secret_key"],
            gnupghome=self.gnupghome,
            gpgbinary="gpg",
        )

        # set path to test files
        orig_path = os.path.join("data", "test.txt")
        enc_path = os.path.join(self.tmpdatadir, "test.txt.asc")
        dec_path = os.path.join(self.tmpdatadir, "test.dec.txt")

        # encrypt string
        pgpw.encrypt_file(orig_path, enc_path)

        # ensure encrypted file exists and starts and ends with the right strings
        assert os.path.isfile(enc_path)
        with open(enc_path, "r") as f:
            content = f.read()
        assert content.startswith("-----BEGIN PGP MESSAGE-----")
        assert content.endswith("-----END PGP MESSAGE-----\n")

        # decrypt string
        pgpw.decrypt_file(enc_path, dec_path)

        # ensure file exists and final message in file was preserved
        assert os.path.isfile(dec_path)
        with open(dec_path, "r") as f:
            content = f.read()
        assert content == "Hello World!"

    def test_encrypt_failure_bad_key_id(self):
        s = get_pgp_secrets()
        pgpw = pgp.PgpWrapper(
            "bad_key_id",
            s["passphrase"],
            s["public_key"],
            s["secret_key"],
            gnupghome=self.gnupghome,
            gpgbinary="gpg",
        )

        # set path to test files
        orig_path = os.path.join("data", "test.txt")
        enc_path = os.path.join(self.tmpdatadir, "test.txt.asc")

        # encrypt string and ensure it fails
        with self.assertRaises(ValueError) as cm:
            pgpw.encrypt_file(orig_path, enc_path)

        # ensure error message is correct
        assert "bad_key_id" in str(cm.exception)

    def test_decrypt_failure_bad_passphrase(self):
        s = get_pgp_secrets()
        pgpw = pgp.PgpWrapper(
            s["key_id"],
            "bad_passphrase",
            s["public_key"],
            s["secret_key"],
            gnupghome=self.gnupghome,
            gpgbinary="gpg",
        )

        # set path to test files
        orig_path = os.path.join("data", "test.txt")
        enc_path = os.path.join(self.tmpdatadir, "test.txt.asc")

        # encrypt string
        pgpw.encrypt_file(orig_path, enc_path)

        # decrypt string and ensure it fails
        with self.assertRaises(ValueError) as cm:
            pgpw.decrypt_file(enc_path)

        # ensure error message is correct
        assert "Unable to decrypt file" in str(cm.exception)


def print_keys(pgpw: pgp.PgpWrapper) -> None:
    keys = pgpw.get_keys()
    string = ""
    for k in keys:
        date = datetime.utcfromtimestamp(int(k["date"])).strftime("%Y-%m-%d %H:%M:%S")
        string += f"\n{k['type']}\t{str(k['uids'])}\t{date}\t{k['fingerprint']}\t{json.dumps(k)}\n"
    print(string)


def get_pgp_secrets():
    with open("./data/test.pub.asc", "r") as f:
        pgp_public_key = f.read()
    with open("./data/test.sec.asc", "r") as f:
        pgp_secret_key = f.read()
    return {
        "key_id": "Test User",
        "passphrase": "Passphrase12345",
        "public_key": pgp_public_key,
        "secret_key": pgp_secret_key,
    }
