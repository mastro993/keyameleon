#!/usr/bin/env python3
import os
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import NOTES_SCRIPT, run


class OfficialReleaseNotesTests(unittest.TestCase):
    def test_notes_structure_groups_changes_and_links_history(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = Path(temporary_directory)
            run("git", "init", "-q", cwd=repository)
            run("git", "config", "user.name", "Release Tester", cwd=repository)
            run("git", "config", "user.email", "release@example.com", cwd=repository)

            tracked_file = repository / "change.txt"
            tracked_file.write_text("initial\n", encoding="utf-8")
            run("git", "add", "change.txt", cwd=repository)
            run("git", "commit", "-q", "-m", "Initial release", cwd=repository)
            run("git", "tag", "v0.1.0", cwd=repository)

            commits = (
                "feat: Add disk image (#12)",
                "fix: Repair update feed",
                "docs: Explain installation",
            )
            for index, subject in enumerate(commits, start=1):
                tracked_file.write_text(f"change {index}\n", encoding="utf-8")
                run("git", "add", "change.txt", cwd=repository)
                run("git", "commit", "-q", "-m", subject, cwd=repository)

            environment = os.environ.copy()
            environment["GITHUB_REPOSITORY"] = "example/Keyameleon"
            environment.pop("GH_TOKEN", None)
            result = run(
                str(NOTES_SCRIPT),
                "--tag",
                "v0.2.0",
                cwd=repository,
                env=environment,
            )

            notes = result.stdout
            self.assertTrue(notes.startswith("## v0.2.0\n\n"))
            self.assertIn("### New Features", notes)
            self.assertIn("### Bug Fixes", notes)
            self.assertIn("### Chores", notes)
            self.assertIn("\n---\n\n### Changelog", notes)
            self.assertIn(
                "**Full Changelog**: [v0.1.0...v0.2.0]"
                "(https://github.com/example/Keyameleon/compare/v0.1.0...v0.2.0)",
                notes,
            )
            self.assertIn(
                "([#12](https://github.com/example/Keyameleon/pull/12))"
                " by Release Tester",
                notes,
            )
            self.assertNotIn("### Contributors", notes)
            self.assertTrue(notes.rstrip().endswith("by Release Tester"))

    def test_notes_attribute_github_logins_without_avatar_images(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = Path(temporary_directory)
            run("git", "init", "-q", cwd=repository)
            run("git", "config", "user.name", "Release Tester", cwd=repository)
            run("git", "config", "user.email", "release@example.com", cwd=repository)

            tracked_file = repository / "change.txt"
            tracked_file.write_text("initial\n", encoding="utf-8")
            run("git", "add", "change.txt", cwd=repository)
            run("git", "commit", "-q", "-m", "Initial release", cwd=repository)
            run("git", "tag", "v0.1.0", cwd=repository)

            tracked_file.write_text("change\n", encoding="utf-8")
            run("git", "add", "change.txt", cwd=repository)
            run("git", "commit", "-q", "-m", "feat: Add disk image (#12)", cwd=repository)

            fake_bin = repository / "bin"
            fake_bin.mkdir()
            fake_gh = fake_bin / "gh"
            fake_gh.write_text(
                """#!/usr/bin/env bash
set -euo pipefail
path=""
filter=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    repos/*) path="$1" ;;
    --jq) filter="$2" ;;
  esac
  shift
done
if [[ "$path" == */pulls ]]; then
  payload='[{"number":12,"user":{"login":"octocat","id":1}}]'
else
  payload='{"author":{"login":"octocat","id":1}}'
fi
printf '%s' "$payload" | jq -r "$filter"
""",
                encoding="utf-8",
            )
            fake_gh.chmod(0o755)

            environment = os.environ.copy()
            environment["PATH"] = f"{fake_bin}{os.pathsep}{environment['PATH']}"
            environment["GH_TOKEN"] = "test-token"
            environment["GITHUB_REPOSITORY"] = "example/Keyameleon"
            result = run(
                str(NOTES_SCRIPT),
                "--tag",
                "v0.2.0",
                cwd=repository,
                env=environment,
            )

            notes = result.stdout
            self.assertIn(" by @octocat", notes)
            self.assertNotIn("### Contributors", notes)
            self.assertNotIn("avatars.githubusercontent.com", notes)
            self.assertNotIn("- Release Tester", notes)


if __name__ == "__main__":
    unittest.main()
