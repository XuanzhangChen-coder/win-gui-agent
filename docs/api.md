# API Reference

The agent listens on `http://127.0.0.1:8765` by default.

## Observation

```text
GET /health
GET /screen
GET /screenshot
GET /windows
GET /active_window
```

## Input

```text
POST /click
POST /double_click
POST /move
POST /type
POST /text
POST /key
POST /hotkey
POST /run
```

## Windows

```text
POST /activate_window
POST /maximize_window
POST /close_window
```

## UI Automation

```text
POST /uia/tree
POST /uia/find
POST /uia/click
POST /uia/set_text
```

## Vision And OCR

```text
POST /vision/diff
POST /vision/find_image
POST /vision/click_image
POST /ocr
POST /ocr/find_text
POST /ocr/click_text
```

OCR body fields:

```json
{
  "image": "C:\\path\\to\\screenshot.png",
  "text": "Next",
  "language": "eng",
  "psm": 6,
  "minConfidence": 40,
  "left": 0,
  "top": 70,
  "right": 320,
  "bottom": 135
}
```

For `/ocr`, `text` and `minConfidence` are ignored. For `/ocr/find_text`, `minConfidence` is ignored. For `/ocr/click_text`, `text` is required.

## Verifier And Actions

```text
POST /verify
POST /action
```

`/action` accepts an action body, captures before/after screenshots, runs the action, and evaluates `expect` when present.

Supported action names:

```text
run
click
type
key
hotkey
activate_window
maximize_window
close_window
uia_click
uia_set_text
ocr_click_text
```

Window-targeting actions accept these selectors:

```json
{
  "titleContains": "WGA Text Pad",
  "classNameContains": "WindowsForms10.EDIT",
  "includeUntitled": false
}
```

`run` actions can wait for a GUI window after process launch:

```json
{
  "action": "run",
  "file": "powershell.exe",
  "arguments": "-File C:\\GuiAgent\\win-gui-agent\\examples\\text-pad.ps1",
  "waitForWindowTitleContains": "WGA Text Pad",
  "waitForWindowClassNameContains": "WindowsForms10.Window",
  "waitIncludeUntitled": false,
  "waitTimeoutMs": 10000,
  "waitIntervalMs": 250
}
```

UIA queries support exact selectors and contains-style filters:

```json
{
  "windowTitleContains": "WGA Text Pad",
  "controlType": "Edit",
  "nameContains": "Search",
  "classNameContains": "WindowsForms10.EDIT",
  "includeOffscreen": false,
  "isEnabled": true,
  "limit": 1
}
```

Example:

```json
{
  "action": "uia_set_text",
  "windowTitleContains": "Notepad",
  "controlType": "Document",
  "text": "hello",
  "expect": {
    "activeWindowTitleContains": "Notepad"
  }
}
```

Supported expectations:

```text
activeWindowTitleContains
uiaExists
diff
ocrTextContains
fileExists
fileTextContains
```

Task files can also poll an expectation until it becomes true:

```json
{
  "label": "wait for settings window",
  "timeoutMs": 10000,
  "intervalMs": 500,
  "waitFor": {
    "activeWindowTitleContains": "设置"
  }
}
```

Task steps can be marked optional. Optional steps still run and are recorded in the report, but a failed optional step is marked `skipped` and does not fail the task. This is useful for transient recovery actions such as dismissing a modal dialog that may or may not be present:

```json
{
  "label": "dismiss warning if present",
  "action": "uia_click",
  "windowTitleContains": "Warning",
  "nameContains": "Continue",
  "optional": true
}
```

## Task And Suite Runners

Run a task with compact terminal output while still writing the full JSON report:

```bash
python3 client/run_task.py examples/notepad-ocr-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/notepad-ocr-task-report.json \
  --quiet
```

Run a suite with compact child-task output:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-report.json \
  --quiet-tasks
```

For unattended reliability checks, suite loop count, minimum duration, and delay can be overridden from the command line:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-long-report.json \
  --duration-minutes 30 \
  --delay-ms 1000 \
  --quiet-tasks
```

The suite report records `durationSeconds`, `requestedDurationMinutes`, `completedLoops`, and `completedTaskRuns`.
