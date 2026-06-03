# Phase 12 KiCad Real Project Trial

Date: 2026-06-03

## Goal

Validate that the Windows-internal GUI agent can operate a real engineering GUI application, not just a small fixture. This trial uses KiCad 10.0.3 with the official `pic_programmer` demo project.

## Installed Software

- KiCad 10.0.3
  - Installer: `C:\Users\xuan\Downloads\kicad-10.0.3-x86_64.exe`
  - Install path: `C:\Program Files\KiCad\10.0`
  - Version check: `kicad-cli.exe version` returns `10.0.3`
- LTspice 26.0.2.1
  - Installer: `C:\Users\xuan\Downloads\LTspice64.msi`
  - Silent install command: `msiexec /i LTspice64.msi /qn /norestart /L*v C:\Tools\logs\ltspice-install-20260603.log`
  - Real-software GUI validation: [phase 13](phase-13-ltspice-real-software.md)

## Important Agent Changes

The KiCad installer and first-run configuration exposed two important reliability requirements:

1. The scheduled task must run with `RunLevel Highest`. Otherwise a limited agent cannot reliably click elevated installer windows after UAC approval.
2. Keyboard actions need a native fallback. `System.Windows.Forms.SendKeys` can fail with access denied in elevated or wxWidgets windows, so the agent now uses native virtual-key input with a `keybd_event` fallback.

The agent also gained a `windowExists` verifier so tasks can distinguish "the window exists" from "the window is foreground".

## Project Setup

The trial copies an official KiCad demo into a writable project directory:

```powershell
C:\GuiAgent\win-gui-agent\examples\kicad-prepare-pic-programmer.ps1
```

## CLI Baseline

The CLI baseline checks and exports real project artifacts:

```bash
/home/xuan/VMs/bin/win11-ee-ssh-ps.sh \
  'C:\GuiAgent\win-gui-agent\examples\kicad-export-pic-programmer.ps1'
```

Result:

- ERC: `0` violations
- DRC: `0` violations
- Schematic PDF: `C:\EE-Projects\wga-kicad-demo\outputs\schematic.pdf`
- Gerbers: `C:\EE-Projects\wga-kicad-demo\outputs\gerbers\`
- Drill: `C:\EE-Projects\wga-kicad-demo\outputs\drill\`
- Repeatability check: after resetting open KiCad processes and recopying the demo project, the export script completed successfully again on 2026-06-03.

## GUI Trial

Task file:

```text
examples/kicad-pic-programmer-task.json
```

Suite file:

```text
examples/engineering-suite.json
```

Run command:

```bash
python3 client/run_task.py examples/kicad-pic-programmer-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/kicad-pic-programmer-task-report.json
```

Suite command:

```bash
python3 client/run_suite.py examples/engineering-suite.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/engineering-suite-report.json \
  --quiet-tasks
```

Validated GUI behavior:

- Opened `pic_programmer.kicad_pro` in KiCad.
- Verified the KiCad project-manager window by title and UIA tree.
- Verified the project manager exposes `原理图编辑器` and `PCB 编辑器`.
- Opened the schematic editor and PCB editor.
- Activated the PCB editor and captured evidence screenshots.
- Verified exported report/manufacturing artifacts exist.
- Repeated the engineering suite for 3 loops after adding recovery for KiCad's file-open warning. Result: `ok`, `completedTaskRuns: 3`, `durationSeconds: 29.383`.

Evidence screenshots copied to the shared folder:

- `/home/xuan/VMs/shared/wga-kicad-project.png`
- `/home/xuan/VMs/shared/wga-kicad-schematic.png`
- `/home/xuan/VMs/shared/wga-kicad-pcb.png`

Evidence reports:

- `runs/kicad-pic-programmer-task-report-20260603.json`
- `runs/engineering-suite-report-20260603.json`
- `runs/engineering-suite-3loop-report-20260603-r2.json`
- `runs/engineering-suite-kicad-ltspice-report-20260603.json` after extending the engineering suite with LTspice: `ok`, 1 loop, 2 child task runs.
- `runs/engineering-suite-kicad-ltspice-sim-report-20260603.json` after adding LTspice simulation-output checks: `ok`, 1 loop, 2 child task runs.

Publication dry run:

- `scripts/export_clean.py /tmp/win-gui-agent-clean`
- `/tmp/win-gui-agent-clean/scripts/preflight.py /tmp/win-gui-agent-clean`
- Result: 12 tests passed, example JSON parsed, and no generated `runs/`, cache, or bytecode files remained in the clean export.
- Local GitHub-ready repository dry run: `/tmp/win-gui-agent-github`
  - Branch: `main`
  - Commit: `Initial win-gui-agent release`
  - Result: committed tree passed `scripts/preflight.py .`.
- Persistent release repository: `/home/xuan/FPGA/win-gui-agent-release`
  - Branch: `main`
  - Initial tag: `v0.1.0`
  - Latest tag after the LTspice extension: `v0.1.1`
  - Archives: `/home/xuan/FPGA/releases/win-gui-agent-0.1.1.tar.gz` and `/home/xuan/FPGA/releases/win-gui-agent-0.1.1.zip`
  - Archive check: extracted v0.1.1 tarball passed `scripts/preflight.py`.

## Known Limitation

This VM currently reports an OpenGL warning in KiCad:

```text
无法使用 OpenGL, 回退到软件渲染
OpenGL 2.1 or higher is required!
```

The schematic and PCB editors still work through software rendering, and the trial passed for 2D engineering workflows. Do not make 3D Viewer a required check on this VM until the virtual GPU/OpenGL stack is improved.
