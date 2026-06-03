import contextlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
RUN_TASK_PATH = ROOT / "client" / "run_task.py"
spec = importlib.util.spec_from_file_location("run_task", RUN_TASK_PATH)
run_task = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(run_task)


class RunStepTests(unittest.TestCase):
    def test_sleep_step(self):
        with mock.patch.object(run_task.time, "sleep") as sleep:
            result = run_task.run_step({"sleepMs": 250}, "http://agent")
        self.assertEqual(result, {"ok": True, "sleepMs": 250})
        sleep.assert_called_once_with(0.25)

    def test_verify_step_posts_expectation(self):
        with mock.patch.object(run_task, "post_json", return_value={"ok": True}) as post:
            result = run_task.run_step({"verify": {"activeWindowTitleContains": "Notepad"}}, "http://agent")
        self.assertEqual(result, {"ok": True})
        post.assert_called_once_with(
            "http://agent",
            "verify",
            {"expect": {"activeWindowTitleContains": "Notepad"}},
        )

    def test_wait_for_succeeds_after_retry(self):
        responses = [{"ok": False}, {"ok": True, "screen": {}}]
        with mock.patch.object(run_task, "post_json", side_effect=responses) as post:
            with mock.patch.object(run_task.time, "sleep") as sleep:
                with mock.patch.object(run_task.time, "monotonic", side_effect=[0.0, 0.1]):
                    result = run_task.run_step(
                        {
                            "waitFor": {"activeWindowTitleContains": "Settings"},
                            "timeoutMs": 5000,
                            "intervalMs": 100,
                        },
                        "http://agent",
                    )
        self.assertTrue(result["ok"])
        self.assertEqual(result["attempts"], 2)
        self.assertEqual(post.call_count, 2)
        sleep.assert_called_once_with(0.1)

    def test_wait_for_times_out(self):
        with mock.patch.object(run_task, "post_json", return_value={"ok": False}) as post:
            with mock.patch.object(run_task.time, "sleep") as sleep:
                with mock.patch.object(run_task.time, "monotonic", side_effect=[0.0, 0.2]):
                    result = run_task.run_step(
                        {
                            "waitFor": {"activeWindowTitleContains": "Missing"},
                            "timeoutMs": 100,
                            "intervalMs": 50,
                        },
                        "http://agent",
                    )
        self.assertFalse(result["ok"])
        self.assertEqual(result["error"], "timeout")
        self.assertEqual(post.call_count, 1)
        sleep.assert_not_called()

    def test_action_step_removes_runner_metadata(self):
        step = {
            "label": "click target",
            "retry": 2,
            "retryDelayMs": 100,
            "action": "click",
            "x": 10,
            "y": 20,
        }
        with mock.patch.object(run_task, "post_json", return_value={"ok": True}) as post:
            result = run_task.run_step(step, "http://agent")
        self.assertEqual(result, {"ok": True})
        post.assert_called_once_with(
            "http://agent",
            "action",
            {"action": "click", "x": 10, "y": 20},
        )


class RunTaskTests(unittest.TestCase):
    def test_quiet_output_prints_summary_and_writes_full_report(self):
        task = {"name": "quiet-demo", "steps": [{"sleepMs": 1}]}
        with tempfile.TemporaryDirectory() as tmp:
            report_path = Path(tmp) / "report.json"
            out = io.StringIO()
            with mock.patch.object(run_task.time, "sleep"):
                with contextlib.redirect_stdout(out):
                    rc = run_task.run_task(task, "http://agent", report_path=report_path, output="summary")
            report = json.loads(report_path.read_text(encoding="utf-8"))
        self.assertEqual(rc, 0)
        self.assertTrue(report["ok"])
        self.assertEqual(report["results"][0]["result"], {"ok": True, "sleepMs": 1})
        printed = json.loads(out.getvalue())
        self.assertEqual(printed["task"], "quiet-demo")
        self.assertEqual(printed["steps"], 1)
        self.assertEqual(printed["report"], str(report_path))

    def test_optional_failed_step_is_recorded_and_task_continues(self):
        task = {
            "name": "optional-demo",
            "steps": [
                {"action": "uia_click", "nameContains": "Maybe", "optional": True},
                {"sleepMs": 1},
            ],
        }
        with tempfile.TemporaryDirectory() as tmp:
            report_path = Path(tmp) / "report.json"
            with mock.patch.object(run_task, "get_json", return_value={"ok": True}):
                with mock.patch.object(run_task, "post_json", return_value={"ok": False, "error": "missing"}):
                    with mock.patch.object(run_task.time, "sleep"):
                        rc = run_task.run_task(task, "http://agent", report_path=report_path, output="silent")
            report = json.loads(report_path.read_text(encoding="utf-8"))
        self.assertEqual(rc, 0)
        self.assertTrue(report["ok"])
        self.assertFalse(report["results"][0]["ok"])
        self.assertTrue(report["results"][0]["optional"])
        self.assertTrue(report["results"][0]["skipped"])
        self.assertTrue(report["results"][1]["ok"])


if __name__ == "__main__":
    unittest.main()
