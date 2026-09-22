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
RELEASE_VERSION_SCRIPT = ROOT / "Scripts" / "release-version.py"
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


class ReleaseVersionTests(unittest.TestCase):
    def make_repository(self, directory: Path, tags: tuple[str, ...] = ("v0.2.3",)) -> Path:
        repository = directory / "repository"
        repository.mkdir()
        run("git", "init", "-q", cwd=repository)
        run("git", "config", "user.name", "Release Tester", cwd=repository)
        run("git", "config", "user.email", "release@example.com", cwd=repository)
        project = repository / "project.yml"
        project.write_text(
            'settings:\n  base:\n    MARKETING_VERSION: "0.1.0"\n'
            '    CURRENT_PROJECT_VERSION: "1"\n',
            encoding="utf-8",
        )
        run("git", "add", "project.yml", cwd=repository)
        run("git", "commit", "-q", "-m", "Initial release", cwd=repository)
        for tag in tags:
            run("git", "tag", tag, cwd=repository)
        return repository

    def test_release_types_increment_latest_official_tag(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = self.make_repository(Path(temporary_directory), ("v0.2.3", "v9.9.9-beta"))

            for release_type, expected in (
                ("patch", "0.2.4"),
                ("minor", "0.3.0"),
                ("major", "1.0.0"),
            ):
                with self.subTest(release_type=release_type):
                    result = run(
                        "python3",
                        str(RELEASE_VERSION_SCRIPT),
                        release_type,
                        cwd=repository,
                    )
                    self.assertEqual(result.stdout.strip(), expected)

    def test_release_rejects_unknown_type(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = self.make_repository(Path(temporary_directory))

            result = subprocess.run(
                ("python3", str(RELEASE_VERSION_SCRIPT), "hotfix"),
                cwd=repository,
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 2)
            self.assertIn("invalid choice", result.stderr)

    def test_write_updates_exactly_one_marketing_version(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = self.make_repository(Path(temporary_directory))
            project = repository / "project.yml"

            result = run(
                "python3",
                str(RELEASE_VERSION_SCRIPT),
                "patch",
                "--write",
                "--project",
                str(project),
                cwd=repository,
            )

            self.assertEqual(result.stdout.strip(), "0.2.4")
            self.assertIn('MARKETING_VERSION: "0.2.4"', project.read_text(encoding="utf-8"))
            self.assertIn('CURRENT_PROJECT_VERSION: "1"', project.read_text(encoding="utf-8"))

    def test_write_rejects_ambiguous_marketing_version_settings(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = self.make_repository(Path(temporary_directory))
            project = repository / "project.yml"
            project.write_text(
                project.read_text(encoding="utf-8") + '    MARKETING_VERSION: "9.9.9"\n',
                encoding="utf-8",
            )

            result = subprocess.run(
                (
                    "python3",
                    str(RELEASE_VERSION_SCRIPT),
                    "patch",
                    "--write",
                    "--project",
                    str(project),
                ),
                cwd=repository,
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 1)
            self.assertIn("expected one MARKETING_VERSION setting", result.stderr)

    def test_release_requires_an_official_tag(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            repository = self.make_repository(Path(temporary_directory), ("not-a-version",))

            result = subprocess.run(
                ("python3", str(RELEASE_VERSION_SCRIPT), "patch"),
                cwd=repository,
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 1)
            self.assertIn("no Official Release tag", result.stderr)


class ReleaseWorkflowTests(unittest.TestCase):
    def test_dispatch_selects_release_type_and_tags_the_bump_commit(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("release_type:", workflow)
        self.assertIn("type: choice", workflow)
        self.assertIn("default: patch", workflow)
        self.assertIn("- major\n          - minor\n          - patch", workflow)
        self.assertNotIn("inputs.version", workflow)
        self.assertIn('git commit -m "chore(release): ${VERSION}"', workflow)
        self.assertIn("ref: ${{ needs.bump.outputs.commit }}", workflow)
        self.assertIn('--head "${{ github.sha }}"', workflow)
        self.assertIn("ssh-key: ${{ secrets.RELEASE_DEPLOY_KEY }}", workflow)

    def test_release_page_has_only_the_dmg_as_a_managed_asset(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        release_create = workflow.split('gh release create "$TAG"', maxsplit=1)[1]
        self.assertIn('"dist/Keyameleon-${VERSION}.dmg"', release_create)
        self.assertNotIn("dist/appcast.xml", release_create)
        self.assertNotIn("dist/release-evidence.json", release_create)
        self.assertNotIn("Keyameleon-source-", workflow)
        self.assertIn("peaceiris/actions-gh-pages@v4", workflow)
        self.assertIn("path: dist/release-evidence.json", workflow)
        self.assertIn("pull-requests: read", workflow)


if __name__ == "__main__":
    unittest.main()
