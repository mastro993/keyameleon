#!/usr/bin/env python3
"""Copy before signing, or verify, the exact license texts in a built app."""

import argparse
import json
from pathlib import Path
import plistlib
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    packages = parser.add_mutually_exclusive_group(required=True)
    packages.add_argument("--package-root", type=Path)
    packages.add_argument("--build-dir", type=Path)
    parser.add_argument("--copy", action="store_true", help="copy texts before signing")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    resolved = root / "Keyameleon.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    try:
        package_root = args.package_root
        if args.build_dir is not None:
            build_dir = args.build_dir.resolve()
            package_root = next(
                (ancestor / "SourcePackages" for ancestor in build_dir.parents
                 if (ancestor / "SourcePackages/artifacts/sparkle/Sparkle").is_dir()),
                None,
            )
            if package_root is None:
                raise ValueError(f"No resolved Sparkle artifact in SourcePackages above {build_dir}")
        artifact = package_root / "artifacts/sparkle/Sparkle"
        pins = json.loads(resolved.read_text())["pins"]
        version = next(pin["state"]["version"] for pin in pins if pin["identity"] == "sparkle")
        frameworks = [artifact / "Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"]
        if not args.copy:
            frameworks.append(args.app / "Contents/Frameworks/Sparkle.framework")
        for framework in frameworks:
            with (framework / "Resources/Info.plist").open("rb") as source:
                actual = plistlib.load(source).get("CFBundleShortVersionString")
            if actual != version:
                raise ValueError(f"Sparkle version mismatch at {framework}: {actual!r}, expected {version}")

        sources = {
            "LICENSE.txt": root / "LICENSE",
            "THIRD_PARTY_NOTICES.md": root / "THIRD_PARTY_NOTICES.md",
            "Sparkle-LICENSE.txt": artifact / "LICENSE",
        }
        texts = {name: source.read_bytes() for name, source in sources.items()}
        for name, content in texts.items():
            if not content.strip():
                raise ValueError(f"Empty license source: {sources[name]}")
        destination = args.app / "Contents/Resources/Licenses"
        if args.copy:
            destination.mkdir(parents=True, exist_ok=True)
            for name, content in texts.items():
                (destination / name).write_bytes(content)
        for name, content in texts.items():
            if (destination / name).read_bytes() != content:
                raise ValueError(f"Bundled license differs from source: {destination / name}")
    except (OSError, ValueError, KeyError, StopIteration, plistlib.InvalidFileException) as error:
        print(f"License packaging failed: {error}", file=sys.stderr)
        return 1
    print(f"Verified bundled licenses: {destination}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
