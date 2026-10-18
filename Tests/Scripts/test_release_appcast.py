#!/usr/bin/env python3
import base64
import subprocess
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import ROOT, VERIFY_APPCAST_SCRIPT, make_release


class ReleaseAppcastTests(unittest.TestCase):
    def verify(self, artifact: Path, evidence: Path, appcast: Path, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            (
                "python3", str(VERIFY_APPCAST_SCRIPT),
                "--appcast", str(appcast),
                "--evidence", str(evidence),
                "--artifact", str(artifact),
                *extra,
            ),
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )

    def test_matching_appcast_and_evidence_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact, evidence, appcast = make_release(Path(temporary_directory))
            self.assertEqual(self.verify(artifact, evidence, appcast).returncode, 0)

    def test_appcast_rejects_wrong_version_size_signature_or_url(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact, evidence, appcast = make_release(Path(temporary_directory))
            original = appcast.read_text(encoding="utf-8")
            signature = base64.b64encode(bytes(range(64))).decode("ascii")
            for label, changed in (
                ("version", original.replace("<sparkle:version>1.2.3", "<sparkle:version>1.2.2")),
                ("size", original.replace(f'length="{artifact.stat().st_size}"', 'length="1"')),
                ("signature", original.replace(f'sparkle:edSignature="{signature}"', 'sparkle:edSignature=""')),
                ("url", original.replace("/download/v1.2.3/", "/download/v1.2.2/")),
            ):
                with self.subTest(label=label):
                    appcast.write_text(changed, encoding="utf-8")
                    self.assertNotEqual(self.verify(artifact, evidence, appcast).returncode, 0)

    def test_appcast_rejects_changed_artifact_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact, evidence, appcast = make_release(Path(temporary_directory))
            artifact.write_bytes(b"changed disk image fixture")
            self.assertNotEqual(self.verify(artifact, evidence, appcast).returncode, 0)

    def test_published_feed_must_match_staged_feed_byte_for_byte(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact, evidence, appcast = make_release(Path(temporary_directory))
            published = appcast.with_name("published-appcast.xml")
            published.write_bytes(appcast.read_bytes())
            self.assertEqual(
                self.verify(artifact, evidence, published, "--expected-appcast", str(appcast)).returncode,
                0,
            )
            published.write_bytes(appcast.read_bytes() + b"<!-- stale cache -->\n")
            self.assertNotEqual(
                self.verify(artifact, evidence, published, "--expected-appcast", str(appcast)).returncode,
                0,
            )


if __name__ == "__main__":
    unittest.main()
