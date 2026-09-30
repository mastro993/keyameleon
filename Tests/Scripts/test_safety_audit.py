import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class SafetyAuditTests(unittest.TestCase):
    def test_scan_errors_never_pass_the_audit(self):
        for failed_scan in range(5):
            with self.subTest(failed_scan=failed_scan), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / "Scripts").mkdir()
                shutil.copyfile(ROOT / "Scripts/run.sh", root / "Scripts/run.sh")
                for relative in (
                    "Sources/Features/Shared/KeyameleonLog.swift",
                    "Sources/Features/Shared/KeyameleonLogFile.swift",
                    "Sources/Features/Shared/KeyameleonLogWriter.swift",
                    "Sources/Features/Shared/KeyameleonLogLevel.swift",
                    "Sources/Features/Shared/KeyameleonLogCategory.swift",
                    "Sources/App/ApplicationDelegate.swift",
                    "Sources/Features/ActivityTriggeredSwitching/ActivityTriggeredSwitching.swift",
                    "Sources/Features/Shared/SetupModel.swift",
                    "Sources/Features/Shared/GeneralSettingsModel.swift",
                    "project.yml",
                ):
                    path = root / relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.touch()
                (root / "Tests").mkdir()
                binary = root / "bin"
                binary.mkdir()
                grep = binary / "grep"
                grep.write_text('''#!/bin/sh
count=$(cat "$SCAN_COUNT")
count=$((count + 1))
echo "$count" > "$SCAN_COUNT"
if [ "$count" -eq "$FAILED_SCAN" ]; then
    echo "injected scan failure" >&2
    exit 2
fi
exec /usr/bin/grep "$@"
''')
                grep.chmod(0o755)
                counter = root / "count"
                counter.write_text("0\n")
                result = subprocess.run(
                    ("zsh", str(root / "Scripts/run.sh"), "audit"),
                    env={**os.environ, "PATH": f"{binary}{os.pathsep}{os.environ['PATH']}",
                         "SCAN_COUNT": str(counter), "FAILED_SCAN": str(failed_scan)},
                    capture_output=True, text=True, check=False,
                )
                if failed_scan:
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertIn("injected scan failure", result.stderr)
                    self.assertEqual(int(counter.read_text()), failed_scan)
                else:
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(int(counter.read_text()), 4)


if __name__ == "__main__":
    unittest.main()
