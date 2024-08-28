import gnupg
from typing import Any, List
import os


class PgpWrapper:
    """
    A wrapper class for performing PGP encryption and decryption operations.
    """

    def __init__(
        self,
        gnupghome: str,  # required, should be a temporary directory
        gpgbinary: str = "/opt/python/gpg",
    ) -> None:
        """
        Initialize the PGP wrapper gnupghome directory and path to gpg binary.
        """

        # Create the gnupghome directory if it doesn't exist
        if not os.path.exists(gnupghome):
            os.makedirs(gnupghome)
            os.chmod(gnupghome, 0o700)

        # Initialize the GPG object
        self.gpg = gnupg.GPG(gpgbinary=gpgbinary, gnupghome=gnupghome)

        # Dictionary of key pairs, key is key_id
        self._key_id_by_recipient = {}
        self._passphrase_by_key_id = {}

        # The key id to be used for encryption when recipient not specified
        self.default_recipient: str = ""

    def import_public_key(
        self, public_key: str, recipient: str = None, default: bool = False
    ) -> list[str]:
        assert public_key
        res = self.gpg.import_keys(public_key)
        result = res.results[0]
        if "ok" not in result:
            raise ImportError(f"Unable to import public PGP key: {res.stderr}")
        fingerprint = result["fingerprint"]
        if not recipient:
            recipient = fingerprint
        self.gpg.trust_keys(fingerprint, "TRUST_ULTIMATE")
        if default or not self.default_recipient:
            self.default_recipient = recipient
        return self._get_all_keyids(fingerprint)

    def _get_all_keyids(self, fingerprint: str) -> str:
        keyids = [fingerprint, fingerprint[-16:], fingerprint[-8:]]
        return keyids + self._get_all_subkeys(keyids)

    def _get_all_subkeys(self, keyids: list[str]) -> list[str]:
        key_list = self.get_keys()
        subkey_set = set()
        for k in key_list:
            if k["keyid"] in keyids and "subkeys" in k:
                for sk in k["subkeys"]:
                    for v in sk:
                        if isinstance(v, str) and len(v) >= 8:
                            subkey_set.add(v)
                            subkey_set.add(v[-8:])
        return list(subkey_set)

    def import_secret_key(self, secret_key: str, passphrase: str) -> list[str]:
        res = self.gpg.import_keys(secret_key)
        result = res.results[0]
        if "ok" not in result:
            raise ImportError(f"Unable to import secret PGP key: {res.stderr}")
        fingerprint = result["fingerprint"]
        keyid = fingerprint[-16:]
        self.gpg.trust_keys(fingerprint, "TRUST_ULTIMATE")
        keyids = self._get_all_keyids(fingerprint)
        for k in keyids:
            self._passphrase_by_key_id[k] = passphrase
        return keyids

    def get_keys(self) -> List[Any]:
        return self.gpg.list_keys(secret=False) + self.gpg.list_keys(secret=True)

    def count_keys(self) -> int:
        return len(self.get_keys())

    def encrypt_file(
        self, file_path: str, output_file_path: str, recipient: str = ""
    ) -> Any:
        result = self.gpg.encrypt_file(
            file_path,
            recipient or self.default_recipient,
            armor=True,
            output=output_file_path,
        )
        if not result.ok:
            raise ValueError(f"Unable to encrypt file: {result.stderr}")
        return result

    def decrypt_file(self, file_path: str, output_file_path: str) -> None:
        keyids = self.gpg.get_recipients_file(file_path)
        if (
            not keyids
            or not keyids[0]
            or not isinstance(keyids[0], str)
            or not len(keyids[0]) >= 8
        ):
            raise ValueError(
                f"Unable to decrypt file {file_path}, no recipient keyid found"
            )
        passphrase = self._passphrase_by_key_id.get(keyids[0], "")
        if not passphrase:
            raise ValueError(
                f"Unable to decrypt file {file_path}, no passphrase for keyid {keyids}"
            )
        result = self.gpg.decrypt_file(
            file_path,
            always_trust=True,
            passphrase=passphrase,
            output=output_file_path,
        )
        if not result.ok:
            raise ValueError(f"Unable to decrypt file: {result.stderr}")
