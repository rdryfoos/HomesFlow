#!/usr/bin/env python3
"""Patch HomeFlow Golden Thread Coverage canvas DATA from traceability JSON."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from datetime import date
from pathlib import Path


def git_short_sha(repo_root: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=repo_root,
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"


def format_data_block(records: list[dict]) -> str:
    lines = ["const DATA: CoverageRecord[] = ["]
    for index, record in enumerate(records):
        compact = json.dumps(record, separators=(",", ":"))
        suffix = "," if index < len(records) - 1 else ""
        lines.append(f"  {compact}{suffix}")
    lines.append("];")
    return "\n".join(lines)


def patch_canvas(canvas_path: Path, records: list[dict], repo_root: Path) -> None:
    text = canvas_path.read_text(encoding="utf-8")
    snapshot = f"// Snapshot: {date.today().isoformat()} · HomeFlow @ {git_short_sha(repo_root)}"
    text = re.sub(r"// Snapshot:.*", snapshot, text, count=1)
    data_block = format_data_block(records)
    text = re.sub(
        r"const DATA: CoverageRecord\[\] = \[.*?\n\];",
        data_block,
        text,
        count=1,
        flags=re.DOTALL,
    )
    canvas_path.write_text(text, encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: update-golden-thread-canvas.py <data.json> <canvas.tsx>", file=sys.stderr)
        sys.exit(1)

    json_path = Path(sys.argv[1])
    canvas_path = Path(sys.argv[2])
    repo_root = Path(__file__).resolve().parent.parent

    records = json.loads(json_path.read_text(encoding="utf-8"))
    if not canvas_path.is_file():
        print(f"Canvas not found: {canvas_path}", file=sys.stderr)
        sys.exit(1)

    patch_canvas(canvas_path, records, repo_root)
    verified = sum(1 for r in records if r.get("type") == "AC" and r.get("status") == "verified")
    total_acs = sum(1 for r in records if r.get("type") == "AC")
    print(f"Updated {canvas_path} ({verified}/{total_acs} ACs verified).")


if __name__ == "__main__":
    main()
