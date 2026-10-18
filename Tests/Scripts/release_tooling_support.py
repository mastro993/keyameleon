"""Shared paths and fixtures for the release tooling tests."""
import base64
import subprocess
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


def workflow_step(name: str) -> str:
    """Text of the release workflow step called `name`, up to the next step."""
    workflow = WORKFLOW.read_text(encoding="utf-8")
    return workflow.split(f"- name: {name}\n", 1)[1].split("\n      - name:", 1)[0]


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
