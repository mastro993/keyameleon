#!/usr/bin/env python3
import base64
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
                "https://mastro993.github.io/keyameleon/appcast.xml",
            )
            self.assertNotIn("sourceArchiveFileName", evidence)


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

    def test_release_asset_precedes_pages_and_crosses_artifact_boundary(self) -> None:
        workflow = WORKFLOW.read_text(encoding="utf-8")
        produce = workflow.split("  produce:", maxsplit=1)[1].split("  publish:", maxsplit=1)[0]
        publish = workflow.split("  publish:", maxsplit=1)[1]
        self.assertIn("actions/upload-artifact@", produce)
        self.assertIn("dist/Keyameleon-${{ needs.verify.outputs.version }}.dmg", produce)
        self.assertIn("dist/appcast.xml", produce)
        self.assertIn("dist/release-evidence.json", produce)
        self.assertIn("- produce", publish)
        self.assertIn("actions/download-artifact@", publish)
        self.assertLess(publish.index("Publish and verify downloadable DMG"), publish.index("peaceiris/actions-gh-pages@v4"))
        self.assertNotIn("Keyameleon-source-", workflow)
        self.assertIn("pull-requests: read", workflow)


if __name__ == "__main__":
    unittest.main()
