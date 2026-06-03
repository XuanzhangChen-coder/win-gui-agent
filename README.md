# win-gui-agent

`win-gui-agent` is a Windows desktop automation agent designed for cases where a program has no useful CLI, API, or scripting interface. The agent runs inside the Windows interactive desktop session, captures screenshots from the same coordinate system it clicks in, and exposes a small remote API for observation, mouse actions, keyboard input, window inspection, and eventually OCR/UI Automation workflows.

The first milestone is intentionally small: prove a stable closed loop from Ubuntu to the Windows VM:

1. Capture a Windows-internal screenshot.
2. Click and type inside the same Windows coordinate system.
3. Capture another screenshot and verify the result.
4. Save logs and screenshots for every step.

## Why This Exists

Remote viewer coordinates are fragile. A screenshot captured outside a VM may not map cleanly to the click coordinates used by the viewer because of display scaling, DPI, window decorations, resizing, or SPICE/RDP/VNC behavior.

This project avoids that class of bugs by running the automation agent inside Windows:

```text
Ubuntu / Codex
  |
  | HTTP / SSH
  v
Windows GUI Agent
  |
  | screenshot, click, type, hotkey, UIA, OCR
  v
Target Windows GUI application
```

## Current Status

The PowerShell/.NET MVP can currently:

- run inside the Windows interactive desktop session through a scheduled task;
- capture Windows-internal screenshots;
- click, double-click, move the mouse, type text, send keys, and send hotkeys;
- start GUI programs;
- list, activate, maximize, and close top-level windows;
- read UI Automation trees;
- find UIA controls;
- click UIA controls;
- set text in a UIA text/document control;
- compare two screenshots with a lightweight sampled image-diff endpoint;
- run a JSON task file through `client/run_task.py`;
- evaluate action expectations with `/verify` and `/action`;
- write task run reports with retry and manual resume support;
- expose optional Tesseract-backed OCR endpoints when an OCR backend is installed;
- constrain OCR to screen regions and click a word by OCR-derived coordinates.
- run a real KiCad engineering project trial that opens schematic/PCB editors and verifies exported ERC/DRC/PDF/Gerber/Drill artifacts;
- run a real LTspice trial that handles first-run dialogs and opens an analog schematic project.

Validation notes:

- Phase 1-3: [docs/phase-1-3-validation.md](docs/phase-1-3-validation.md)
- Phase 4-5: [docs/phase-4-5-validation.md](docs/phase-4-5-validation.md)
- Phase 6: [docs/phase-6-vision-foundation.md](docs/phase-6-vision-foundation.md)
- Phase 7: [docs/phase-7-ocr.md](docs/phase-7-ocr.md)
- Phase 8-9: [docs/phase-8-9-verifier-task-dsl.md](docs/phase-8-9-verifier-task-dsl.md)
- Phase 10: [docs/phase-10-real-software-trials.md](docs/phase-10-real-software-trials.md)
- Phase 11: [docs/phase-11-unattended-smoke-suite.md](docs/phase-11-unattended-smoke-suite.md)
- Phase 12: [docs/phase-12-kicad-real-project.md](docs/phase-12-kicad-real-project.md)
- Phase 13: [docs/phase-13-ltspice-real-software.md](docs/phase-13-ltspice-real-software.md)

## Quickstart

On Windows:

```powershell
C:\GuiAgent\win-gui-agent\scripts\register-task.ps1
C:\GuiAgent\win-gui-agent\scripts\restart-agent.ps1
Invoke-RestMethod http://127.0.0.1:8765/health
```

From the client side:

```bash
client/wga.sh health
python3 client/run_task.py examples/notepad-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/notepad-task-report.json
```

After installing Tesseract OCR on Windows:

```bash
python3 client/run_task.py examples/notepad-ocr-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/notepad-ocr-task-report.json
```

Run the controlled Text Pad OCR fixture used by the unattended suite:

```bash
python3 client/run_task.py examples/text-pad-ocr-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/text-pad-ocr-task-report.json
```

Run a non-destructive Windows Settings demo:

```bash
python3 client/run_task.py examples/settings-about-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/settings-about-task-report.json
```

Run a local Edge browser demo:

```bash
python3 client/run_task.py examples/edge-browser-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/edge-browser-task-report.json
```

Run an installer-style wizard demo:

```bash
python3 client/run_task.py examples/installer-wizard-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/installer-wizard-task-report.json
```

Run a non-destructive Vivado engineering-software smoke:

```bash
python3 client/run_task.py examples/vivado-smoke-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/vivado-smoke-task-report.json
```

Run the KiCad real-project trial after KiCad is installed:

```bash
/home/xuan/VMs/bin/win11-ee-ssh-ps.sh \
  'C:\GuiAgent\win-gui-agent\examples\kicad-prepare-pic-programmer.ps1'

/home/xuan/VMs/bin/win11-ee-ssh-ps.sh \
  'C:\GuiAgent\win-gui-agent\examples\kicad-export-pic-programmer.ps1'

python3 client/run_task.py examples/kicad-pic-programmer-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/kicad-pic-programmer-task-report.json
```

Run the LTspice real-software trial after LTspice is installed:

```bash
python3 client/run_task.py examples/ltspice-lowpass-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/ltspice-lowpass-task-report.json
```

Run the short unattended smoke suite:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-report.json
```

For a longer unattended check, override the loop count without editing the suite:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-long-report.json \
  --duration-minutes 30 \
  --delay-ms 1000 \
  --quiet-tasks
```

Run the engineering-software suite:

```bash
python3 client/run_suite.py examples/engineering-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/engineering-suite-report.json \
  --quiet-tasks
```

Setup details: [docs/setup.md](docs/setup.md). API details: [docs/api.md](docs/api.md). Troubleshooting: [docs/troubleshooting.md](docs/troubleshooting.md).
Open-source checklist: [docs/open-source-checklist.md](docs/open-source-checklist.md). Release notes: [docs/release-notes-v0.1.0.md](docs/release-notes-v0.1.0.md). Contributing: [CONTRIBUTING.md](CONTRIBUTING.md). Security: [SECURITY.md](SECURITY.md). Changes: [CHANGELOG.md](CHANGELOG.md).

Create and validate a clean source export before publishing:

```bash
scripts/export_clean.py /tmp/win-gui-agent-clean
/tmp/win-gui-agent-clean/scripts/preflight.py /tmp/win-gui-agent-clean
```

## Roadmap

See [docs/roadmap.md](docs/roadmap.md).

## Safety Model

The agent is intended for a trusted local VM or LAN environment. The MVP binds to localhost by default on Windows. Do not expose it directly to untrusted networks.
