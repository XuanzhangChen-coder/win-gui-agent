#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


FORBIDDEN_DIRS = {"runs", "__pycache__", ".pytest_cache", ".venv"}
FORBIDDEN_SUFFIXES = {".pyc", ".pyo", ".log", ".tmp"}


def fail(message: str) -> None:
    raise SystemExit(message)


def check_forbidden_files(root: Path) -> None:
    bad = []
    for path in root.rglob("*"):
        rel = path.relative_to(root)
        if any(part in FORBIDDEN_DIRS for part in rel.parts):
            bad.append(str(rel))
        elif path.suffix in FORBIDDEN_SUFFIXES:
            bad.append(str(rel))
    if bad:
        shown = "\n".join(bad[:40])
        more = "" if len(bad) <= 40 else f"\n... and {len(bad) - 40} more"
        fail(f"forbidden generated files found:\n{shown}{more}")


def check_json_examples(root: Path) -> None:
    for path in sorted((root / "examples").glob("*.json")):
        json.loads(path.read_text(encoding="utf-8"))


def run_tests(root: Path) -> None:
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    subprocess.run(
        [sys.executable, "-m", "pytest", str(root / "tests"), "-q", "-p", "no:cacheprovider"],
        cwd=root,
        env=env,
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run win-gui-agent source preflight checks.")
    parser.add_argument("root", type=Path, nargs="?", default=Path.cwd())
    parser.add_argument("--skip-tests", action="store_true")
    args = parser.parse_args()

    root = args.root.resolve()
    check_forbidden_files(root)
    check_json_examples(root)
    if not args.skip_tests:
        run_tests(root)
        check_forbidden_files(root)
    print("preflight ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
