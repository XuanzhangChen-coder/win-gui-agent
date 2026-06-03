# Troubleshooting

## Screenshot Is Black Or Empty

The agent is probably not running in an interactive desktop session. Register it with `LogonType Interactive`, log in as the target user, then restart the task.

## Clicks Miss The Target

Use screenshots captured by the agent, not screenshots from a remote viewer. The same Windows process must capture pixels and send mouse input.

Check:

```bash
client/wga.sh screen
```

Then click using coordinates from that screenshot.

## Agent Window Appears In Screenshots

Register the scheduled task with `-WindowStyle Hidden` and restart it:

```powershell
C:\GuiAgent\win-gui-agent\scripts\register-task.ps1
C:\GuiAgent\win-gui-agent\scripts\restart-agent.ps1
```

## OCR Returns Too Much Text

Full-screen OCR sees title bars, taskbar text, and background windows. Prefer bounded OCR:

```bash
client/wga.sh ocr "$SHOT" eng 6 LEFT TOP RIGHT BOTTOM
client/wga.sh ocr-find-text Next "$SHOT" eng 6 LEFT TOP RIGHT BOTTOM
```

Use UI Automation or a window rectangle to choose the bounds.

## OCR Backend Missing

Install Tesseract:

```powershell
winget install --id tesseract-ocr.tesseract --source winget --accept-package-agreements --accept-source-agreements
```

The agent searches:

```text
tesseract.exe
C:\Program Files\Tesseract-OCR\tesseract.exe
C:\Program Files (x86)\Tesseract-OCR\tesseract.exe
```

## Multiple Old Windows Break A Demo

Reset the demo state before running it. For Notepad:

```powershell
Get-Process notepad -ErrorAction SilentlyContinue | Stop-Process -Force
```

Task files can do this with a first `run` step that starts PowerShell and stops the old process.

Modern Windows Notepad can restore old tabs or leave untitled UWP container windows after repeated forced resets. Keep Notepad as a real-application demo, but prefer `examples/text-pad-ocr-task.json` for long unattended OCR/UIA reliability runs.

Window actions can target untitled shell/container windows with:

```json
{
  "action": "close_window",
  "classNameContains": "ApplicationFrameWindow",
  "includeUntitled": true
}
```

## API Returns HTTP 500

Open the latest run log:

```powershell
Get-ChildItem C:\GuiAgent\runs | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Get-Content C:\GuiAgent\runs\<latest>\agent.log -Tail 120
```

The agent records the route, error message, invocation position, and script stack trace.
