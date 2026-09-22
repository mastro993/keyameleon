#!/usr/bin/env python3
"""Calculate and optionally persist the next Official Release version."""

import argparse
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VERIFY_TAG = ROOT / "Scripts" / "verify-official-release-tag.sh"
VERSION_SETTING = re.compile(r'^    MARKETING_VERSION: "[^"]+"$', re.MULTILINE)


class ReleaseVersionError(Exception):
    pass


def latest_official_version(repository: Path) -> tuple[int, int, int]:
    result = subprocess.run(
        (
            "git",
            "tag",
            "--merged",
            "HEAD",
            "--list",
            "v*",
            "--sort=-version:refname",
        ),
        cwd=repository,
        check=True,
        text=True,
        capture_output=True,
    )

    for tag in result.stdout.splitlines():
        verified = subprocess.run(
            (str(VERIFY_TAG), tag),
            cwd=repository,
            check=False,
            text=True,
            capture_output=True,
        )
        if verified.returncode == 0:
            return tuple(int(component) for component in verified.stdout.strip().split("."))

    raise ReleaseVersionError("no Official Release tag is reachable from HEAD")


def next_version(current: tuple[int, int, int], release_type: str) -> str:
    major, minor, patch = current
    match release_type:
        case "major":
            return f"{major + 1}.0.0"
        case "minor":
            return f"{major}.{minor + 1}.0"
        case "patch":
            return f"{major}.{minor}.{patch + 1}"
        case _:
            raise ReleaseVersionError(f"unsupported release type: {release_type}")


def write_marketing_version(project: Path, version: str) -> None:
    source = project.read_text(encoding="utf-8")
    updated, count = VERSION_SETTING.subn(f'    MARKETING_VERSION: "{version}"', source)
    if count != 1:
        raise ReleaseVersionError(
            f"expected one MARKETING_VERSION setting in {project}; found {count}"
        )
    project.write_text(updated, encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("release_type", choices=("major", "minor", "patch"))
    parser.add_argument("--write", action="store_true")
    parser.add_argument("--project", type=Path, default=ROOT / "project.yml", help=argparse.SUPPRESS)
    arguments = parser.parse_args()

    try:
        version = next_version(latest_official_version(Path.cwd()), arguments.release_type)
        if arguments.write:
            write_marketing_version(arguments.project, version)
    except (ReleaseVersionError, subprocess.CalledProcessError, OSError) as error:
        print(error, file=sys.stderr)
        return 1

    print(version)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
