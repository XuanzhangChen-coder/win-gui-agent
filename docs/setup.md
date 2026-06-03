# Setup

This project has two sides:

- Windows runs the desktop agent.
- Ubuntu, macOS, or another client machine calls the agent HTTP API.

The current reference setup is a trusted Windows 11 VM controlled from Ubuntu.

## Windows Requirements

- Windows 10 or Windows 11.
- PowerShell 5.1.
- .NET assemblies available with Windows: `System.Drawing`, `System.Windows.Forms`, and UI Automation.
- An interactive user session. The agent must run in the same desktop session as the target GUI apps.
- Optional: Tesseract OCR for `/ocr` endpoints.

Install Tesseract with `winget`:

```powershell
winget install --id tesseract-ocr.tesseract --source winget --accept-package-agreements --accept-source-agreements
```

## Install Agent

Copy this repository to:

```text
C:\GuiAgent\win-gui-agent
```

Register the scheduled task:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
C:\GuiAgent\win-gui-agent\scripts\register-task.ps1
```

Start or restart the agent:

```powershell
C:\GuiAgent\win-gui-agent\scripts\restart-agent.ps1
```

Check health:

```powershell
Invoke-RestMethod http://127.0.0.1:8765/health
```

The agent binds to `127.0.0.1` by default.

## Client Smoke Test

From a machine that can reach the agent:

```bash
client/wga.sh health
client/wga.sh screen
client/wga.sh screenshot
```

Run the Notepad task:

```bash
python3 client/run_task.py examples/notepad-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/notepad-task-report.json
```

Run the OCR task after Tesseract is installed:

```bash
python3 client/run_task.py examples/notepad-ocr-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/notepad-ocr-task-report.json
```

Run the controlled Text Pad OCR task used by the unattended reliability suite:

```bash
python3 client/run_task.py examples/text-pad-ocr-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/text-pad-ocr-task-report.json
```

Run the multi-application suite:

```bash
python3 client/run_suite.py examples/smoke-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/smoke-suite-report.json \
  --quiet-tasks
```

## Security

Treat the agent like local desktop control. Do not expose it to untrusted networks. Use SSH tunnels, firewall rules, or VM-only networking when controlling it remotely.
