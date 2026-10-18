#!/usr/bin/env python3
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import ROOT, workflow_step

WAIT_FOR_BUMP_SCRIPT = ROOT / "Scripts" / "wait-for-release-bump.sh"
WAIT_FOR_ARTIFACTS_SCRIPT = ROOT / "Scripts" / "wait-for-release-artifacts.sh"
RESTORE_ARTIFACTS_SCRIPT = ROOT / "Scripts" / "restore-release-artifacts.sh"


class ReleaseCheckpointTests(unittest.TestCase):
    def test_version_checkpoint_waits_and_rejects_unexpected_main(self) -> None:
        self.assertIn("run: bash Scripts/wait-for-release-bump.sh", workflow_step("Wait for validated version commit"))
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            fake_bin = directory / "bin"
            fake_bin.mkdir()
            git = fake_bin / "git"
            git.write_text(r'''#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  fetch)
    test "$CASE" != "api_error"
    count=0; if [[ -f count ]]; then count="$(cat count)"; fi
    echo "$((count+1))" > count ;;
  rev-parse)
    if [[ "$CASE" == "timeout" || ( "$CASE" == "delayed" && "$(cat count)" == 1 ) ]]; then
      printf 'source'
    else printf 'bump'; fi ;;
  log)
    if [[ "$3" == "--format=%P" ]]; then
      if [[ "$CASE" == "wrong_parent" ]]; then printf 'other'; else printf 'source'; fi
    else
      if [[ "$CASE" == "wrong_subject" ]]; then printf 'other'; else printf 'chore(release): 1.2.3'; fi
    fi ;;
  diff-tree)
    if [[ "$CASE" == "wrong_files" ]]; then printf 'other\n'; else
      printf 'Keyameleon.xcodeproj/project.pbxproj\nproject.yml\n'; fi ;;
  show)
    if [[ "$CASE" == "wrong_version" ]]; then printf '    MARKETING_VERSION: "9.9.9"\n'; else
      printf '    MARKETING_VERSION: "1.2.3"\n'; fi ;;
  *) exit 1 ;;
esac
''', encoding="utf-8")
            sleep = fake_bin / "sleep"
            sleep.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            git.chmod(0o755)
            sleep.chmod(0o755)
            for case in ("present", "delayed", "timeout", "api_error", "wrong_parent", "wrong_subject", "wrong_files", "wrong_version"):
                with self.subTest(case=case):
                    working = directory / case
                    working.mkdir()
                    output = working / "output"
                    environment = os.environ | {
                        "PATH": f"{fake_bin}:{os.environ['PATH']}", "CASE": case,
                        "GITHUB_OUTPUT": str(output), "DEFAULT_BRANCH": "main",
                        "SOURCE_SHA": "source", "VERSION": "1.2.3",
                    }
                    result = subprocess.run(("bash", str(WAIT_FOR_BUMP_SCRIPT)), cwd=working, env=environment, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, case in ("present", "delayed"), result.stderr)
                    if result.returncode == 0:
                        self.assertEqual(output.read_text(), "commit=bump\n")
                    else:
                        self.assertFalse(output.exists())
                    if case == "delayed":
                        self.assertEqual((working / "count").read_text(), "2\n")
                    if case == "timeout":
                        self.assertEqual((working / "count").read_text(), "180\n")

    def test_artifact_checkpoint_waits_for_exact_same_run_bytes(self) -> None:
        self.assertIn("run: bash Scripts/wait-for-release-artifacts.sh", workflow_step("Wait for saved release artifacts"))
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            fake_bin = directory / "bin"
            fake_bin.mkdir()
            gh = fake_bin / "gh"
            gh.write_text(r'''#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "run download" ]]; then
  test "$3" = "42"
  test "$4 $5 $6 $7" = "--name official-release-1.2.3 --dir dist"
  test "$CASE" != "download_error"
  mkdir dist
  cp "$SAVED_DMG" dist/Keyameleon-1.2.3.dmg
else
  test "$*" = "api --paginate --slurp repos/example/Keyameleon/actions/runs/42/artifacts"
  test "$CASE" != "api_error"
  count=0; if [[ -f count ]]; then count="$(cat count)"; fi
  echo "$((count+1))" > count
  if [[ "$CASE" == "timeout" || ( "$CASE" == "delayed" && "$count" == 0 ) ]]; then
    printf '[{"artifacts":[]}]'
  elif [[ "$CASE" == "expired" ]]; then
    printf '[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":true}]}]'
  elif [[ "$CASE" == "duplicate" ]]; then
    printf '[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":false},{"name":"official-release-1.2.3","id":8,"expired":false}]}]'
  else
    printf '[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":false}]}]'
  fi
fi
''', encoding="utf-8")
            sleep = fake_bin / "sleep"
            sleep.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
            gh.chmod(0o755)
            sleep.chmod(0o755)
            saved_dmg = directory / "saved.dmg"
            saved_dmg.write_bytes(b"original signed bytes")
            for case in ("present", "delayed", "timeout", "api_error", "expired", "duplicate", "download_error"):
                with self.subTest(case=case):
                    working = directory / case
                    working.mkdir()
                    environment = os.environ | {
                        "PATH": f"{fake_bin}:{os.environ['PATH']}", "CASE": case,
                        "GITHUB_REPOSITORY": "example/Keyameleon", "GITHUB_RUN_ID": "42",
                        "VERSION": "1.2.3", "SAVED_DMG": str(saved_dmg),
                    }
                    result = subprocess.run(("bash", str(WAIT_FOR_ARTIFACTS_SCRIPT)), cwd=working, env=environment, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, case in ("present", "delayed"), result.stderr)
                    if result.returncode == 0:
                        self.assertEqual((working / "dist/Keyameleon-1.2.3.dmg").read_bytes(), saved_dmg.read_bytes())
                    else:
                        self.assertFalse((working / "dist").exists())
                    if case == "delayed":
                        self.assertEqual((working / "count").read_text(), "2\n")
                    if case == "timeout":
                        self.assertEqual((working / "count").read_text(), "180\n")

    def test_same_run_artifact_recovery_fails_closed(self) -> None:
        self.assertIn("run: bash Scripts/restore-release-artifacts.sh", workflow_step("Restore saved release artifacts on retry"))
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            fake_bin = directory / "bin"
            fake_bin.mkdir()
            gh = fake_bin / "gh"
            gh.write_text(r'''#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2" == "run download" ]]; then
  test "$3" = "42"
  test "$4 $5 $6 $7" = "--name official-release-1.2.3 --dir dist"
  test "$CASE" != "download_error"
  mkdir dist
  cp "$SAVED_DMG" dist/Keyameleon-1.2.3.dmg
elif [[ "$*" == *"/artifacts"* ]]; then
  test "$CASE" != "api_error"
  case "$CASE" in
    present|download_error) payload='[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":false}]}]' ;;
    expired) payload='[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":true}]}]' ;;
    duplicate) payload='[{"artifacts":[{"name":"official-release-1.2.3","id":7,"expired":false},{"name":"official-release-1.2.3","id":8,"expired":false}]}]' ;;
    *) payload='[{"artifacts":[]}]' ;;
  esac
  printf '%s' "$payload"
else
  test "$CASE" != "release_error"
  if [[ "$CASE" == "release" ]]; then printf '99'; fi
fi
''', encoding="utf-8")
            git = fake_bin / "git"
            git.write_text(r'''#!/usr/bin/env bash
set -euo pipefail
test "$CASE" != "tag_error"
if [[ "$CASE" == "tag" ]]; then printf 'sha\trefs/tags/v1.2.3\n'; fi
''', encoding="utf-8")
            gh.chmod(0o755)
            git.chmod(0o755)
            saved_dmg = directory / "saved.dmg"
            saved_dmg.write_bytes(b"original signed bytes")
            for case in ("absent", "present", "expired", "duplicate", "api_error", "download_error", "tag", "tag_error", "release", "release_error"):
                with self.subTest(case=case):
                    working = directory / case
                    working.mkdir()
                    output = working / "output"
                    environment = os.environ | {
                        "PATH": f"{fake_bin}:{os.environ['PATH']}", "CASE": case,
                        "GITHUB_REPOSITORY": "example/Keyameleon", "GITHUB_RUN_ID": "42",
                        "GITHUB_OUTPUT": str(output), "VERSION": "1.2.3", "TAG": "v1.2.3",
                        "SAVED_DMG": str(saved_dmg),
                    }
                    result = subprocess.run(("bash", str(RESTORE_ARTIFACTS_SCRIPT)), cwd=working, env=environment, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, case in ("absent", "present"), result.stderr)
                    if case == "present":
                        self.assertEqual(output.read_text(), "restored=true\n")
                        self.assertEqual((working / "dist/Keyameleon-1.2.3.dmg").read_bytes(), saved_dmg.read_bytes())
                    elif case == "absent":
                        self.assertEqual(output.read_text(), "restored=false\n")
                    else:
                        self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
