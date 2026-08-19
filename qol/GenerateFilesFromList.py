#!/usr/bin/env python3
"""Create every file listed in a JSON manifest with random printable content."""

from __future__ import annotations

import argparse
import base64
import json
import os
from pathlib import Path


def random_content(length: int) -> bytes:
    """Return exactly length bytes of printable ASCII data."""
    chunks: list[bytes] = []
    remaining = length
    while remaining:
        chunk = base64.b85encode(os.urandom(max(1, (remaining * 4 + 3) // 5)))
        chunks.append(chunk[:remaining])
        remaining -= len(chunks[-1])
    return b"".join(chunks)


def destination_for(target_root: Path, relative_path: str) -> Path:
    candidate = (target_root / relative_path).resolve()
    if candidate == target_root or target_root not in candidate.parents:
        raise ValueError(f"unsafe relativePath: {relative_path}")
    return candidate


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="JSON list containing a files array")
    parser.add_argument("target_root", type=Path, help="directory in which to create files")
    parser.add_argument(
        "--content-length",
        type=int,
        required=True,
        help="random content length in bytes for every file",
    )
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="replace files that already exist in the target directory",
    )
    args = parser.parse_args()

    if args.content_length < 0:
        parser.error("--content-length must be zero or greater")

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    entries = manifest.get("files")
    if not isinstance(entries, list):
        parser.error("manifest must contain a files array")

    target_root = args.target_root.resolve()
    destinations: list[Path] = []
    for entry in entries:
        if not isinstance(entry, dict) or not isinstance(entry.get("relativePath"), str):
            parser.error("each files entry must include a string relativePath")
        try:
            destinations.append(destination_for(target_root, entry["relativePath"]))
        except ValueError as error:
            parser.error(str(error))

    if len(set(destinations)) != len(destinations):
        parser.error("manifest contains duplicate relativePath values")
    if not args.overwrite:
        existing = next((path for path in destinations if path.exists()), None)
        if existing is not None:
            parser.error(f"refusing to overwrite existing file: {existing} (use --overwrite)")

    for destination in destinations:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(random_content(args.content_length))

    print(f"Created {len(destinations)} files under {target_root}")


if __name__ == "__main__":
    main()
