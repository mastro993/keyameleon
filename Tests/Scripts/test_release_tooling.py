#!/usr/bin/env python3
import base64
import fnmatch
import hashlib
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
VERIFY_APPCAST_SCRIPT = ROOT / "Scripts" / "verify-release-appcast.py"
PUBLISH_ASSET_SCRIPT = ROOT / "Scripts" / "publish-official-release-asset.sh"
PUBLISH_PAGES_SCRIPT = ROOT / "Scripts" / "publish-release-pages.sh"
VERIFY_TAG_SCRIPT = ROOT / "Scripts" / "verify-official-release-tag.sh"
PUBLISH_CASK_SCRIPT = ROOT / "Scripts" / "publish-homebrew-cask.sh"


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


class OfficialReleaseTagTests(unittest.TestCase):
    def test_tags_require_strict_semantic_versioning_cores(self) -> None:
        for tag, version in (
            ("v0.1.0", "0.1.0"), ("v1.2.3", "1.2.3"), ("v10.20.30", "10.20.30"),
            ("1.2.3", None), ("v1.2", None), ("v1.2.3-beta.1", None),
            ("v1.2.3+build.1", None), ("release-1.2.3", None),
            ("v01.2.3", None), ("v1.02.3", None), ("v1.2.03", None), ("", None),
        ):
            with self.subTest(tag=tag):
                result = subprocess.run(
                    (str(VERIFY_TAG_SCRIPT), tag),
                    cwd=ROOT,
                    check=False,
                    text=True,
                    capture_output=True,
                )
                if version is not None:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, f"{version}\n")
                else:
                    self.assertEqual(result.returncode, 1 if tag else 64)
                    self.assertEqual(result.stdout, "")


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
            self.assertEqual(evidence["product"], "Keyameleon")
            self.assertEqual(evidence["licenseSPDXIdentifier"], "MIT")
            self.assertEqual(evidence["tag"], "v1.2.3")
            self.assertEqual(evidence["semanticVersion"], "1.2.3")
            self.assertEqual(evidence["gitCommit"], "abc123")
            self.assertEqual(evidence["artifactFileName"], "Keyameleon-1.2.3.dmg")
            self.assertEqual(evidence["artifactSHA256"], hashlib.sha256(disk_image.read_bytes()).hexdigest())
            self.assertEqual(evidence["appcastFileName"], "appcast.xml")
            self.assertEqual(
                evidence["feedURLString"],
                "https://mastro993.github.io/keyameleon/appcast.xml",
            )
            self.assertNotIn("sourceArchiveFileName", evidence)

    def test_invalid_release_inputs_do_not_write_evidence(self) -> None:
        for tag, commit, filename, error in (
            ("1.2.3", "abc123", "Keyameleon-1.2.3.dmg", "not an Official Release tag"),
            ("v1.2.3", "", "Keyameleon-1.2.3.dmg", "usage: write-release-evidence.sh"),
            ("v1.2.3", "abc123", "Keyameleon-1.2.4.dmg", "artifact must be named"),
        ):
            with self.subTest(tag=tag, commit=commit, filename=filename), \
                    tempfile.TemporaryDirectory() as temporary_directory:
                directory = Path(temporary_directory)
                artifact = directory / filename
                artifact.write_bytes(b"disk image fixture")
                evidence = directory / "release-evidence.json"
                result = subprocess.run(
                    (str(EVIDENCE_SCRIPT), "--tag", tag, "--commit", commit,
                     "--artifact", str(artifact), "--output", str(evidence)),
                    cwd=ROOT,
                    check=False,
                    text=True,
                    capture_output=True,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(error, result.stderr)
                self.assertFalse(evidence.exists())


class ReleaseAppcastTests(unittest.TestCase):
    @staticmethod
    def make_release(directory: Path) -> tuple[Path, Path, Path]:
        artifact = directory / "Keyameleon-1.2.3.dmg"
        artifact.write_bytes(b"signed disk image fixture")
        evidence = directory / "release-evidence.json"
        run(
            str(EVIDENCE_SCRIPT),
            "--tag", "v1.2.3",
            "--commit", "abc123",
            "--artifact", str(artifact),
            "--output", str(evidence),
            cwd=ROOT,
        )
        appcast = directory / "appcast.xml"
        signature = base64.b64encode(bytes(range(64))).decode("ascii")
        appcast.write_text(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">\n'
            '<channel><item>\n'
            '<sparkle:version>1.2.3</sparkle:version>\n'
            '<sparkle:shortVersionString>1.2.3</sparkle:shortVersionString>\n'
            f'<enclosure url="https://github.com/mastro993/Keyameleon/releases/download/v1.2.3/{artifact.name}" '
            f'length="{artifact.stat().st_size}" sparkle:edSignature="{signature}" '
            'type="application/octet-stream"/>\n'
            '</item></channel></rss>\n',
            encoding="utf-8",
        )
        return artifact, evidence, appcast

    def verify(self, artifact: Path, evidence: Path, appcast: Path, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            (
                "python3", str(VERIFY_APPCAST_SCRIPT),
                "--appcast", str(appcast),
                "--evidence", str(evidence),
                "--artifact", str(artifact),
                *extra,
            ),
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )

    def test_matching_appcast_and_evidence_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact, evidence, appcast = self.make_release(Path(temporary_directory))
            self.assertEqual(self.verify(artifact, evidence, appcast).returncode, 0)

    def test_appcast_rejects_wrong_version_size_signature_or_url(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact, evidence, appcast = self.make_release(Path(temporary_directory))
            original = appcast.read_text(encoding="utf-8")
            signature = base64.b64encode(bytes(range(64))).decode("ascii")
            for label, changed in (
                ("version", original.replace("<sparkle:version>1.2.3", "<sparkle:version>1.2.2")),
                ("size", original.replace(f'length="{artifact.stat().st_size}"', 'length="1"')),
                ("signature", original.replace(f'sparkle:edSignature="{signature}"', 'sparkle:edSignature=""')),
                ("url", original.replace("/download/v1.2.3/", "/download/v1.2.2/")),
            ):
                with self.subTest(label=label):
                    appcast.write_text(changed, encoding="utf-8")
                    self.assertNotEqual(self.verify(artifact, evidence, appcast).returncode, 0)

    def test_appcast_rejects_changed_artifact_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact, evidence, appcast = self.make_release(Path(temporary_directory))
            artifact.write_bytes(b"changed disk image fixture")
            self.assertNotEqual(self.verify(artifact, evidence, appcast).returncode, 0)

    def test_published_feed_must_match_staged_feed_byte_for_byte(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            artifact, evidence, appcast = self.make_release(Path(temporary_directory))
            published = appcast.with_name("published-appcast.xml")
            published.write_bytes(appcast.read_bytes())
            self.assertEqual(
                self.verify(artifact, evidence, published, "--expected-appcast", str(appcast)).returncode,
                0,
            )
            published.write_bytes(appcast.read_bytes() + b"<!-- stale cache -->\n")
            self.assertNotEqual(
                self.verify(artifact, evidence, published, "--expected-appcast", str(appcast)).returncode,
                0,
            )


class PublishReleaseAssetTests(unittest.TestCase):
    def test_retry_keeps_uploaded_asset_and_repairs_starter_asset(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            directory = Path(temporary_directory)
            dist = directory / "dist"
            dist.mkdir()
            download = directory / "download"
            asset, _, _ = ReleaseAppcastTests.make_release(dist)
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


class ReleaseWorkflowTests(unittest.TestCase):
    def test_producer_cannot_write_repository_or_change_publisher_source(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("\n  produce:\n", workflow)
        producer = workflow.split("\n  produce:\n", 1)[1].split("\n  publish:\n", 1)[0]
        publisher = workflow.split("\n  publish:\n", 1)[1]
        self.assertNotIn("RELEASE_DEPLOY_KEY", producer)
        self.assertNotIn("contents: write", producer)
        self.assertIn("persist-credentials: false", producer)
        self.assertIn("ref: ${{ github.sha }}", publisher)
        self.assertNotIn("git checkout", publisher)
        self.assertNotIn("./Scripts/run.sh test", publisher)
        self.assertNotIn("./Scripts/official-release.sh", publisher)
        self.assertNotIn("secrets.APPLE_", publisher)
        self.assertIn('git tag -a "$TAG" "$COMMIT"', publisher)

    def test_run_tests_rejects_invalid_pages_publisher(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            scripts = Path(temporary_directory) / "Scripts"
            scripts.mkdir()
            for name in ("official-release-notes.sh", "verify-official-release-tag.sh",
                         "write-release-evidence.sh", "official-release.sh"):
                (scripts / name).write_text("exit 0\n", encoding="utf-8")
            (scripts / "publish-release-pages.sh").write_text("if\n", encoding="utf-8")
            command = r'''
set -e
source <(sed -n '/^run_tests()/,/^}/p' "$1")
cd "$2"
python3() { return 0; }
xcodebuild() { return 0; }
kill_leftover_derived_data_keyameleon() { return 0; }
DERIVED_DATA_PATH="$2/build"
run_tests
'''
            result = subprocess.run(
                ("zsh", "-c", command, "test", str(ROOT / "Scripts/run.sh"), temporary_directory),
                capture_output=True, text=True, check=False,
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("Scripts/publish-release-pages.sh", result.stderr)
            self.assertIn("syntax error", result.stderr)

    def test_version_commit_installs_pinned_swiftlint_before_tests(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        release = workflow.split("\n  produce:\n", maxsplit=1)[1].split("\n  publish:\n", 1)[0]
        before_tests = release.split("- name: Test version commit", maxsplit=1)[0]
        configuration = (ROOT / ".swiftlint.yml").read_text(encoding="utf-8")
        version = configuration.split('swiftlint_version: "', maxsplit=1)[1].split('"', maxsplit=1)[0]
        ci_workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
        checksum_command = next(
            line.strip() for line in ci_workflow.splitlines()
            if line.strip().startswith('echo "') and "swiftlint.zip" in line
        )
        self.assertIn(f"Install SwiftLint {version}", before_tests)
        self.assertIn(f"/releases/download/{version}/portable_swiftlint.zip", before_tests)
        self.assertIn(checksum_command, before_tests)
        self.assertIn("| shasum -a 256 --check", before_tests)
        self.assertIn('echo "${swiftlint_dir}" >> "${GITHUB_PATH}"', before_tests)

    def test_dispatch_selects_release_type_and_tags_the_bump_commit(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertIn("release_type:", workflow)
        self.assertIn("type: choice", workflow)
        self.assertIn("default: patch", workflow)
        self.assertIn("- major\n          - minor\n          - patch", workflow)
        self.assertNotIn("inputs.version", workflow)
        self.assertIn('git commit -m "chore(release): ${VERSION}"', workflow)
        self.assertIn("COMMIT: ${{ steps.bump.outputs.commit }}", workflow)
        self.assertIn('--head "${{ github.sha }}"', workflow)

    def test_batch_approval_preserves_isolated_publication_order(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        self.assertEqual(workflow.count("environment: official-release"), 3)
        for job in ("bump", "produce", "publish"):
            body = workflow.split(f"\n  {job}:\n", 1)[1].split("\n  bump:\n", 1)[0].split("\n  produce:\n", 1)[0].split("\n  publish:\n", 1)[0]
            self.assertIn("needs: verify", body)
        producer = workflow.split("\n  produce:\n", 1)[1].split("\n  publish:\n", 1)[0]
        publisher = workflow.split("\n  publish:\n", 1)[1]
        self.assertLess(producer.index("Test version commit"), producer.index("Upload workflow artifacts"))
        for step in ("Test version commit", "Produce signed, notarized, stapled artifacts", "Upload workflow artifacts"):
            self.assertIn(f"- name: {step}\n        if: steps.saved.outputs.restored != 'true'", producer)
        steps = ("Wait for saved release artifacts", "Validate published version commit",
                 "Require complete artifact bundle", "Prepare Official Release tag and notes",
                 "Publish and verify downloadable DMG", "bash Scripts/publish-release-pages.sh",
                 "Verify published feed and enclosure")
        self.assertEqual([publisher.index(step) for step in steps], sorted(publisher.index(step) for step in steps))
        self.assertIn('cmp -s "$RUNNER_TEMP/published-evidence.json" dist/release-evidence.json', publisher)
        self.assertNotIn("Keyameleon-source-", workflow)

    def test_version_checkpoint_waits_and_rejects_unexpected_main(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        step = workflow.split("- name: Wait for validated version commit", 1)[1].split("\n      - name:", 1)[0]
        command = "\n".join(line[10:] for line in step.split("        run: |\n", 1)[1].splitlines())
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
                    result = subprocess.run(("bash", "-c", command), cwd=working, env=environment, capture_output=True, text=True)
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
        workflow = WORKFLOW.read_text(encoding="utf-8")
        step = workflow.split("- name: Wait for saved release artifacts", 1)[1].split("\n      - name:", 1)[0]
        command = "\n".join(line[10:] for line in step.split("        run: |\n", 1)[1].splitlines())
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
                    result = subprocess.run(("bash", "-c", command), cwd=working, env=environment, capture_output=True, text=True)
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
        workflow = WORKFLOW.read_text(encoding="utf-8")
        step = workflow.split("- name: Restore saved release artifacts on retry", 1)[1].split("\n      - name:", 1)[0]
        command = "\n".join(line[10:] for line in step.split("        run: |\n", 1)[1].splitlines())
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
                    result = subprocess.run(("bash", "-c", command), cwd=working, env=environment, capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, case in ("absent", "present"), result.stderr)
                    if case == "present":
                        self.assertEqual(output.read_text(), "restored=true\n")
                        self.assertEqual((working / "dist/Keyameleon-1.2.3.dmg").read_bytes(), saved_dmg.read_bytes())
                    elif case == "absent":
                        self.assertEqual(output.read_text(), "restored=false\n")
                    else:
                        self.assertFalse(output.exists())

    def test_protected_version_commit_and_tag_use_deploy_key(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        release = workflow.split("\n  publish:\n", maxsplit=1)[1]
        checkout = release.split("- uses: actions/checkout@v7\n", maxsplit=1)[1].split("\n\n", maxsplit=1)[0]
        self.assertIn("ssh-key: ${{ secrets.RELEASE_DEPLOY_KEY }}", checkout)
        self.assertIn("environment: official-release", release)

        documentation = (ROOT / "docs" / "release" / "official-release.md").read_text(
            encoding="utf-8"
        )
        glob = documentation.split("Target tags: `", maxsplit=1)[1].split("`", maxsplit=1)[0]
        self.assertTrue(fnmatch.fnmatchcase("v0.4.5", glob))
        self.assertTrue(fnmatch.fnmatchcase("v0notasemver", glob))
        rejected = subprocess.run(
            (str(ROOT / "Scripts" / "verify-official-release-tag.sh"), "v0notasemver"),
            cwd=ROOT,
            check=False,
            text=True,
            capture_output=True,
        )
        self.assertEqual(rejected.returncode, 1)


if __name__ == "__main__":
    unittest.main()
