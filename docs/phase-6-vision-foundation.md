# Phase 6 Vision Foundation

Date: 2026-06-01

## Implemented

The MVP now includes a lightweight image-diff endpoint:

```text
POST /vision/diff
```

Request:

```json
{
  "before": "C:\\GuiAgent\\runs\\...\\before.png",
  "after": "C:\\GuiAgent\\runs\\...\\after.png",
  "step": 8,
  "threshold": 24
}
```

Response includes:

- image dimensions;
- sampled pixel count;
- changed pixel count;
- changed ratio;
- average RGB delta;
- max RGB delta.

The MVP also includes first-pass template matching:

```text
POST /vision/find_image
POST /vision/click_image
```

This implementation uses built-in .NET bitmap APIs, so it has no external dependency. It is suitable for small templates and region-limited searches. It is intentionally a foundation; a later Python/OpenCV implementation should improve speed and matching robustness.

## Purpose

This is not full computer vision yet. It is the foundation for action verification:

- click a button;
- compare before/after screenshots;
- confirm that the GUI changed enough to count as progress;
- stop if the action produced no visible effect.

## Next Vision Work

- Add region-limited diff.
- Improve template matching performance.
- Add `find_image` and `click_image`.
- Add OCR after the image matching layer is stable.

## Validation

Passed on 2026-06-01.

Procedure:

1. Captured a before screenshot.
2. Activated Notepad.
3. Typed additional visible text.
4. Captured an after screenshot.
5. Called `/vision/diff` with `step = 8` and `threshold = 24`.

Result:

```json
{
  "width": 1440,
  "height": 900,
  "sampledPixels": 20340,
  "changedPixels": 11590,
  "changedRatio": 0.5698131760078663,
  "averageDelta": 228.92822025565388,
  "maxDelta": 747
}
```

Evidence screenshots:

- `/home/xuan/VMs/shared/wga-diff-before.png`
- `/home/xuan/VMs/shared/wga-diff-after.png`

Note: this validation also exposed that literal `\r\n` passed through the text endpoint is not converted into an actual newline. Keyboard/text normalization should be improved in a later input-hardening pass.

Template matching validation:

- Template: `/home/xuan/VMs/shared/wga-template-notepad-text.png`
- Image copied locally in Windows: `C:\GuiAgent\vision-test\image.png`
- Template copied locally in Windows: `C:\GuiAgent\vision-test\template.png`
- Final bounded search settings: `step = 4`, `pixelStep = 2`, region `(left=0, top=60, right=650, bottom=130)`
- Result:

```json
{
  "x": 272,
  "y": 80,
  "centerX": 408,
  "centerY": 91,
  "width": 271,
  "height": 22,
  "searchedPositions": 1235,
  "averageDelta": 96.766042780748663,
  "confidence": 0.87350844080947887
}
```

Known caveat: full-screen pure .NET template matching is slow. Callers should provide `left/top/right/bottom` search bounds whenever possible.
