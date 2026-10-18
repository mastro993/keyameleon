#!/usr/bin/env python3
import base64
import subprocess
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import ROOT, EVIDENCE_SCRIPT, PUBLISH_PAGES_SCRIPT, run


class PublishReleasePagesTests(unittest.TestCase):
    @staticmethod
    def repository(directory: Path) -> tuple[Path, Path, str]:
        remote = directory / "remote.git"
        source = directory / "source"
        source.mkdir()
        run("git", "init", "--bare", "-q", str(remote), cwd=directory)
        run("git", "init", "-q", "-b", "main", cwd=source)
        run("git", "config", "user.name", "Release Tester", cwd=source)
        run("git", "config", "user.email", "release@example.com", cwd=source)
        run("git", "remote", "add", "origin", str(remote), cwd=source)
        (source / "source.txt").write_text("release source\n", encoding="utf-8")
        run("git", "add", "source.txt", cwd=source)
        run("git", "commit", "-q", "-m", "Release source", cwd=source)
        commit = run("git", "rev-parse", "HEAD", cwd=source).stdout.strip()
        run("git", "tag", "-a", "v1.2.3", "-m", "v1.2.3", cwd=source)
        run("git", "push", "-q", "origin", "main", "--tags", cwd=source)
        run("git", "checkout", "-q", "--orphan", "gh-pages", cwd=source)
        (source / "source.txt").unlink()
        (source / "older.txt").write_text("keep old content\n", encoding="utf-8")
        run("git", "add", "older.txt", cwd=source)
        run("git", "commit", "-q", "-m", "Existing Pages", cwd=source)
        run("git", "push", "-q", "origin", "gh-pages", cwd=source)
        run("git", "checkout", "-q", "main", cwd=source)
        return source, remote, commit

    @staticmethod
    def bundle(directory: Path, commit: str, version: str = "1.2.3") -> tuple[Path, Path]:
        dist = directory / f"dist-{version}"
        dist.mkdir()
        artifact = dist / f"Keyameleon-{version}.dmg"
        artifact.write_bytes(f"signed {version}".encode())
        run(
            str(EVIDENCE_SCRIPT), "--tag", f"v{version}", "--commit", commit,
            "--artifact", str(artifact), "--output", str(dist / "release-evidence.json"), cwd=ROOT,
        )
        signature = base64.b64encode(bytes(range(64))).decode("ascii")
        (dist / "appcast.xml").write_text(
            '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
            f'<channel><item><sparkle:version>{version}</sparkle:version>'
            f'<enclosure url="https://github.com/mastro993/Keyameleon/releases/download/v{version}/{artifact.name}" '
            f'length="{artifact.stat().st_size}" sparkle:edSignature="{signature}"/>'
            '</item></channel></rss>', encoding="utf-8",
        )
        return dist, artifact

    @staticmethod
    def publish(source: Path, commit: str, dist: Path, artifact: Path, tag: str = "v1.2.3") -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ("bash", str(PUBLISH_PAGES_SCRIPT), tag, commit, str(dist), str(artifact)),
            cwd=source, check=False, text=True, capture_output=True,
        )

    def test_publish_retry_and_next_version_keep_older_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            source, remote, commit = self.repository(directory)
            dist, artifact = self.bundle(directory, commit)
            self.assertEqual(self.publish(source, commit, dist, artifact).returncode, 0)
            first_head = run("git", "--git-dir", str(remote), "rev-parse", "gh-pages", cwd=directory).stdout.strip()
            published = directory / "published"
            run("git", "clone", "-q", "-b", "gh-pages", str(remote), str(published), cwd=directory)
            self.assertEqual((published / "releases/v1.2.3/release-evidence.json").read_bytes(), (dist / "release-evidence.json").read_bytes())
            self.assertEqual((published / "appcast.xml").read_bytes(), (dist / "appcast.xml").read_bytes())
            self.assertEqual((published / "older.txt").read_text(), "keep old content\n")
            self.assertTrue((published / ".nojekyll").exists())
            self.assertEqual(self.publish(source, commit, dist, artifact).returncode, 0)
            self.assertEqual(run("git", "--git-dir", str(remote), "rev-parse", "gh-pages", cwd=directory).stdout.strip(), first_head)

            run("git", "tag", "-a", "v1.2.4", "-m", "v1.2.4", cwd=source)
            run("git", "push", "-q", "origin", "v1.2.4", cwd=source)
            next_dist, next_artifact = self.bundle(directory, commit, "1.2.4")
            self.assertEqual(self.publish(source, commit, next_dist, next_artifact, "v1.2.4").returncode, 0)
            run("git", "pull", "-q", cwd=published)
            self.assertEqual((published / "releases/v1.2.3/release-evidence.json").read_bytes(), (dist / "release-evidence.json").read_bytes())
            self.assertEqual((published / "releases/v1.2.4/release-evidence.json").read_bytes(), (next_dist / "release-evidence.json").read_bytes())

    def test_conflicts_and_remote_tag_mismatch_do_not_mutate_pages(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            source, remote, commit = self.repository(directory)
            dist, artifact = self.bundle(directory, commit)
            before = run("git", "--git-dir", str(remote), "rev-parse", "gh-pages", cwd=directory).stdout.strip()
            wrong_commit = "0" * 40
            self.assertNotEqual(self.publish(source, wrong_commit, dist, artifact).returncode, 0)
            run("git", "tag", "-f", "v1.2.3", cwd=source)
            run("git", "push", "-q", "--force", "origin", "v1.2.3", cwd=source)
            self.assertNotEqual(self.publish(source, commit, dist, artifact).returncode, 0)
            self.assertEqual(run("git", "--git-dir", str(remote), "rev-parse", "gh-pages", cwd=directory).stdout.strip(), before)
            (source / "source.txt").write_text("different source\n", encoding="utf-8")
            run("git", "add", "source.txt", cwd=source)
            run("git", "commit", "-q", "-m", "Different source", cwd=source)
            run("git", "tag", "-fa", "v1.2.3", "-m", "different source", cwd=source)
            run("git", "push", "-q", "--force", "origin", "v1.2.3", cwd=source)
            mismatch = self.publish(source, commit, dist, artifact)
            self.assertNotEqual(mismatch.returncode, 0)
            self.assertIn("remote annotated tag v1.2.3 does not match", mismatch.stderr)
            self.assertEqual(run("git", "--git-dir", str(remote), "rev-parse", "gh-pages", cwd=directory).stdout.strip(), before)
            run("git", "tag", "-fa", "v1.2.3", commit, "-m", "v1.2.3", cwd=source)
            run("git", "push", "-q", "--force", "origin", "v1.2.3", cwd=source)
            self.assertEqual(self.publish(source, commit, dist, artifact).returncode, 0)
            published_head = run("git", "--git-dir", str(remote), "rev-parse", "gh-pages", cwd=directory).stdout.strip()
            evidence = dist / "release-evidence.json"
            artifact.write_bytes(b"x" * artifact.stat().st_size)
            run(
                str(EVIDENCE_SCRIPT), "--tag", "v1.2.3", "--commit", commit,
                "--artifact", str(artifact), "--output", str(evidence), cwd=ROOT,
            )
            conflict = self.publish(source, commit, dist, artifact)
            self.assertNotEqual(conflict.returncode, 0)
            self.assertIn("release evidence already exists with different bytes", conflict.stderr)
            self.assertEqual(run("git", "--git-dir", str(remote), "rev-parse", "gh-pages", cwd=directory).stdout.strip(), published_head)


if __name__ == "__main__":
    unittest.main()
