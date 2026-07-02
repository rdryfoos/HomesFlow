#!/usr/bin/env python3
"""Patch HomesFlow Golden Thread Coverage canvas DATA from traceability JSON."""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tempfile
from datetime import date
from pathlib import Path


def trusted_roots(repo_root: Path) -> list[Path]:
    """Directories that CLI paths may resolve under."""
    roots = [repo_root.resolve(), Path(tempfile.gettempdir()).resolve()]
    cursor_projects = (Path.home() / ".cursor" / "projects").resolve()
    if cursor_projects.is_dir():
        roots.append(cursor_projects)
    return roots


def resolve_trusted_path(
    raw_path: str,
    allowed_roots: list[Path],
    *,
    required_suffix: str,
) -> Path:
    """Resolve and confine a CLI path before any file system access."""
    candidate = Path(raw_path).expanduser()
    if not candidate.is_absolute():
        print(f"Refusing relative path: {raw_path}", file=sys.stderr)
        sys.exit(1)

    resolved = candidate.resolve(strict=False)
    if not str(resolved).endswith(required_suffix):
        print(
            f"Refusing path with unexpected suffix (expected *{required_suffix}): {resolved}",
            file=sys.stderr,
        )
        sys.exit(1)

    for root in allowed_roots:
        try:
            resolved.relative_to(root)
            return resolved
        except ValueError:
            continue

    allowed = ", ".join(str(root) for root in allowed_roots)
    print(
        f"Refusing path outside allowed directories: {resolved}\nAllowed roots: {allowed}",
        file=sys.stderr,
    )
    sys.exit(1)


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
    snapshot = f"// Snapshot: {date.today().isoformat()} · HomesFlow @ {git_short_sha(repo_root)}"
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

    repo_root = Path(__file__).resolve().parent.parent

    json_path = resolve_trusted_path(sys.argv[1], trusted_roots(repo_root), required_suffix=".json")
    canvas_path = resolve_trusted_path(
        sys.argv[2],
        trusted_roots(repo_root),
        required_suffix=".canvas.tsx",
    )

    if not json_path.is_file():
        print(f"JSON input not found: {json_path}", file=sys.stderr)
        sys.exit(1)
    if not canvas_path.is_file():
        print(f"Canvas not found: {canvas_path}", file=sys.stderr)
        sys.exit(1)

    records = json.loads(json_path.read_text(encoding="utf-8"))
    patch_canvas(canvas_path, records, repo_root)
    verified = sum(1 for r in records if r.get("type") == "AC" and r.get("status") == "verified")
    total_acs = sum(1 for r in records if r.get("type") == "AC")
    print(f"Updated {canvas_path} ({verified}/{total_acs} ACs verified).")


if __name__ == "__main__":
    main()
