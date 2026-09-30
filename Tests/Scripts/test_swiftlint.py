import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class SwiftLintPolicyTests(unittest.TestCase):
    def test_lint_rejects_warnings_correctness_findings_and_version_drift(self):
        configuration = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        clean_source = "struct ValidName { let value = 1 }\n"
        cases = (
            (clean_source, configuration, None),
            (clean_source + " \n", configuration, "trailing_whitespace"),
            ('let value = "text" as! Int\n', configuration, "force_cast"),
            (clean_source, configuration.replace('"0.65.1"', '"0.0.0"'),
             "configuration specified version 0.0.0"),
        )
        script = r'''
source <(sed -n '/^lint_sources()/,/^}/p' "$1")
cd "$2"
lint_sources
'''
        for source, config, finding in cases:
            with self.subTest(finding=finding), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "Sources").mkdir()
                (root / "Sources/Example.swift").write_text(source, encoding="utf-8")
                (root / ".swiftlint.yml").write_text(config, encoding="utf-8")
                result = subprocess.run(
                    ("zsh", "-c", script, "test", str(ROOT / "Scripts/run.sh"), directory),
                    capture_output=True,
                    text=True,
                    check=False,
                )
                output = result.stdout + result.stderr
                if finding is None:
                    self.assertEqual(result.returncode, 0, output)
                    self.assertEqual(output, "")
                else:
                    self.assertNotEqual(result.returncode, 0, output)
                    self.assertIn(finding, output)


if __name__ == "__main__":
    unittest.main()
