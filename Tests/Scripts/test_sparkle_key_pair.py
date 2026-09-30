import base64
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SEED = bytes(range(32))
PUBLIC_KEY = bytes.fromhex("03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8")


class SparkleKeyPairTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.verifier = cls.root / "verify-keys"
        subprocess.run(
            ("xcrun", "swiftc", str(ROOT / "Scripts/verify-sparkle-ed-keys.swift"),
             "-o", str(cls.verifier)),
            capture_output=True, text=True, check=True,
        )

    def test_checks_modern_and_legacy_pairs_without_disclosing_keys(self):
        expanded = bytearray(hashlib.sha512(SEED).digest())
        expanded[0] &= 248
        expanded[31] &= 63
        expanded[31] |= 64
        legacy = bytes(expanded) + PUBLIC_KEY
        cases = (
            ("seed", SEED, PUBLIC_KEY, True),
            ("legacy", legacy, PUBLIC_KEY, True),
            ("seed mismatch", SEED, bytes(32), False),
            ("legacy mismatch", legacy, bytes(32), False),
            ("expanded private key", bytes(expanded), PUBLIC_KEY, False),
            ("oversized public key", SEED, PUBLIC_KEY * 2, False),
            ("truncated public key", SEED, PUBLIC_KEY[:-1], False),
        )
        for name, private_key, public_key, accepted in cases:
            with self.subTest(case=name):
                private_text = base64.b64encode(private_key).decode()
                public_text = base64.b64encode(public_key).decode()
                private_path = self.root / "private"
                public_path = self.root / "public"
                private_path.write_text(private_text)
                public_path.write_text(public_text)
                result = subprocess.run(
                    (str(self.verifier), str(private_path), str(public_path)),
                    capture_output=True, text=True, check=False,
                )
                self.assertEqual(result.returncode, 0 if accepted else 1, result.stderr)
                self.assertEqual(result.stdout, "")
                self.assertNotIn(private_text, result.stderr)
                self.assertNotIn(public_text, result.stderr)


if __name__ == "__main__":
    unittest.main()
