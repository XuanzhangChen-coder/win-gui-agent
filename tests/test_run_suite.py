import contextlib
import io
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "client"
if str(CLIENT) not in sys.path:
    sys.path.insert(0, str(CLIENT))
RUN_SUITE_PATH = ROOT / "client" / "run_suite.py"
spec = importlib.util.spec_from_file_location("run_suite", RUN_SUITE_PATH)
run_suite = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(run_suite)


class RunSuiteTests(unittest.TestCase):
    def test_run_suite_executes_all_tasks(self):
        suite = {
            "name": "suite",
            "loops": 2,
            "delayMs": 0,
            "tasks": [
                {"label": "a", "path": "a.json"},
                {"label": "b", "path": "b.json"},
            ],
        }
        with mock.patch.object(run_suite.run_task, "get_json", return_value={"ok": True}):
            with mock.patch.object(run_suite.run_task, "load_task", side_effect=lambda path: {"name": path.stem, "steps": []}):
                with mock.patch.object(run_suite.run_task, "run_task", return_value=0) as run_task_mock:
                    with contextlib.redirect_stdout(io.StringIO()):
                        rc = run_suite.run_suite(suite, "http://agent", task_output="summary")
        self.assertEqual(rc, 0)
        self.assertEqual(run_task_mock.call_count, 4)
        for call in run_task_mock.call_args_list:
            self.assertEqual(call.kwargs["output"], "summary")

    def test_run_suite_stops_on_failure(self):
        suite = {
            "name": "suite",
            "tasks": [
                {"label": "a", "path": "a.json"},
                {"label": "b", "path": "b.json"},
            ],
        }
        with mock.patch.object(run_suite.run_task, "get_json", return_value={"ok": True}):
            with mock.patch.object(run_suite.run_task, "load_task", return_value={"name": "task", "steps": []}):
                with mock.patch.object(run_suite.run_task, "run_task", side_effect=[0, 1]) as run_task_mock:
                    with contextlib.redirect_stdout(io.StringIO()):
                        rc = run_suite.run_suite(suite, "http://agent")
        self.assertEqual(rc, 1)
        self.assertEqual(run_task_mock.call_count, 2)

    def test_run_suite_duration_can_extend_past_requested_loops(self):
        suite = {
            "name": "suite",
            "loops": 1,
            "durationMinutes": 1,
            "tasks": [{"label": "a", "path": "a.json"}],
        }
        monotonic_values = [0, 0, 70, 70]
        with tempfile.TemporaryDirectory() as tmp:
            report_path = Path(tmp) / "suite-report.json"
            with mock.patch.object(run_suite.run_task, "get_json", return_value={"ok": True}):
                with mock.patch.object(run_suite.run_task, "load_task", return_value={"name": "task", "steps": []}):
                    with mock.patch.object(run_suite.run_task, "run_task", return_value=0) as run_task_mock:
                        with mock.patch.object(run_suite.time, "monotonic", side_effect=monotonic_values):
                            with contextlib.redirect_stdout(io.StringIO()):
                                rc = run_suite.run_suite(
                                    suite,
                                    "http://agent",
                                    report_path=report_path,
                                    task_output="summary",
                                )
            report = json.loads(report_path.read_text(encoding="utf-8"))
        self.assertEqual(rc, 0)
        self.assertEqual(run_task_mock.call_count, 2)
        self.assertEqual(report["requestedDurationMinutes"], 1)
        self.assertEqual(report["completedLoops"], 2)
        self.assertEqual(report["completedTaskRuns"], 2)

    def test_main_overrides_loops_and_delay(self):
        suite = {"name": "suite", "loops": 1, "delayMs": 0, "tasks": [{"path": "a.json"}]}
        with tempfile.TemporaryDirectory() as tmp:
            suite_path = Path(tmp) / "suite.json"
            suite_path.write_text(json.dumps(suite), encoding="utf-8")
            argv = [
                "run_suite.py",
                str(suite_path),
                "--base-url",
                "http://agent",
                "--loops",
                "3",
                "--delay-ms",
                "25",
                "--duration-minutes",
                "0.5",
                "--quiet-tasks",
            ]
            with mock.patch.object(sys, "argv", argv):
                with mock.patch.object(run_suite, "run_suite", return_value=0) as run_suite_mock:
                    rc = run_suite.main()
        self.assertEqual(rc, 0)
        loaded_suite = run_suite_mock.call_args.args[0]
        self.assertEqual(loaded_suite["loops"], 3)
        self.assertEqual(loaded_suite["delayMs"], 25)
        self.assertEqual(loaded_suite["durationMinutes"], 0.5)
        self.assertEqual(run_suite_mock.call_args.kwargs["task_output"], "summary")


if __name__ == "__main__":
    unittest.main()
