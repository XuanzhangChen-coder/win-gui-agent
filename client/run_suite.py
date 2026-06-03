#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import sys
import time
from pathlib import Path

import run_task


def load_suite(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def run_suite(
    suite: dict,
    base_url: str,
    report_path: Path | None = None,
    task_output: str = "full",
) -> int:
    if task_output not in {"full", "summary", "silent"}:
        raise ValueError("task_output must be one of: full, summary, silent")
    name = suite.get("name", "unnamed-suite")
    tasks = suite.get("tasks", [])
    loops = int(suite.get("loops", 1))
    delay_ms = int(suite.get("delayMs", 0))
    duration_minutes = suite.get("durationMinutes")
    duration_seconds = None
    if duration_minutes is not None:
        duration_seconds = float(duration_minutes) * 60
    if not isinstance(tasks, list) or not tasks:
        raise SystemExit("Suite field 'tasks' must be a non-empty list")
    if loops < 1:
        raise SystemExit("Suite field 'loops' must be at least 1")
    if duration_seconds is not None and duration_seconds <= 0:
        raise SystemExit("Suite field 'durationMinutes' must be positive")

    started_at = dt.datetime.now(dt.timezone.utc).isoformat()
    start_monotonic = time.monotonic()
    results = []
    print(f"suite: {name}", flush=True)
    print(json.dumps(run_task.get_json(base_url, "health"), ensure_ascii=False), flush=True)

    base_dir = Path.cwd()
    loop_index = 1
    while loop_index <= loops or (
        duration_seconds is not None and time.monotonic() - start_monotonic < duration_seconds
    ):
        for task_entry in tasks:
            task_path = Path(task_entry["path"])
            if not task_path.is_absolute():
                task_path = base_dir / task_path
            task = run_task.load_task(task_path)
            label = task_entry.get("label", task.get("name", task_path.stem))
            loop_display = f"{loop_index}/{loops}" if loop_index <= loops else f"{loop_index}/duration"
            print(f"[loop {loop_display}] {label}", flush=True)
            task_report_path = None
            if report_path:
                task_report_path = report_path.parent / f"{report_path.stem}-{loop_index}-{task_path.stem}.json"
            rc = run_task.run_task(task, base_url, report_path=task_report_path, output=task_output)
            task_result = {
                "loop": loop_index,
                "label": label,
                "path": str(task_path),
                "ok": rc == 0,
                "report": str(task_report_path) if task_report_path else None,
            }
            results.append(task_result)
            if rc != 0:
                suite_report = {
                    "ok": False,
                    "suite": name,
                    "startedAt": started_at,
                    "endedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
                    "durationSeconds": round(time.monotonic() - start_monotonic, 3),
                    "requestedLoops": loops,
                    "requestedDurationMinutes": duration_minutes,
                    "completedTaskRuns": len(results),
                    "failed": task_result,
                    "results": results,
                }
                if report_path:
                    report_path.parent.mkdir(parents=True, exist_ok=True)
                    report_path.write_text(json.dumps(suite_report, ensure_ascii=False, indent=2), encoding="utf-8")
                print(json.dumps(suite_report, ensure_ascii=False, indent=2), flush=True)
                return 1
            if delay_ms > 0:
                time.sleep(delay_ms / 1000)
        loop_index += 1

    ended_at = dt.datetime.now(dt.timezone.utc).isoformat()
    suite_report = {
        "ok": True,
        "suite": name,
        "startedAt": started_at,
        "endedAt": ended_at,
        "durationSeconds": round(time.monotonic() - start_monotonic, 3),
        "requestedLoops": loops,
        "requestedDurationMinutes": duration_minutes,
        "completedLoops": loop_index - 1,
        "completedTaskRuns": len(results),
        "loops": loops,
        "tasks": len(tasks),
        "results": results,
    }
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(suite_report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(suite_report, ensure_ascii=False, indent=2), flush=True)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a win-gui-agent task suite.")
    parser.add_argument("suite", type=Path)
    parser.add_argument("--base-url", default="http://127.0.0.1:8765")
    parser.add_argument("--report", type=Path, help="write a JSON suite report")
    parser.add_argument("--loops", type=int, help="override suite loops")
    parser.add_argument("--delay-ms", type=int, help="override delayMs between tasks")
    parser.add_argument("--duration-minutes", type=float, help="run until at least this many minutes have elapsed")
    parser.add_argument("--quiet-tasks", action="store_true", help="print compact child-task summaries")
    args = parser.parse_args()
    suite = load_suite(args.suite)
    if args.loops is not None:
        suite["loops"] = args.loops
    if args.delay_ms is not None:
        suite["delayMs"] = args.delay_ms
    if args.duration_minutes is not None:
        suite["durationMinutes"] = args.duration_minutes
    task_output = "summary" if args.quiet_tasks else "full"
    return run_suite(suite, args.base_url, report_path=args.report, task_output=task_output)


if __name__ == "__main__":
    sys.exit(main())
