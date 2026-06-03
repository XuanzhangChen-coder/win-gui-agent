# Phase 1-3 Validation

Date: 2026-06-01

Environment:

- VM: `win11-ee`
- Windows user: `xuan`
- Agent local path: `C:\GuiAgent\win-gui-agent`
- Agent endpoint inside Windows: `http://127.0.0.1:8765`
- Agent run mode: scheduled task `WinGuiAgent`, interactive desktop session
- Screen reported by agent: `1440x900`

## Validated

- The agent starts in Windows Session 1, not SSH Session 0.
- `/health` returns an active agent PID and run directory.
- `/screen` reports screen size, cursor position, active window title, and run directory.
- `/screenshot` captures the visible Windows desktop from inside Windows.
- `/run` launches Notepad in the interactive session.
- `/type` writes text into Notepad using clipboard paste.
- `/click` moves the cursor and clicks in the same coordinate system used for screenshots.
- Each action returns before/after screenshots.

## Evidence

Screenshots copied to the Ubuntu shared folder:

- `/home/xuan/VMs/shared/wga-first-screenshot.png`
- `/home/xuan/VMs/shared/wga-notepad-open4.png`
- `/home/xuan/VMs/shared/wga-notepad-typed.png`
- `/home/xuan/VMs/shared/wga-notepad-click-type.png`

## Issues Found And Fixed

- Windows SSH sessions do not reliably expose mapped drive `Z:`. Use UNC path `\\192.168.122.1\vmshare` for deployment.
- `Copy-Item source target` can accidentally create nested `win-gui-agent\win-gui-agent` directories. The deployment script now removes the target directory before copying.
- PowerShell 5.1 does not support the `??` operator. The agent uses explicit null checks.
- Scheduled task `RunLevel` accepts `Limited` or `Highest`, not `LeastPrivilege`.
- `Start-Process -ArgumentList ""` fails in PowerShell 5.1. The agent omits `ArgumentList` when empty.

## Current Limitation

Raw coordinate clicks are stable but not semantically smart. A coordinate click in Notepad can place the caret in the middle of a line. Phase 4-5 should add window management and UI Automation so tasks can target windows/controls instead of relying on naked coordinates.

## Next Phase

Phase 4:

- `/windows`
- `/active_window`
- `/activate_window`
- `/maximize_window`
- `/close_window`

Phase 5:

- UI Automation tree for standard controls.
- Click controls by name/type.
- Set text in standard input fields.
