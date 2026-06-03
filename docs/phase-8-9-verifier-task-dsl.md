# Phase 8-9 Verifier And Task DSL

Date: 2026-06-01

## Implemented

Verifier endpoint:

```text
POST /verify
```

Action endpoint:

```text
POST /action
```

The `/action` endpoint performs one action, captures before/after screenshots, then evaluates an optional expectation.

Supported expectations in this first pass:

- `activeWindowTitleContains`
- `uiaExists`
- `diff`
- `ocrTextContains`
- `fileExists`
- `fileTextContains`

Task runner:

```text
client/run_task.py
```

Runner capabilities in this pass:

- sequential step execution;
- `waitFor` polling for verifier conditions;
- `retry` and `retryDelayMs`;
- `--start-at` for manual resume from a step index;
- `--report` for persistent JSON run reports;
- stop-on-failure with structured evidence from the failing step.

Task example:

```text
examples/notepad-task.json
```

## Validation

Passed.

### Input Hardening

Validation script:

```powershell
C:\GuiAgent\win-gui-agent\scripts\demo-input-hardening.ps1
```

Result:

- Input string `line one\nline two\twith tab` was normalized before paste.
- Screenshot shows two visible lines in Notepad.
- Evidence: `/home/xuan/VMs/shared/wga-demo-input-hardening.png`

### Verifier Endpoint

`/verify` now returns structured expectation results instead of throwing or crashing the agent.

Example expectation:

```json
{
  "expect": {
    "activeWindowTitleContains": "Notepad"
  }
}
```

Example result when Notepad is not active:

```json
{
  "ok": false,
  "expectation": {
    "ok": false,
    "checks": [
      {
        "type": "activeWindowTitleContains",
        "ok": false
      }
    ]
  }
}
```

### Action Endpoint

`/action` performs an action, stores before/after screenshots, then evaluates expectations.

Validated actions:

- `run`
- `type`
- `maximize_window`
- `close_window`
- `uia_click`
- `uia_set_text`
- `ocr_click_text`

Validated expectations:

- `activeWindowTitleContains`
- `uiaExists`
- `diff`
- `ocrTextContains`
- `fileTextContains`

The `diff` expectation was validated by typing visible text and checking that before/after screenshots changed.

The `ocrTextContains` expectation was validated after the Phase 7 OCR pass using a constrained Notepad text region. It should be used with `left/top/right/bottom` bounds whenever possible.

### Task DSL

Runner:

```bash
python3 client/run_task.py examples/notepad-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/notepad-task-report.json
```

Validation task:

```text
examples/notepad-task.json
```

Steps:

1. Open Notepad.
2. Maximize Notepad.
3. Write two lines via UI Automation.
4. Verify Notepad is still active.

Result:

```json
{
  "ok": true,
  "task": "notepad-task-demo",
  "steps": 4
}
```

OCR task result:

```json
{
  "ok": true,
  "task": "notepad-ocr-demo",
  "steps": 7
}
```

Report:

```text
runs/notepad-ocr-task-report.json
```

Final screenshot:

- `/home/xuan/VMs/shared/wga-task-dsl-final.png`

Visible text:

```text
task dsl line one
task dsl line two
```

## Issues Found And Fixed

- The first verifier implementation used a generic .NET list and mutating PSCustomObject nested fields, which produced PowerShell 5.1 `parameter type mismatch` errors and caused the agent process to exit. The verifier now uses plain PowerShell arrays and constructs replacement expectation objects instead of mutating nested JSON objects directly.
- Agent error logging now records invocation position and script stack trace, so future runtime failures expose line-level evidence in `agent.log`.

## Current Limitation

The task runner currently supports JSON out of the box. YAML is supported only when `PyYAML` is installed. A later packaging pass should either vendor a tiny YAML parser, make `PyYAML` an explicit optional dependency, or keep JSON as the stable base format.

Automatic resume is not implemented yet. `--start-at` supports manual resume from a known step index.
