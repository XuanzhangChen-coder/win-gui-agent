# Phase 4-5 Validation

Date: 2026-06-01

Environment:

- VM: `win11-ee`
- Agent endpoint inside Windows: `http://127.0.0.1:8765`

## Target Capabilities

Phase 4:

- `/windows`
- `/active_window`
- `/activate_window`
- `/maximize_window`
- `/close_window`

Phase 5:

- `/uia/tree`
- `/uia/find`
- `/uia/click`
- `/uia/set_text`

## Validation Procedure

Run:

```powershell
C:\GuiAgent\win-gui-agent\scripts\demo-window-uia.ps1
```

Expected behavior:

- Notepad opens.
- Agent finds Notepad in the top-level window list.
- Agent activates and maximizes Notepad by window handle.
- Agent reads a UI Automation tree from the Notepad window.
- Agent finds the editor control via UI Automation.
- Agent sets text without relying on a hard-coded click coordinate.
- A screenshot is copied to `\\192.168.122.1\vmshare\wga-demo-window-uia.png`.

## Results

Passed.

Observed evidence:

- `/windows` returned visible top-level windows including Notepad, Settings, Vivado, and Program Manager.
- `/active_window` returned foreground window metadata with hwnd, title, class name, and rectangle.
- `/activate_window` brought a Notepad window to foreground by title/handle.
- `/maximize_window` maximized the target Notepad window.
- `/uia/tree` returned the Notepad UI Automation hierarchy. The editor appeared as:
  - `name`: `文本编辑器`
  - `className`: `RichEditD2DPT`
  - `controlType`: `ControlType.Document`
- `/uia/set_text` set text in the Notepad editor using `ValuePattern`, not a coordinate click.
- Final screenshot copied to:
  - `/home/xuan/VMs/shared/wga-demo-window-uia.png`

Final visible text:

```text
phase 4-5 window and uia validation
```

## Issues Found And Fixed

- Initial `/windows` implementation used a PowerShell script block as a Win32 `EnumWindows` callback and failed with a parameter type mismatch. The window enumeration logic was moved into the C# interop helper.
- UIA tree calls depend on window lookup, so the same window enumeration issue initially affected `/uia/tree`.
- Notepad on Windows 11 exposes the editor as `ControlType.Document` with localized name `文本编辑器`; the demo falls back to `ControlType.Edit` only if `Document` is unavailable.

## Current Limitation

UI Automation is excellent for standard controls, but complex self-drawn tools may expose incomplete control trees. Phase 6 should add template matching and screenshot-diff verification for those cases.
