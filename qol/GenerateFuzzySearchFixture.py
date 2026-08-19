#!/usr/bin/env python3
"""Create a deterministic 10,000-entry fixture for fuzzy filename searches."""

import json
import random
from pathlib import Path

OUTPUT = Path(__file__).with_name("fuzzy-search-fixture-10000.json")
RANDOM = random.Random(20260814)
ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.$"

EXPECTED = {
    "plan": [
        ("plan-exact", "pLaN"),
        ("plan-edit-1", "pLoN"),
        ("plan-edit-2", "pLnA"),
        ("plan-edit-3", "pKaN"),
        ("plan-edit-4", "pLiN"),
        ("plan-edit-5", "pLaM"),
        ("plan-noise-1", "archive__pLoN__2026"),
        ("plan-noise-2", "x-pLnA-y"),
        ("plan-noise-3", "alpha_pKaN_beta"),
        ("plan-noise-4", "pre-pLiN-post"),
        ("plan-noise-5", "report.pLaM.final"),
    ],
    "myPhoto": [
        ("photo-exact", "mYpHoTo"),
        ("photo-edit-1", "mYqHoTo"),
        ("photo-edit-2", "mYpHoOt"),
        ("photo-edit-3", "mYpHoTe"),
        ("photo-edit-4", "mXpHoTo"),
        ("photo-edit-5", "mYpHoRo"),
        ("photo-noise-1", "archive__mYqHoTo__2026"),
        ("photo-noise-2", "x-mYpHoOt-y"),
        ("photo-noise-3", "alpha_mYpHoTe_beta"),
        ("photo-noise-4", "pre-mXpHoTo-post"),
        ("photo-noise-5", "report.mYpHoRo.final"),
    ],
}


def one_error(query: str, candidate: str) -> bool:
    if len(query) != len(candidate):
        return False
    mismatches = [i for i, (left, right) in enumerate(zip(query, candidate)) if left != right]
    if len(mismatches) == 1:
        return True
    return (
        len(mismatches) == 2
        and mismatches[1] == mismatches[0] + 1
        and query[mismatches[0]] == candidate[mismatches[1]]
        and query[mismatches[1]] == candidate[mismatches[0]]
    )


def matches(query: str, candidate: str) -> bool:
    query = query.lower()
    candidate = candidate.lower()
    if candidate == query or one_error(query, candidate):
        return True
    if len(candidate) == len(query) - 1:
        return any(query[:i] + query[i + 1:] == candidate for i in range(len(query)))
    if len(candidate) > len(query):
        for start in range(len(candidate) - len(query) + 1):
            window = candidate[start:start + len(query)]
            if window == query or one_error(query, window):
                return True
    return False


def record(identifier: str, stem: str) -> dict:
    file_name = f"{stem}.txt"
    return {
        "relativePath": f"fixture/{file_name}",
        "fileName": file_name,
        "fileExtension": "txt",
        "size": 0,
        "modifiedAt": "2026-08-14T00:00:00Z",
        "id": identifier,
    }


def main() -> None:
    files = [record(identifier, stem) for entries in EXPECTED.values() for identifier, stem in entries]
    used_file_names = {entry["fileName"].casefold() for entry in files}
    while len(files) < 10_000:
        stem = "".join(RANDOM.choice(ALPHABET) for _ in range(RANDOM.randint(3, 10)))
        file_name = f"{stem}.txt"
        if file_name.casefold() in used_file_names or any(matches(query, stem) for query in EXPECTED):
            continue
        files.append(record(f"random-{len(files):05d}", stem))
        used_file_names.add(file_name.casefold())

    payload = {
        "version": 1,
        "rootPath": "/fixture",
        "createdAt": "2026-08-14T00:00:00Z",
        "queries": [
            {"query": query, "expectedIds": [identifier for identifier, _ in entries]}
            for query, entries in EXPECTED.items()
        ],
        "files": files,
    }
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n")
    print(f"Wrote {len(files)} entries to {OUTPUT}")


if __name__ == "__main__":
    main()
