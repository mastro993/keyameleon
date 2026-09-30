import base64
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ReleaseCleanupTests(unittest.TestCase):
    def test_failure_releases_keychain_and_restores_source_plist(self):
        for failure in ("import", "set-key-partition-list", "plist-version", "archive", "key-mismatch"):
            with self.subTest(failure=failure), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                scripts = root / "Scripts"
                scripts.mkdir()
                binary = root / "bin"
                binary.mkdir()
                for name in ("normalize-sparkle-ed-key.py", "verify-official-release-tag.sh"):
                    shutil.copy2(ROOT / "Scripts" / name, scripts / name)
                verifier = ROOT / "Scripts/verify-sparkle-ed-keys.swift"
                if verifier.exists():
                    shutil.copy2(verifier, scripts / verifier.name)
                plist = root / "Sources/App/Info.plist"
                plist.parent.mkdir(parents=True)
                original = plistlib.dumps({"CFBundleShortVersionString": "1.0.0", "CFBundleVersion": "1"})
                plist.write_bytes(original)
                producer = scripts / "official-release.sh"
                producer.write_text((ROOT / "Scripts/official-release.sh").read_text().replace(
                    "/usr/libexec/PlistBuddy", str(binary / "plist-buddy"),
                ))
                commands = {
                    "security": '''#!/bin/sh
if [ "$1" = "$FAILURE" ]; then
    echo "injected $FAILURE failure" >&2
    exit 73
fi
case "$1" in
    create-keychain) touch "$FAKE_KEYCHAIN" "$FAKE_KEYCHAIN_CREATED" ;;
    delete-keychain) rm "$FAKE_KEYCHAIN" ;;
esac
''',
                    "git": "#!/bin/sh\nprintf '%040d\\n' 1\n",
                    "xcodegen": "#!/bin/sh\nexit 0\n",
                    "xcodebuild": "#!/bin/sh\necho 'injected archive failure' >&2\nexit 73\n",
                    "plist-buddy": '''#!/usr/bin/env python3
import os
from pathlib import Path
import plistlib
import sys

operation, key, *value = sys.argv[2].split()
key = key.removeprefix(":")
path = Path(sys.argv[3])
if os.environ["FAILURE"] == "plist-version" and key == "CFBundleVersion":
    sys.stderr.write("injected plist-version failure\\n")
    sys.exit(73)
data = plistlib.loads(path.read_bytes())
if operation == "Print":
    if key not in data:
        sys.exit(1)
    sys.stdout.write(str(data[key]))
else:
    data[key] = value[-1]
    path.write_bytes(plistlib.dumps(data))
''',
                }
                for name, text in commands.items():
                    path = binary / name
                    path.write_text(text)
                    path.chmod(0o755)
                keychain = root / "keychain"
                environment = {
                    **os.environ,
                    "PATH": f"{binary}{os.pathsep}{os.environ['PATH']}",
                    "FAILURE": failure,
                    "FAKE_KEYCHAIN": str(keychain),
                    "FAKE_KEYCHAIN_CREATED": str(root / "keychain-created"),
                    "RELEASE_TAG": "v1.2.3",
                    "SKIP_NOTARIZE": "1",
                    "APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_P12_BASE64": "dGVzdA==",
                    "APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD": "fixture",
                    "SPARKLE_PRIVATE_ED_KEY": base64.b64encode(bytes(range(32))).decode(),
                    "SPARKLE_PUBLIC_ED_KEY": base64.b64encode(
                        bytes(32) if failure == "key-mismatch" else bytes.fromhex(
                            "03a107bff3ce10be1d70dd18e74bc09967e4d6309ba50d5f1ddc8664125531b8"
                        )
                    ).decode(),
                }
                result = subprocess.run(
                    ("zsh", str(producer)), env=environment,
                    capture_output=True, text=True, check=False,
                )
                if failure == "key-mismatch":
                    self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                    self.assertIn("public key does not match", result.stderr)
                    self.assertFalse((root / "keychain-created").exists())
                else:
                    self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
                    self.assertIn(f"injected {failure} failure", result.stderr)
                self.assertFalse(keychain.exists(), "temporary signing keychain leaked")
                self.assertEqual(plist.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
