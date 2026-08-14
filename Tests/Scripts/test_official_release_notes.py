#!/usr/bin/env python3
"""Official Release notes: first, empty range, subjects, ignore non-Official tags."""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]
NOTES = REPO / "Scripts" / "official-release-notes.sh"


def run(repo: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=repo,
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def git(repo: Path, *args: str) -> str:
    return run(repo, "git", *args).stdout.strip()


def write_commit(repo: Path, message: str, name: str = "a.txt") -> None:
    path = repo / name
    path.write_text(path.read_text() + message + "\n" if path.exists() else message + "\n")
    git(repo, "add", name)
    git(repo, "commit", "-m", message)


def init_repo() -> tempfile.TemporaryDirectory[str]:
    tmp = tempfile.TemporaryDirectory()
    repo = Path(tmp.name)
    git(repo, "init", "-b", "main")
    git(repo, "config", "user.name", "Test")
    git(repo, "config", "user.email", "test@example.com")
    return tmp


def notes(repo: Path, rev: str = "HEAD") -> str:
    os.chmod(NOTES, 0o755)
    return run(repo, str(NOTES), rev).stdout


class OfficialReleaseNotesTests(unittest.TestCase):
    def test_first_official_release(self) -> None:
        with init_repo() as name:
            repo = Path(name)
            write_commit(repo, "first")
            self.assertEqual(notes(repo), "Initial Official Release\n")

    def test_empty_range_same_commit(self) -> None:
        with init_repo() as name:
            repo = Path(name)
            write_commit(repo, "first")
            git(repo, "tag", "-a", "v1.0.0", "-m", "1.0.0")
            self.assertEqual(notes(repo), "No source changes since v1.0.0\n")

    def test_subjects_since_previous_without_merges(self) -> None:
        with init_repo() as name:
            repo = Path(name)
            write_commit(repo, "first")
            git(repo, "tag", "-a", "v1.0.0", "-m", "1.0.0")
            write_commit(repo, "fix switch")
            git(repo, "checkout", "-b", "topic")
            write_commit(repo, "topic work", "b.txt")
            git(repo, "checkout", "main")
            git(repo, "merge", "--no-ff", "-m", "Merge topic", "topic")
            write_commit(repo, "docs notes")
            self.assertEqual(notes(repo), "- fix switch\n- topic work\n- docs notes\n")

    def test_ignores_prerelease_and_non_ancestor_tags(self) -> None:
        with init_repo() as name:
            repo = Path(name)
            write_commit(repo, "base")
            git(repo, "tag", "-a", "v1.0.0", "-m", "1.0.0")
            write_commit(repo, "stable work")
            git(repo, "tag", "-a", "v1.0.1-beta.1", "-m", "beta")
            git(repo, "branch", "other")
            git(repo, "checkout", "other")
            write_commit(repo, "other line", "other.txt")
            git(repo, "tag", "-a", "v2.0.0", "-m", "2.0.0")
            git(repo, "checkout", "main")
            self.assertEqual(notes(repo), "- stable work\n")


if __name__ == "__main__":
    unittest.main()
