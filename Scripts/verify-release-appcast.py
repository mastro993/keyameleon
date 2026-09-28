#!/usr/bin/env python3
"""Check that a Sparkle feed advertises the exact Official Release DMG."""

import argparse
import base64
import hashlib
import json
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def verify(appcast: Path, evidence_path: Path, artifact: Path, expected_appcast: Path | None) -> None:
    evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
    if artifact.name != evidence["artifactFileName"]:
        raise ValueError("DMG filename differs from release evidence")
    if hashlib.sha256(artifact.read_bytes()).hexdigest() != evidence["artifactSHA256"]:
        raise ValueError("DMG SHA-256 differs from release evidence")

    feed_bytes = appcast.read_bytes()
    if expected_appcast is not None and feed_bytes != expected_appcast.read_bytes():
        raise ValueError("published appcast differs from signed appcast")

    root = ET.fromstring(feed_bytes)
    items = root.findall("./channel/item")
    if len(items) != 1:
        raise ValueError("appcast must contain exactly one release item")
    item = items[0]
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise ValueError("appcast has no enclosure")

    version = evidence["semanticVersion"]
    if evidence["tag"] != f"v{version}":
        raise ValueError("release evidence tag and version differ")
    feed_version = item.findtext(f"{SPARKLE}version") or enclosure.get(f"{SPARKLE}version")
    if feed_version != version:
        raise ValueError("appcast version differs from release evidence")
    expected_url = (
        f"https://github.com/mastro993/Keyameleon/releases/download/"
        f"{evidence['tag']}/{evidence['artifactFileName']}"
    )
    if enclosure.get("url") != expected_url:
        raise ValueError("appcast enclosure URL differs from release evidence")
    if enclosure.get("length") != str(artifact.stat().st_size):
        raise ValueError("appcast enclosure length differs from DMG")
    signature = enclosure.get(f"{SPARKLE}edSignature", "")
    try:
        decoded_signature = base64.b64decode(signature, validate=True)
    except ValueError as error:
        raise ValueError("appcast EdDSA signature is invalid base64") from error
    if len(decoded_signature) != 64:
        raise ValueError("appcast EdDSA signature must be 64 bytes")
    print(f"verified {version}: enclosure URL, size, signature, and DMG SHA-256")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--appcast", type=Path, required=True)
    parser.add_argument("--evidence", type=Path, required=True)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--expected-appcast", type=Path)
    args = parser.parse_args()
    try:
        verify(args.appcast, args.evidence, args.artifact, args.expected_appcast)
    except (OSError, ValueError, KeyError, ET.ParseError) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
