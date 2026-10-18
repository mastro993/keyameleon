#!/usr/bin/env python3
import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import ROOT, EVIDENCE_SCRIPT, run


class ReleaseEvidenceTests(unittest.TestCase):
    def test_evidence_binds_the_dmg_and_pages_feed(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            disk_image = directory / "Keyameleon-1.2.3.dmg"
            evidence_path = directory / "release-evidence.json"
            disk_image.write_bytes(b"disk image fixture")

            run(
                str(EVIDENCE_SCRIPT),
                "--tag",
                "v1.2.3",
                "--commit",
                "abc123",
                "--artifact",
                str(disk_image),
                "--output",
                str(evidence_path),
                cwd=ROOT,
            )

            evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
            self.assertEqual(evidence["product"], "Keyameleon")
            self.assertEqual(evidence["licenseSPDXIdentifier"], "MIT")
            self.assertEqual(evidence["tag"], "v1.2.3")
            self.assertEqual(evidence["semanticVersion"], "1.2.3")
            self.assertEqual(evidence["gitCommit"], "abc123")
            self.assertEqual(evidence["artifactFileName"], "Keyameleon-1.2.3.dmg")
            self.assertEqual(evidence["artifactSHA256"], hashlib.sha256(disk_image.read_bytes()).hexdigest())
            self.assertEqual(evidence["appcastFileName"], "appcast.xml")
            self.assertEqual(
                evidence["feedURLString"],
                "https://mastro993.github.io/keyameleon/appcast.xml",
            )
            self.assertNotIn("sourceArchiveFileName", evidence)

    def test_invalid_release_inputs_do_not_write_evidence(self) -> None:
        for tag, commit, filename, error in (
            ("1.2.3", "abc123", "Keyameleon-1.2.3.dmg", "not an Official Release tag"),
            ("v1.2.3", "", "Keyameleon-1.2.3.dmg", "usage: write-release-evidence.sh"),
            ("v1.2.3", "abc123", "Keyameleon-1.2.4.dmg", "artifact must be named"),
        ):
            with self.subTest(tag=tag, commit=commit, filename=filename), \
                    tempfile.TemporaryDirectory() as temporary_directory:
                directory = Path(temporary_directory)
                artifact = directory / filename
                artifact.write_bytes(b"disk image fixture")
                evidence = directory / "release-evidence.json"
                result = subprocess.run(
                    (str(EVIDENCE_SCRIPT), "--tag", tag, "--commit", commit,
                     "--artifact", str(artifact), "--output", str(evidence)),
                    cwd=ROOT,
                    check=False,
                    text=True,
                    capture_output=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(error, result.stderr)
                self.assertFalse(evidence.exists())


if __name__ == "__main__":
    unittest.main()
