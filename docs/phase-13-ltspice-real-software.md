# Phase 13 LTspice Real Software Trial

Date: 2026-06-03

## Goal

Add a second real engineering application to the validation set. KiCad proves a PCB-design workflow; LTspice proves an analog simulation tool with a different UI stack, first-run modal behavior, and a user-local install path.

## Installed Software

- LTspice 26.0.2.1
  - Installer: `C:\Users\xuan\Downloads\LTspice64.msi`
  - Install command:

```powershell
msiexec /i C:\Users\xuan\Downloads\LTspice64.msi /qn /norestart /L*v C:\Tools\logs\ltspice-install.log
```

  - Install path: `C:\Users\xuan\AppData\Local\Programs\ADI\LTspice`
  - Application data path: `C:\Users\xuan\AppData\Local\LTspice`

The MSI install returned exit code `0`, and Windows Installer logged LTspice 26.0.2.1 as successfully installed.

## Project Setup

The trial copies LTspice's bundled educational low-pass filter schematic into a writable project directory:

```powershell
C:\GuiAgent\win-gui-agent\examples\ltspice-prepare-lowpass.ps1
```

Output:

- `C:\EE-Projects\wga-ltspice-demo\2ndOrderLowpass.asc`
- `C:\EE-Projects\wga-ltspice-demo\rc_filter.cir`
- `C:\EE-Projects\wga-ltspice-demo\rc_filter.raw`
- `C:\EE-Projects\wga-ltspice-demo\rc_filter.log`
- `C:\EE-Projects\wga-ltspice-demo\ltspice-demo-manifest.txt`

## Simulation And GUI Trial

Task file:

```text
examples/ltspice-lowpass-task.json
```

Run command:

```bash
python3 client/run_task.py examples/ltspice-lowpass-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/ltspice-lowpass-task-report.json \
  --quiet
```

Validated GUI behavior:

- Resets stale LTspice processes.
- Prepares a writable demo project from LTspice's bundled examples.
- Runs a generated RC-filter netlist through `LTspice.exe -b`.
- Verifies `rc_filter.raw` exists.
- Verifies `rc_filter.log` contains the measured `vout_final` value.
- Launches `LTspice.exe` with the schematic path.
- Handles the first-run `Anonymously Share LTspice Usage Data` modal as optional recovery.
- Handles LTspice one-time `Tool Change Log` and `New Keyboard Shortcuts` dialogs as optional recovery.
- Waits for the real schematic window by the stable schematic title.
- Activates the schematic window and verifies the project file content.

This trial intentionally combines product-level simulation evidence with GUI evidence. The batch simulation proves LTspice ran a circuit and produced results; the GUI steps prove the Windows-internal agent can observe, recover from first-run modal state, and control the desktop application itself.

Observed evidence:

- `runs/ltspice-lowpass-sim-task-report-20260603.json`: `ok`, 13 steps, raw/log simulation output verified, active window `LTspice - [2ndOrderLowpass]`.
- `runs/engineering-suite-kicad-ltspice-sim-report-20260603.json`: `ok`, 1 loop, 2 child task runs, 14.204 seconds.
- Simulation measurement:
  - `vout_final: V(out) =3.64633274078 at 0.005`
- Child reports:
  - `runs/engineering-suite-kicad-ltspice-sim-report-20260603-1-kicad-pic-programmer-task.json`
  - `runs/engineering-suite-kicad-ltspice-sim-report-20260603-1-ltspice-lowpass-task.json`

## Notes

The first-run usage-data dialog exposes old-style controls through UI Automation as panes with `className` equal to `Button`. The task therefore targets by `windowTitleContains`, `nameContains`, and `classNameContains` instead of requiring `controlType: Button`.

LTspice's main schematic window uses an MFC-style `Afx:...` class name that can vary between launches. The stable selector is the schematic title, for example `2ndOrderLowpass`, not the raw class name.
