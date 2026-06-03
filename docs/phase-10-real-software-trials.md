# Phase 10 Real Software Trials

Date: 2026-06-01

## Goal

Move beyond toy Notepad-only automation and prove that the agent can operate a real Windows application through the same observe-act-verify loop.

## Trial 1: Windows Settings About Page

Task file:

```text
examples/settings-about-task.json
```

The task is intentionally non-destructive:

1. Reset any old Settings process.
2. Open `ms-settings:about`.
3. Wait for the Settings window title.
4. Verify the search box exists through UI Automation.
5. Verify the `系统信息` breadcrumb exists through UI Automation.
6. Focus the search box through UI Automation.
7. Type a harmless query, `display`.
8. Close Settings through the agent `close_window` action.

Run command:

```bash
python3 client/run_task.py examples/settings-about-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/settings-about-task-report.json
```

Result:

```text
task: settings-about-demo
steps: 9
ok: true
```

Validated primitives:

- launching a real Windows URI with `explorer.exe ms-settings:about`;
- active window title verification with localized title `设置`;
- UIA existence checks for real app controls;
- task-runner `waitFor` polling instead of fixed sleeps for window readiness;
- UIA click on the Settings search box;
- keyboard text input into a real system app;
- close-window action from the task DSL;
- before/after screenshots and JSON report for every action.

Evidence:

- `runs/settings-about-task-report.json`
- `/home/xuan/VMs/shared/wga-settings-about-open.png`
- `/home/xuan/VMs/shared/wga-settings-about-search.png`
- `/home/xuan/VMs/shared/wga-settings-about-final.png`
- `/home/xuan/VMs/shared/wga-settings-waitfor-open.png`
- `/home/xuan/VMs/shared/wga-settings-waitfor-search.png`
- `/home/xuan/VMs/shared/wga-settings-waitfor-final.png`

## Notes

This trial also validated that localized UI names are part of the automation contract. On this VM, Windows Settings exposes:

- window title: `设置`
- search box name: `搜索框，查找设置`
- about-page breadcrumb: `系统信息`

Future public examples should mention that localized Windows builds may require adapting visible names.

## Trial 2: Microsoft Edge Local Page

Task file:

```text
examples/edge-browser-task.json
```

Page fixture:

```text
examples/browser-trial.html
```

This trial avoids public internet dependency by opening a local HTML file in Microsoft Edge:

1. Reset old Edge processes.
2. Open `browser-trial.html` with a dedicated Edge profile.
3. Wait for the browser title to contain `WGA Browser Trial`.
4. Verify page text with bounded OCR.
5. Click the page button by OCR text coordinates.
6. Verify the page changed to `Status: browser automation confirmed`.
7. Close Edge through the `close_window` action.

Run command:

```bash
python3 client/run_task.py examples/edge-browser-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/edge-browser-task-report.json
```

Result:

```text
task: edge-browser-demo
steps: 7
ok: true
```

Validated primitives:

- launching a real browser from the task DSL;
- controlling a local web page without a browser extension or web driver;
- using OCR to find text inside web content that was not exposed as a useful UIA button;
- clicking the OCR-derived center of `Confirm`;
- verifying state change by both title and OCR text;
- keeping the trial independent of public network availability.

Evidence:

- `runs/edge-browser-task-report.json`
- `/home/xuan/VMs/shared/wga-edge-browser-open.png`
- `/home/xuan/VMs/shared/wga-edge-browser-clicked.png`
- `/home/xuan/VMs/shared/wga-edge-browser-final.png`

## Trial 3: Installer-Style Wizard

Task file:

```text
examples/installer-wizard-task.json
```

Wizard fixture:

```text
examples/installer-wizard.ps1
```

This trial uses a local Windows Forms wizard to simulate a real installer without changing system software:

1. Reset old wizard processes and remove the previous trial install directory.
2. Open `WGA Trial Installer`.
3. Wait for the welcome page.
4. Click `Next`.
5. Accept the license terms.
6. Click `Next` to reach the install-location page.
7. Click `Install`.
8. Wait for the `Finish` control.
9. Verify `C:\GuiAgent\trial-install\installed.txt` contains completion text.
10. Click `Finish`.

Run command:

```bash
python3 client/run_task.py examples/installer-wizard-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/installer-wizard-task-report.json
```

Result:

```text
task: installer-wizard-demo
steps: 10
ok: true
```

Validated primitives:

- multi-page installer-style navigation;
- license checkbox handling;
- waiting for a completion page;
- exact UIA name matching;
- filtering UIA candidates by enabled state;
- tolerant UIA click fallback when `SetFocus()` fails on pane-like WinForms controls;
- file-system verification after GUI completion.

Evidence:

- `runs/installer-wizard-task-report.json`
- `/home/xuan/VMs/shared/wga-installer-welcome.png`
- `/home/xuan/VMs/shared/wga-installer-license-accepted.png`
- `/home/xuan/VMs/shared/wga-installer-complete.png`
- `/home/xuan/VMs/shared/wga-installer-installed.txt`

## Trial 4: Vivado Engineering Software Smoke

Task file:

```text
examples/vivado-smoke-task.json
```

This trial is deliberately read-only. It does not create, open, or modify a Vivado project. It only proves that the agent can foreground a heavyweight engineering GUI and verify visible state.

The task:

1. Activates the existing `Vivado 2025.2` window.
2. Maximizes it.
3. Waits for Vivado to be the foreground window.
4. Uses bounded OCR to verify top chrome text such as `Vivado`.
5. Uses bounded OCR to verify the `Quick Start` area.
6. Uses bounded OCR to verify `Create Project`.

Run command:

```bash
python3 client/run_task.py examples/vivado-smoke-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/vivado-smoke-task-report.json
```

Result:

```text
task: vivado-smoke-demo
steps: 6
ok: true
```

Validated primitives:

- foregrounding a Java/AWT engineering application;
- stronger window activation through native Windows foreground handling;
- OCR verification on a complex real application;
- non-destructive engineering-software smoke testing.

Evidence:

- `runs/vivado-smoke-task-report.json`
- `/home/xuan/VMs/shared/wga-vivado-smoke-foreground.png`
- `/home/xuan/VMs/shared/wga-vivado-smoke-top-ocr.png`
- `/home/xuan/VMs/shared/wga-vivado-smoke-quickstart-ocr.png`

## Remaining Trials

The first engineering-software smoke is done. A later, riskier phase can open a disposable project and verify project navigation.
