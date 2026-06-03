# Phase 11 Unattended Smoke Suite

Date: 2026-06-01

## Goal

Prove that separate GUI demos can be chained in one unattended run without manual cleanup between every application.

The suite started as a short MVP validation and now also has a passing 30-minute burn-in result.

## Suite

Suite file:

```text
examples/smoke-suite.json
```

Tasks:

1. `examples/text-pad-ocr-task.json`
2. `examples/settings-about-task.json`
3. `examples/edge-browser-task.json`
4. `examples/installer-wizard-task.json`
5. `examples/vivado-smoke-task.json`

Run command:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-report.json
```

Result:

```text
suite: wga-smoke-suite
loops: 1
tasks: 5
ok: true
```

## Two-Loop Reliability Check

After adding compact task output, the same suite was run for two consecutive loops:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-textpad-2loop-report.json \
  --loops 2 \
  --delay-ms 1000 \
  --quiet-tasks
```

Result:

```text
suite: wga-smoke-suite
loops: 2
tasks: 5
child task runs: 10
ok: true
startedAt: 2026-06-01T15:44:57.716962+00:00
endedAt: 2026-06-01T15:46:23.111449+00:00
```

Evidence:

```text
runs/smoke-suite-textpad-2loop-report.json
runs/smoke-suite-textpad-2loop-report-1-text-pad-ocr-task.json
runs/smoke-suite-textpad-2loop-report-1-settings-about-task.json
runs/smoke-suite-textpad-2loop-report-1-edge-browser-task.json
runs/smoke-suite-textpad-2loop-report-1-installer-wizard-task.json
runs/smoke-suite-textpad-2loop-report-1-vivado-smoke-task.json
runs/smoke-suite-textpad-2loop-report-2-text-pad-ocr-task.json
runs/smoke-suite-textpad-2loop-report-2-settings-about-task.json
runs/smoke-suite-textpad-2loop-report-2-edge-browser-task.json
runs/smoke-suite-textpad-2loop-report-2-installer-wizard-task.json
runs/smoke-suite-textpad-2loop-report-2-vivado-smoke-task.json
```

Validated chain:

- OCR text detection and clicking in the controlled Text Pad fixture.
- UIA wait/click/type flow in Windows Settings.
- OCR-driven browser interaction in Edge.
- UIA-driven installer-style wizard navigation.
- OCR verification on the real Vivado 2025.2 GUI.

Evidence:

```text
runs/smoke-suite-textpad-2loop-report.json
runs/smoke-suite-30min-textpad-report.json
```

## Longer Runs

The suite runner supports command-line overrides so longer checks do not require editing the JSON fixture:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-long-report.json \
  --duration-minutes 30 \
  --delay-ms 1000 \
  --quiet-tasks
```

`--quiet-tasks` keeps terminal output readable during long runs while preserving complete per-task reports on disk.
`--duration-minutes` makes the suite keep starting full loops until at least the requested duration has elapsed.

## First 30-Minute Burn-In Attempt

The first duration-based burn-in attempt stopped before the 30-minute target:

```text
report: runs/smoke-suite-30min-report.json
ok: false
durationSeconds: 589.053
completedTaskRuns: 71
failed: loop 15, notepad ocr, failedStep 5
```

The failing child report was:

```text
runs/smoke-suite-30min-report-15-notepad-ocr-task.json
```

Root cause:

- The failure was not OCR accuracy.
- The Notepad task opened successfully and activated a window titled `*line one - Notepad`.
- The following maximize step could not find a matching Notepad window.
- Repeated `Stop-Process notepad` plus Windows 11 Notepad session restore caused an old restored tab/title to leak into the test.

Fix:

- The Notepad examples now create and open fixed scratch files under `C:\GuiAgent\scratch`.
- The agent `run` action supports `waitForWindowTitleContains`, `waitTimeoutMs`, and `waitIntervalMs`.
- The Notepad tasks wait for the scratch filename in the window title before activating, maximizing, or using UIA.
- The agent window resolver now supports `classNameContains` and `includeUntitled`, and `Wait-WindowHandle` no longer falls back to the foreground window when no title match exists.
- The unattended suite now uses `examples/text-pad-ocr-task.json`, a controlled WinForms text fixture, for the repeated OCR/UIA baseline. The real Notepad OCR task remains as a separate real-application demo because modern Windows Notepad can leave UWP session-restore windows after repeated forced resets.

Regression after the fix:

```text
notepad fixed report: runs/notepad-ocr-task-fixed-report.json
two-loop suite report: runs/smoke-suite-fixed-2loop-report.json
two-loop suite ok: true
completedTaskRuns: 10
```

## Passing 30-Minute Burn-In

After moving the repeated OCR/UIA baseline to the controlled Text Pad fixture, the duration-based suite completed successfully:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-30min-textpad-report.json \
  --duration-minutes 30 \
  --delay-ms 1000 \
  --quiet-tasks
```

Result:

```text
report: runs/smoke-suite-30min-textpad-report.json
ok: true
startedAt: 2026-06-01T15:47:05.825240+00:00
endedAt: 2026-06-01T16:17:30.348973+00:00
durationSeconds: 1824.524
requestedDurationMinutes: 30.0
completedLoops: 43
completedTaskRuns: 215
tasksPerLoop: 5
```

Every child task report was successful:

```text
text pad ocr: 43
settings about: 43
edge browser: 43
installer wizard: 43
vivado smoke: 43
```

Evidence:

```text
runs/smoke-suite-30min-textpad-report.json
runs/smoke-suite-30min-textpad-report-*-text-pad-ocr-task.json
runs/smoke-suite-30min-textpad-report-*-settings-about-task.json
runs/smoke-suite-30min-textpad-report-*-edge-browser-task.json
runs/smoke-suite-30min-textpad-report-*-installer-wizard-task.json
runs/smoke-suite-30min-textpad-report-*-vivado-smoke-task.json
```
