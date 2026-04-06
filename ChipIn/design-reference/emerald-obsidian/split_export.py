#!/usr/bin/env python3
"""Split combined Stitch paste (multiple <!-- ... --> + <!DOCTYPE html> docs) into numbered files."""
from __future__ import annotations

import re
import sys
from pathlib import Path

OUT_NAMES = [
    "01-home.html",
    "02-add-expense.html",
    "03-groups.html",
    "04-profile.html",
    "05-auth-login.html",
]


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 split_export.py stitch-full-export.html", file=sys.stderr)
        sys.exit(1)
    src = Path(sys.argv[1]).read_text(encoding="utf-8")
    parts = re.split(
        r"(?=<!--[^\n]+-->\s*\n<!DOCTYPE html)",
        src,
        flags=re.IGNORECASE | re.DOTALL,
    )
    parts = [p.strip() for p in parts if p.strip()]
    if not parts:
        print("No segments found.", file=sys.stderr)
        sys.exit(1)
    out_dir = Path(__file__).resolve().parent
    for i, name in enumerate(OUT_NAMES):
        if i < len(parts):
            out_dir.joinpath(name).write_text(parts[i] + "\n", encoding="utf-8")
            print("Wrote", name, f"({len(parts[i])} chars)")
    if len(parts) != len(OUT_NAMES):
        print(
            f"Note: found {len(parts)} segment(s), expected {len(OUT_NAMES)}. Check your paste.",
            file=sys.stderr,
        )


if __name__ == "__main__":
    main()
