#!/usr/bin/env python3
import hashlib
import subprocess
import tempfile
import unittest
from pathlib import Path

from release_tooling_support import ROOT, WORKFLOW, PUBLISH_CASK_SCRIPT, run


class PublishHomebrewCaskTests(unittest.TestCase):
    CASK = (
        'cask "keyameleon" do\n'
        '  version "1.2.3"\n'
        f'  sha256 "{"a" * 64}"\n'
        "\n"
        '  url "https://github.com/mastro993/Keyameleon/releases/download/v#{version}/Keyameleon-#{version}.dmg"\n'
        "end\n"
    )

    @classmethod
    def tap(cls, directory: Path) -> tuple[Path, Path]:
        remote = directory / "tap.git"
        tap = directory / "tap"
        run("git", "init", "--bare", "-q", "-b", "main", str(remote), cwd=directory)
        run("git", "clone", "-q", str(remote), str(tap), cwd=directory)
        run("git", "config", "user.name", "Tap Tester", cwd=tap)
        run("git", "config", "user.email", "tap@example.com", cwd=tap)
        (tap / "Casks").mkdir()
        (tap / "Casks/keyameleon.rb").write_text(cls.CASK, encoding="utf-8")
        run("git", "add", ".", cwd=tap)
        run("git", "commit", "-q", "-m", "Add keyameleon", cwd=tap)
        run("git", "push", "-q", "origin", "HEAD:main", cwd=tap)
        return tap, remote

    @staticmethod
    def publish(tap: Path, version: str, dmg: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ("bash", str(PUBLISH_CASK_SCRIPT), str(tap), version, str(dmg)),
            cwd=ROOT, check=False, text=True, capture_output=True,
        )

    @staticmethod
    def head(remote: Path) -> str:
        return run("git", "--git-dir", str(remote), "rev-parse", "main", cwd=remote).stdout.strip()

    def test_publish_updates_version_and_checksum_once(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            tap, remote = self.tap(directory)
            dmg = directory / "Keyameleon-1.2.4.dmg"
            dmg.write_bytes(b"signed 1.2.4")
            digest = hashlib.sha256(dmg.read_bytes()).hexdigest()

            result = self.publish(tap, "1.2.4", dmg)
            self.assertEqual(result.returncode, 0, result.stderr)
            published = run("git", "--git-dir", str(remote), "show", "main:Casks/keyameleon.rb", cwd=directory).stdout
            self.assertEqual(
                published,
                self.CASK.replace('"1.2.3"', '"1.2.4"').replace("a" * 64, digest),
            )
            self.assertEqual(
                run("git", "--git-dir", str(remote), "log", "-1", "--format=%s", "main", cwd=directory).stdout.strip(),
                "keyameleon 1.2.4",
            )
            first_head = self.head(remote)
            self.assertEqual(self.publish(tap, "1.2.4", dmg).returncode, 0)
            self.assertEqual(self.head(remote), first_head)

    def test_conflicting_older_or_invalid_versions_do_not_push(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            tap, remote = self.tap(directory)
            before = self.head(remote)
            dmg = directory / "Keyameleon.dmg"
            dmg.write_bytes(b"different bytes")

            conflict = self.publish(tap, "1.2.3", dmg)
            self.assertIn("already has a different sha256", conflict.stderr)
            older = self.publish(tap, "1.2.2", dmg)
            self.assertIn("already points at newer version 1.2.3", older.stderr)
            self.assertNotEqual(self.publish(tap, "1.2.10/x", dmg).returncode, 0)
            for result in (conflict, older):
                self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.head(remote), before)
            self.assertEqual((tap / "Casks/keyameleon.rb").read_text(encoding="utf-8"), self.CASK)

    def test_minor_and_major_versions_sort_numerically(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            tap, _ = self.tap(directory)
            dmg = directory / "Keyameleon.dmg"
            dmg.write_bytes(b"signed")
            for version in ("1.2.10", "1.10.0", "10.0.0"):
                result = self.publish(tap, version, dmg)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_workflow_publishes_cask_after_verified_feed(self) -> None:
        publisher = WORKFLOW.read_text(encoding="utf-8").split("\n  publish:\n", 1)[1]
        feed = publisher.index("- name: Verify published feed and enclosure")
        tap = publisher.index("- name: Check out Homebrew tap")
        cask = publisher.index("- name: Publish Homebrew cask")
        self.assertLess(feed, tap)
        self.assertLess(tap, cask)
        self.assertIn("ssh-key: ${{ secrets.HOMEBREW_TAP_DEPLOY_KEY }}", publisher[tap:cask])
        self.assertIn('"$RUNNER_TEMP/release-asset/Keyameleon-${VERSION}.dmg"', publisher[cask:])

    def test_workflow_rebuilds_site_last_without_failing_release(self) -> None:
        publisher = WORKFLOW.read_text(encoding="utf-8").split("\n  publish:\n", 1)[1]
        cask = publisher.index("- name: Publish Homebrew cask")
        site = publisher.index("- name: Rebuild keyameleon.app")
        self.assertLess(cask, site)
        step = publisher[site:]
        self.assertNotIn("- name:", step[len("- name:"):])
        self.assertIn("continue-on-error: true", step)
        self.assertIn("DEPLOY_HOOK: ${{ secrets.KEYAMELEON_WEB_DEPLOY_HOOK }}", step)
        self.assertNotIn('echo "${DEPLOY_HOOK}', step)


if __name__ == "__main__":
    unittest.main()
