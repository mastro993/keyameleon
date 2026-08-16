#!/usr/bin/env python3
import base64
import importlib.util
import io
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts" / "normalize-sparkle-ed-key.py"

_spec = importlib.util.spec_from_file_location("normalize_sparkle_ed_key", SCRIPT)
assert _spec is not None and _spec.loader is not None
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
normalize = _mod.normalize
main = _mod.main

SEED = base64.b64encode(b"\x11" * 32).decode("ascii")


class NormalizeSparkleEdKeyTests(unittest.TestCase):
    def test_plain_seed(self) -> None:
        self.assertEqual(normalize(SEED), SEED)

    def test_strips_whitespace_and_quotes(self) -> None:
        self.assertEqual(normalize(f' \n"{SEED}"\r\n'), SEED)
        self.assertEqual(normalize(f"'{SEED}'"), SEED)

    def test_unwraps_pem(self) -> None:
        pem = f"-----BEGIN PRIVATE KEY-----\n{SEED}\n-----END PRIVATE KEY-----\n"
        self.assertEqual(normalize(pem), SEED)

    def test_rejects_empty(self) -> None:
        with self.assertRaises(ValueError):
            normalize("   ")

    def test_rejects_wrong_length(self) -> None:
        short = base64.b64encode(b"\x11" * 16).decode("ascii")
        with self.assertRaises(ValueError):
            normalize(short)

    def test_writes_dest_and_exits_on_bad_input(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            dest = Path(tmp) / "key"
            err = io.StringIO()
            with patch("sys.stdin", io.StringIO(SEED + "\n")), redirect_stderr(err):
                code = main([str(dest)])
            self.assertEqual(code, 0)
            self.assertEqual(dest.read_text(encoding="ascii"), SEED)

            err = io.StringIO()
            with patch("sys.stdin", io.StringIO("not-a-key")), redirect_stderr(err):
                code = main([str(dest)])
            self.assertEqual(code, 1)
            self.assertIn("not base64", err.getvalue())


if __name__ == "__main__":
    unittest.main()
