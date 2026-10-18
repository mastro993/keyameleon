#!/usr/bin/env python3
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import ROOT, PUBLISH_ASSET_SCRIPT, make_release


class PublishReleaseAssetTests(unittest.TestCase):
    def test_retry_keeps_uploaded_asset_and_repairs_starter_asset(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            dist = directory / "dist"
            dist.mkdir()
            download = directory / "download"
            asset, _, _ = make_release(dist)
            notes = directory / "notes.md"
            notes.write_text("Release notes\n", encoding="utf-8")
            fake_bin = directory / "bin"
            fake_bin.mkdir()
            fake_gh = fake_bin / "gh"
            fake_gh.write_text(
                """#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$STUB_CALLS"
case "$1 $2" in
  'release view')
    [[ -f "$STUB_RELEASE" ]] || exit 1
    if [[ "$*" == *'--json assets'* ]]; then
      if [[ -f "$STUB_ASSET_STATE" ]]; then
        printf '{"assets":[{"name":"Keyameleon-1.2.3.dmg","state":"%s","apiUrl":"https://api.github.com/repos/mastro993/keyameleon/releases/assets/123"}]}\\n' "$(cat "$STUB_ASSET_STATE")"
      else
        printf '%s\\n' '{"assets":[]}'
      fi
    else
      printf '%s\\n' false
    fi
    ;;
  'release create') touch "$STUB_RELEASE"; printf uploaded > "$STUB_ASSET_STATE" ;;
  'release upload') printf uploaded > "$STUB_ASSET_STATE" ;;
  'api --method')
    [[ "$*" == *'/releases/assets/123' ]] || exit 2
    rm "$STUB_ASSET_STATE"
    ;;
  *) exit 2 ;;
esac
""",
                encoding="utf-8",
            )
            fake_gh.chmod(0o755)
            fake_curl = fake_bin / "curl"
            fake_curl.write_text(
                """#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >> "$STUB_CALLS"
[[ -f "$STUB_ASSET_STATE" && "$(cat "$STUB_ASSET_STATE")" == uploaded ]] || exit 22
if [[ ! -f "$STUB_CURL_FAILED" ]]; then
  touch "$STUB_CURL_FAILED"
  exit 22
fi
while [[ $# -gt 0 ]]; do
  if [[ "$1" == '-o' || "$1" == '--output' ]]; then
    cp "$STUB_ASSET_SOURCE" "$2"
    exit 0
  fi
  shift
done
exit 2
""",
                encoding="utf-8",
            )
            fake_curl.chmod(0o755)
            environment = os.environ.copy()
            environment.update(
                PATH=f"{fake_bin}{os.pathsep}{environment['PATH']}",
                STUB_CALLS=str(directory / "calls.txt"),
                STUB_RELEASE=str(directory / "release-exists"),
                STUB_ASSET_STATE=str(directory / "asset-state"),
                STUB_CURL_FAILED=str(directory / "curl-failed"),
                STUB_ASSET_SOURCE=str(asset),
            )
            command = (
                "bash", str(PUBLISH_ASSET_SCRIPT),
                "v1.2.3", "1.2.3", str(notes), str(dist), str(download),
            )

            failed = subprocess.run(command, cwd=ROOT, env=environment, text=True, capture_output=True)
            self.assertNotEqual(failed.returncode, 0)
            self.assertEqual(Path(environment["STUB_ASSET_STATE"]).read_text(), "uploaded")
            self.assertFalse((download / asset.name).exists())

            retried = subprocess.run(command, cwd=ROOT, env=environment, text=True, capture_output=True)
            self.assertEqual(retried.returncode, 0, retried.stderr)
            self.assertEqual((download / asset.name).read_bytes(), asset.read_bytes())
            Path(environment["STUB_ASSET_STATE"]).write_text("starter")
            repaired = subprocess.run(command, cwd=ROOT, env=environment, text=True, capture_output=True)
            self.assertEqual(repaired.returncode, 0, repaired.stderr)
            self.assertEqual(Path(environment["STUB_ASSET_STATE"]).read_text(), "uploaded")
            calls = Path(environment["STUB_CALLS"]).read_text(encoding="utf-8").splitlines()
            self.assertEqual(sum(call.startswith("release create ") for call in calls), 1)
            self.assertEqual(sum(call.startswith("release upload ") for call in calls), 1)
            self.assertEqual(sum(call.startswith("api --method DELETE ") for call in calls), 1)
            self.assertFalse(any("--clobber" in call for call in calls))


if __name__ == "__main__":
    unittest.main()
