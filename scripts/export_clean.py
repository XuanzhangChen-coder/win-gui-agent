#!/usr/bin/env python3
import argparse
import shutil
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
KEEP_DIRS = (".github", "agent", "client", "docs", "examples", "scripts", "tests")
KEEP_FILES = (".gitignore", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE", "README.md", "SECURITY.md")
EXCLUDE_DIRS = {"__pycache__", ".pytest_cache", ".venv", "runs"}
EXCLUDE_SUFFIXES = {".pyc", ".pyo", ".log", ".tmp"}


def should_skip(path: Path) -> bool:
    if any(part in EXCLUDE_DIRS for part in path.parts):
        return True
    if path.suffix in EXCLUDE_SUFFIXES:
        return True
    return False


def copy_tree(src: Path, dst: Path) -> None:
    for item in src.rglob("*"):
        rel = item.relative_to(src)
        if should_skip(rel):
            continue
        target = dst / rel
        if item.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(item, target)


def export_clean(destination: Path) -> None:
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)

    for filename in KEEP_FILES:
        shutil.copy2(ROOT / filename, destination / filename)

    for dirname in KEEP_DIRS:
        copy_tree(ROOT / dirname, destination / dirname)


def main() -> int:
    parser = argparse.ArgumentParser(description="Export a clean win-gui-agent source tree.")
    parser.add_argument(
        "destination",
        type=Path,
        nargs="?",
        default=Path("/tmp/win-gui-agent-clean"),
        help="destination directory, overwritten if it exists",
    )
    args = parser.parse_args()
    export_clean(args.destination)
    print(args.destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
