#!/usr/bin/env python3
import subprocess
import unittest

from release_tooling_support import ROOT, VERIFY_TAG_SCRIPT


class OfficialReleaseTagTests(unittest.TestCase):
    def test_tags_require_strict_semantic_versioning_cores(self) -> None:
        for tag, version in (
            ("v0.1.0", "0.1.0"), ("v1.2.3", "1.2.3"), ("v10.20.30", "10.20.30"),
            ("1.2.3", None), ("v1.2", None), ("v1.2.3-beta.1", None),
            ("v1.2.3+build.1", None), ("release-1.2.3", None),
            ("v01.2.3", None), ("v1.02.3", None), ("v1.2.03", None), ("", None),
        ):
            with self.subTest(tag=tag):
                result = subprocess.run(
                    (str(VERIFY_TAG_SCRIPT), tag),
                    cwd=ROOT,
                    check=False,
                    text=True,
                    capture_output=True,
                )
                if version is not None:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, f"{version}\n")
                else:
                    self.assertEqual(result.returncode, 1 if tag else 64)
                    self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
