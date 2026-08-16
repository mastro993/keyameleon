#!/usr/bin/env python3
"""Normalize a Sparkle EdDSA key from stdin to a one-line base64 file.

Accepts generate_keys -x / -p output plus accidental quotes, PEM wrappers,
and whitespace. Rejects anything that is not a 32-byte seed/public key
(or 64-byte legacy private) after strict base64 decode.
"""

from __future__ import annotations

import argparse
import base64
import re
import sys
from pathlib import Path

_BEGIN = re.compile(r"-----BEGIN [^-]+-----")
_END = re.compile(r"-----END [^-]+-----")
_B64 = re.compile(r"[A-Za-z0-9+/]+=*\Z")


def normalize(raw: str) -> str:
    text = raw.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in {'"', "'"}:
        text = text[1:-1].strip()
    text = _BEGIN.sub("", text)
    text = _END.sub("", text)
    text = re.sub(r"\s+", "", text)
    if not _B64.fullmatch(text):
        raise ValueError(
            "is not base64 EdDSA. Use generate_keys -x / -p output; "
            "no quotes or PEM wrapper."
        )
    try:
        data = base64.b64decode(text, validate=True)
    except Exception as exc:
        raise ValueError("is not valid base64") from exc
    if len(data) not in (32, 64):
        raise ValueError(
            f"decoded to {len(data)} bytes; Sparkle EdDSA seed/public is "
            "32 bytes (or 64-byte legacy private)."
        )
    return text


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dest", help="output path for the one-line key")
    args = parser.parse_args(argv)
    try:
        normalized = normalize(sys.stdin.read())
    except ValueError as exc:
        print(f"Sparkle EdDSA key {exc}", file=sys.stderr)
        return 1
    Path(args.dest).write_text(normalized, encoding="ascii")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
