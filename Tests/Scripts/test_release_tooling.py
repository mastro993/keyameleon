#!/usr/bin/env python3
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NOTES_SCRIPT = ROOT / "Scripts" / "official-release-notes.sh"
EVIDENCE_SCRIPT = ROOT / "Scripts" / "write-release-evidence.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "release.yml"


def run(*args: str, cwd: Path, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd,
        env=env,
        check=True,
        text=True,
        capture_output=True,
    )


class OfficialReleaseNotesTests(unittest.TestCase):
    def test_openusage_structure_groups_changes_and_links_history(self) -> None:
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
            self.assertIn("### Contributors\n\n- Release Tester", notes)


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
            self.assertEqual(evidence["artifactFileName"], "Keyameleon-1.2.3.dmg")
            self.assertEqual(
                evidence["feedURLString"],
                "https://mastro993.github.io/Keyameleon/appcast.xml",
            )
            self.assertNotIn("sourceArchiveFileName", evidence)


class ReleaseWorkflowTests(unittest.TestCase):
    def test_release_page_has_only_the_dmg_as_a_managed_asset(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        release_create = workflow.split('gh release create "$TAG"', maxsplit=1)[1]
        self.assertIn('"dist/Keyameleon-${VERSION}.dmg"', release_create)
        self.assertNotIn("dist/appcast.xml", release_create)
        self.assertNotIn("dist/release-evidence.json", release_create)
        self.assertNotIn("Keyameleon-source-", workflow)
        self.assertIn("peaceiris/actions-gh-pages@v4", workflow)
        self.assertIn("path: dist/release-evidence.json", workflow)


if __name__ == "__main__":
    unittest.main()
