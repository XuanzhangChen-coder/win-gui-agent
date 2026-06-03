#!/usr/bin/env python3
import argparse
import datetime as dt
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


def load_task(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    if path.suffix.lower() == ".json":
        return json.loads(text)
    try:
        import yaml  # type: ignore
    except Exception as exc:
        raise SystemExit(
            f"{path} is not JSON and PyYAML is not installed. "
            "Install PyYAML or use a .json task file."
        ) from exc
    return yaml.safe_load(text)


def post_json(base_url: str, endpoint: str, body: dict) -> dict:
    data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/{endpoint.lstrip('/')}",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {exc.code} from {endpoint}: {detail}") from exc


def get_json(base_url: str, endpoint: str) -> dict:
    with urllib.request.urlopen(f"{base_url.rstrip('/')}/{endpoint.lstrip('/')}", timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def run_step(step: dict, base_url: str) -> dict:
    if "sleepMs" in step:
        time.sleep(float(step["sleepMs"]) / 1000)
        return {"ok": True, "sleepMs": step["sleepMs"]}
    if "waitFor" in step:
        return wait_for_condition(step, base_url)
    if "verify" in step:
        return post_json(base_url, "verify", {"expect": step["verify"]})
    action_body = dict(step)
    action_body.pop("label", None)
    action_body.pop("retry", None)
    action_body.pop("retryDelayMs", None)
    action_body.pop("optional", None)
    return post_json(base_url, "action", action_body)


def wait_for_condition(step: dict, base_url: str) -> dict:
    expect = step["waitFor"]
    timeout_ms = int(step.get("timeoutMs", 10000))
    interval_ms = int(step.get("intervalMs", 500))
    if timeout_ms < 0:
        raise ValueError("timeoutMs must be non-negative")
    if interval_ms <= 0:
        raise ValueError("intervalMs must be positive")

    deadline = time.monotonic() + (timeout_ms / 1000)
    attempts = 0
    last_result = {"ok": False, "error": "not run"}
    while True:
        attempts += 1
        try:
            last_result = post_json(base_url, "verify", {"expect": expect})
        except Exception as exc:
            last_result = {"ok": False, "error": str(exc)}
        if last_result.get("ok", False):
            return {
                "ok": True,
                "attempts": attempts,
                "waitFor": expect,
                "result": last_result,
            }
        if time.monotonic() >= deadline:
            return {
                "ok": False,
                "attempts": attempts,
                "waitFor": expect,
                "lastResult": last_result,
                "error": "timeout",
                "timeoutMs": timeout_ms,
            }
        time.sleep(interval_ms / 1000)


def print_report(report: dict, report_path: Path | None, output: str) -> None:
    if output == "full":
        print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
        return
    if output == "summary":
        summary = {
            "ok": report.get("ok", False),
            "task": report.get("task"),
            "steps": report.get("steps", len(report.get("results", []))),
            "failedStep": report.get("failedStep"),
            "report": str(report_path) if report_path else None,
        }
        print(json.dumps(summary, ensure_ascii=False), flush=True)


def run_task(
    task: dict,
    base_url: str,
    start_at: int = 1,
    report_path: Path | None = None,
    output: str = "full",
) -> int:
    if output not in {"full", "summary", "silent"}:
        raise ValueError("output must be one of: full, summary, silent")
    name = task.get("name", "unnamed-task")
    steps = task.get("steps", [])
    if not isinstance(steps, list):
        raise SystemExit("Task field 'steps' must be a list")

    started_at = dt.datetime.now(dt.timezone.utc).isoformat()
    if output == "full":
        print(f"task: {name}")
        print(json.dumps(get_json(base_url, "health"), ensure_ascii=False))

    results = []
    for index, step in enumerate(steps, start=1):
        if index < start_at:
            continue
        label = step.get("label", f"step-{index}")
        if output == "full":
            print(f"[{index}/{len(steps)}] {label}")
        retry = int(step.get("retry", task.get("retry", 0)))
        attempt_results = []
        result = {"ok": False, "error": "not run"}
        for attempt in range(1, retry + 2):
            try:
                result = run_step(step, base_url)
            except Exception as exc:
                result = {"ok": False, "error": str(exc)}
            attempt_results.append(result)
            if output == "full":
                print(json.dumps({"ok": result.get("ok"), "label": label, "attempt": attempt}, ensure_ascii=False))
            if result.get("ok", False):
                break
            if attempt <= retry:
                time.sleep(float(step.get("retryDelayMs", task.get("retryDelayMs", 500))) / 1000)

        step_record = {
            "index": index,
            "label": label,
            "ok": result.get("ok", False),
            "optional": bool(step.get("optional", False)),
            "attempts": len(attempt_results),
            "result": result,
        }
        results.append(step_record)
        if not result.get("ok", False):
            if step_record["optional"]:
                step_record["skipped"] = True
                if output == "full":
                    print(json.dumps({"ok": True, "label": label, "optional": True, "skipped": True}, ensure_ascii=False))
                continue
            report = {
                "ok": False,
                "task": name,
                "startedAt": started_at,
                "endedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
                "failedStep": index,
                "results": results,
            }
            if report_path:
                report_path.parent.mkdir(parents=True, exist_ok=True)
                report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
            print_report(report, report_path, output)
            return 1

    report = {
        "ok": True,
        "task": name,
        "startedAt": started_at,
        "endedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "steps": len(steps),
        "ranFromStep": start_at,
        "results": results,
    }
    if report_path:
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print_report(report, report_path, output)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Run a win-gui-agent task file.")
    parser.add_argument("task", type=Path)
    parser.add_argument("--base-url", default="http://127.0.0.1:8765")
    parser.add_argument("--start-at", type=int, default=1, help="1-based step index to start from")
    parser.add_argument("--report", type=Path, help="write a JSON run report")
    parser.add_argument("--quiet", action="store_true", help="print only a compact summary")
    args = parser.parse_args()
    task = load_task(args.task)
    output = "summary" if args.quiet else "full"
    return run_task(task, args.base_url, start_at=args.start_at, report_path=args.report, output=output)


if __name__ == "__main__":
    sys.exit(main())
