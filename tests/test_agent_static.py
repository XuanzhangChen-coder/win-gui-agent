import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AGENT = ROOT / "agent" / "WinGuiAgent.ps1"


class AgentStaticTests(unittest.TestCase):
    def test_wait_window_handle_does_not_use_foreground_fallback(self):
        text = AGENT.read_text(encoding="utf-8")
        match = re.search(r"function Wait-WindowHandle \{(?P<body>.*?)\n\}", text, re.S)
        self.assertIsNotNone(match)
        body = match.group("body")
        self.assertNotIn("Resolve-WindowHandle", body)
        self.assertIn("Get-TopLevelWindows", body)


if __name__ == "__main__":
    unittest.main()
