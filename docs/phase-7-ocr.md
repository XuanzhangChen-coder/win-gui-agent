# Phase 7 OCR

Date: 2026-06-01

## Implemented

OCR endpoints:

```text
POST /ocr
POST /ocr/find_text
POST /ocr/click_text
```

Verifier expectation:

```json
{
  "ocrTextContains": {
    "image": "C:\\path\\to\\screenshot.png",
    "text": "Next",
    "language": "eng",
    "psm": 6
  }
}
```

Client commands:

```bash
client/wga.sh ocr [IMAGE_PATH] [LANGUAGE] [PSM] [LEFT TOP RIGHT BOTTOM]
client/wga.sh ocr-find-text TEXT [IMAGE_PATH] [LANGUAGE] [PSM] [LEFT TOP RIGHT BOTTOM]
client/wga.sh ocr-click-text TEXT [IMAGE_PATH] [LANGUAGE] [PSM] [MIN_CONFIDENCE] [LEFT TOP RIGHT BOTTOM]
```

## Backend

The first OCR backend is Tesseract. The agent detects:

- `tesseract.exe` on PATH;
- `C:\Program Files\Tesseract-OCR\tesseract.exe`;
- `C:\Program Files (x86)\Tesseract-OCR\tesseract.exe`.

If no backend is present, `/ocr` returns `ok: false` with a `missing backend` style diagnostic instead of pretending OCR is available.

## Validation

Passed.

### Backend Detection

Tesseract was installed in the Windows VM through `winget`:

```text
tesseract-ocr.tesseract 5.5.0.20241111
```

The agent detected:

```text
C:\Program Files\Tesseract-OCR\tesseract.exe
```

### Full-Screen OCR

Full-screen OCR worked, but it intentionally showed why unrestricted OCR should not be the default decision primitive: it read visible title bars, taskbar text, and background windows along with the target application.

Example result:

```text
ocr ok: true
word count: 85
query "target": found
```

### Region OCR

Validated with Notepad showing:

```text
gui agent ocr target line one
visible next cancel install words
```

Command shape:

```bash
client/wga.sh ocr "$SHOT" eng 6 0 70 320 135
client/wga.sh ocr-find-text target "$SHOT" eng 6 0 70 320 135
client/wga.sh ocr-click-text target "$SHOT" eng 6 40 0 70 320 135
```

Result:

```text
region text: gui agent ocr target line one visible next cancel install words
target confidence: 93.747299
target center: x=138, y=94
click result: ok
```

Evidence paths from the Windows run:

- `C:\GuiAgent\runs\20260601-221257\00003-manual.png`
- `C:\GuiAgent\runs\20260601-221257\00011-ocr-crop.png`
- `C:\GuiAgent\runs\20260601-221257\00018-ocr-click-text-after.png`

The task DSL OCR demo also passed:

```bash
python3 client/run_task.py examples/notepad-ocr-task.json \
  --base-url http://127.0.0.1:8765 \
  --report runs/notepad-ocr-task-report.json
```

Result:

```text
task: notepad-ocr-demo
steps: 7
ok: true
bounded OCR target confidence: 96.954086
OCR click target center: x=138, y=94
```

Shared evidence:

- `/home/xuan/VMs/shared/wga-ocr-task-crop.png`
- `/home/xuan/VMs/shared/wga-ocr-task-final.png`

## Lessons

OCR should usually be constrained to a region obtained from UI Automation, a known window rectangle, or a prior visual match. Full-screen OCR is useful for diagnostics, but it is too noisy for reliable unattended clicking.

The agent scheduled task now starts PowerShell with `-WindowStyle Hidden` so the agent console does not steal foreground focus or appear in screenshots.
