import gnupg
from typing import Any, List
import os


class PgpWrapper:
    """
    A wrapper class for performing PGP encryption and decryption operations.
    """

    def __init__(
        self,
        key_id: str = None,
        passphrase: str = None,
        public_key: str = None,
        secret_key: str = None,
        gnupghome: str = "/tmp/.gnupghome",
        gpgbinary: str = "/opt/python/gpg",
    ) -> None:
        """
        Initializes a PGP object.

        Args:
            key_id (str): The key ID associated with the PGP key.
            passphrase (str): The passphrase to unlock the PGP key.
            public_key (str): The ASCII armored public key.
            secret_key (str): The ASCII armored secret key.
            gnupghome (str, optional): The path to the GnuPG home directory. Defaults to "/tmp/.gnupghome".
        """

        if not os.path.exists(gnupghome):
            os.makedirs(gnupghome)
            os.chmod(gnupghome, 0o700)
        self.gpg = gnupg.GPG(gpgbinary=gpgbinary, gnupghome=gnupghome)

        # import the keys
        self.key_id = key_id
        self.passphrase = passphrase
        if secret_key:
            res = self.import_keys(secret_key)
        if public_key:
            res = self.import_keys(public_key)
            self.gpg.trust_keys(res["key_id"], "TRUST_ULTIMATE")

    def get_keys(
        self,
    ) -> List[Any]:
        """
        Retrieves a list of PGP keys.

        Returns:
            List[Any]: A list of PGP keys.
        """
        return self.gpg.list_keys(secret=False) + self.gpg.list_keys(secret=True)

    def count_keys(self) -> int:
        """
        Counts the number of PGP keys.

        Returns:
            int: The number of PGP keys.
        """
        return len(self.get_keys())

    def import_key_file(self, ascii_key_file_path: str) -> Any:
        """
        Imports a PGP key from an ASCII armored key file.

        Args:
            ascii_key_file_path (str): The path to the ASCII armored key file.

        Returns:
            Any: The result of the key import operation.
        """
        with open(ascii_key_file_path, "r") as f:
            content = f.read()
        return self.import_keys(content)

    def import_keys(self, ascii_key_data: str) -> dict:
        """
        Imports PGP keys from ASCII armored key data.

        Args:
            ascii_key_data (str): The ASCII armored key data.

        Returns:
            dict: The result of the key import operation.
        """
        res = self.gpg.import_keys(ascii_key_data)
        if res.returncode != 0:
            raise ImportError(f"Unable to import PGP key(s): {res.stderr}")
        return {
            "key_id": res.fingerprints[0],
            "keys_found": res.count,
            "pub_keys_imported": res.imported,
            "sec_keys_imported": res.sec_imported,
        }

    def encrypt_file(self, file_path: str, output_file_path: str = None) -> None:
        """
        Encrypts a file using PGP.

        Args:
            file_path (str): The path to the file to encrypt.
            output_file_path (str, optional): The path to save the encrypted file. Defaults to None.
        """
        result = self.gpg.encrypt_file(
            file_path,
            self.key_id,
            armor=True,
            output=output_file_path,
        )
        if not result.ok:
            raise ValueError(f"Unable to encrypt file: {result.stderr}")

    def decrypt_file(self, file_path: str, output_file_path: str = None) -> None:
        """
        Decrypts a file using PGP.

        Args:
            file_path (str): The path to the file to decrypt.
            output_file_path (str, optional): The path to save the decrypted file. Defaults to None.
        """
        result = self.gpg.decrypt_file(
            file_path,
            always_trust=True,
            passphrase=self.passphrase,
            output=output_file_path,
        )
        if not result.ok:
            raise ValueError(f"Unable to decrypt file: {result.stderr}")
