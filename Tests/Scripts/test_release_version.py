#!/usr/bin/env python3
import subprocess
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import RELEASE_VERSION_SCRIPT, run


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


if __name__ == "__main__":
    unittest.main()
