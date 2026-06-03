#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${WGA_URL:-http://127.0.0.1:8765}"

usage() {
  cat <<'EOF'
Usage:
  wga.sh health
  wga.sh screen
  wga.sh screenshot
  wga.sh click X Y [CLICKS]
  wga.sh double-click X Y
  wga.sh move X Y
  wga.sh type TEXT
  wga.sh text TEXT
  wga.sh key KEY
  wga.sh hotkey KEY...
  wga.sh run FILE [ARGUMENTS...]
  wga.sh windows
  wga.sh active-window
  wga.sh activate-window TITLE_CONTAINS
  wga.sh maximize-window TITLE_CONTAINS
  wga.sh close-window TITLE_CONTAINS
  wga.sh uia-tree WINDOW_TITLE_CONTAINS [MAX_DEPTH]
  wga.sh uia-find WINDOW_TITLE_CONTAINS NAME_CONTAINS [CONTROL_TYPE]
  wga.sh uia-click WINDOW_TITLE_CONTAINS NAME_CONTAINS [CONTROL_TYPE]
  wga.sh uia-set-text WINDOW_TITLE_CONTAINS NAME_CONTAINS TEXT [CONTROL_TYPE]
  wga.sh vision-diff BEFORE_PATH AFTER_PATH [STEP] [THRESHOLD]
  wga.sh vision-find-image IMAGE_PATH TEMPLATE_PATH [STEP] [PIXEL_STEP]
  wga.sh vision-click-image TEMPLATE_PATH [IMAGE_PATH] [STEP] [PIXEL_STEP]
  wga.sh ocr [IMAGE_PATH] [LANGUAGE] [PSM] [LEFT TOP RIGHT BOTTOM]
  wga.sh ocr-find-text TEXT [IMAGE_PATH] [LANGUAGE] [PSM] [LEFT TOP RIGHT BOTTOM]
  wga.sh ocr-click-text TEXT [IMAGE_PATH] [LANGUAGE] [PSM] [MIN_CONFIDENCE] [LEFT TOP RIGHT BOTTOM]
  wga.sh verify JSON
  wga.sh action-json JSON

Set WGA_URL to override the agent URL.
EOF
}

post_json() {
  local endpoint="$1"
  local json="$2"
  curl -fsS -H 'Content-Type: application/json' -X POST -d "$json" "$BASE_URL/$endpoint"
}

cmd="${1:-}"
case "$cmd" in
  health|screen|screenshot|windows)
    curl -fsS "$BASE_URL/$cmd"
    ;;
  active-window|active_window)
    curl -fsS "$BASE_URL/active_window"
    ;;
  click)
    x="${2:?X required}"
    y="${3:?Y required}"
    clicks="${4:-1}"
    post_json click "{\"x\":$x,\"y\":$y,\"clicks\":$clicks}"
    ;;
  double-click|double_click)
    x="${2:?X required}"
    y="${3:?Y required}"
    post_json double_click "{\"x\":$x,\"y\":$y}"
    ;;
  move)
    x="${2:?X required}"
    y="${3:?Y required}"
    post_json move "{\"x\":$x,\"y\":$y}"
    ;;
  type|text)
    endpoint="$cmd"
    raw=false
    if [[ "${2:-}" == "--raw" ]]; then
      raw=true
      shift
    fi
    text="${*:2}"
    python3 - "$text" "$raw" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/$endpoint"
import json, sys
print(json.dumps({"text": sys.argv[1], "raw": sys.argv[2] == "true"}))
PY
    ;;
  key)
    key="${2:?KEY required}"
    python3 - "$key" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/key"
import json, sys
print(json.dumps({"key": sys.argv[1]}))
PY
    ;;
  hotkey)
    shift
    python3 - "$@" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/hotkey"
import json, sys
print(json.dumps({"keys": sys.argv[1:]}))
PY
    ;;
  run)
    file="${2:?FILE required}"
    arguments="${*:3}"
    python3 - "$file" "$arguments" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/run"
import json, sys
print(json.dumps({"file": sys.argv[1], "arguments": sys.argv[2]}))
PY
    ;;
  activate-window|activate_window)
    title="${2:?TITLE_CONTAINS required}"
    python3 - "$title" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/activate_window"
import json, sys
print(json.dumps({"titleContains": sys.argv[1]}))
PY
    ;;
  maximize-window|maximize_window)
    title="${2:?TITLE_CONTAINS required}"
    python3 - "$title" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/maximize_window"
import json, sys
print(json.dumps({"titleContains": sys.argv[1]}))
PY
    ;;
  close-window|close_window)
    title="${2:?TITLE_CONTAINS required}"
    python3 - "$title" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/close_window"
import json, sys
print(json.dumps({"titleContains": sys.argv[1]}))
PY
    ;;
  uia-tree|uia_tree)
    title="${2:-}"
    max_depth="${3:-3}"
    python3 - "$title" "$max_depth" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/uia/tree"
import json, sys
print(json.dumps({"windowTitleContains": sys.argv[1], "maxDepth": int(sys.argv[2]), "maxNodes": 200}))
PY
    ;;
  uia-find|uia_find)
    title="${2:?WINDOW_TITLE_CONTAINS required}"
    name="${3:?NAME_CONTAINS required}"
    control_type="${4:-}"
    python3 - "$title" "$name" "$control_type" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/uia/find"
import json, sys
body = {"windowTitleContains": sys.argv[1], "nameContains": sys.argv[2], "limit": 20}
if sys.argv[3]:
    body["controlType"] = sys.argv[3]
print(json.dumps(body))
PY
    ;;
  uia-click|uia_click)
    title="${2:?WINDOW_TITLE_CONTAINS required}"
    name="${3:?NAME_CONTAINS required}"
    control_type="${4:-}"
    python3 - "$title" "$name" "$control_type" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/uia/click"
import json, sys
body = {"windowTitleContains": sys.argv[1], "nameContains": sys.argv[2], "includeOffscreen": False}
if sys.argv[3]:
    body["controlType"] = sys.argv[3]
print(json.dumps(body))
PY
    ;;
  uia-set-text|uia_set_text)
    title="${2:?WINDOW_TITLE_CONTAINS required}"
    name="${3:?NAME_CONTAINS required}"
    text="${4:?TEXT required}"
    control_type="${5:-}"
    python3 - "$title" "$name" "$text" "$control_type" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/uia/set_text"
import json, sys
body = {"windowTitleContains": sys.argv[1], "nameContains": sys.argv[2], "text": sys.argv[3], "includeOffscreen": False}
if sys.argv[4]:
    body["controlType"] = sys.argv[4]
print(json.dumps(body))
PY
    ;;
  vision-diff|vision_diff)
    before="${2:?BEFORE_PATH required}"
    after="${3:?AFTER_PATH required}"
    step="${4:-8}"
    threshold="${5:-24}"
    python3 - "$before" "$after" "$step" "$threshold" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/vision/diff"
import json, sys
print(json.dumps({
    "before": sys.argv[1],
    "after": sys.argv[2],
    "step": int(sys.argv[3]),
    "threshold": int(sys.argv[4]),
}))
PY
    ;;
  vision-find-image|vision_find_image)
    image="${2:?IMAGE_PATH required}"
    template="${3:?TEMPLATE_PATH required}"
    step="${4:-4}"
    pixel_step="${5:-4}"
    python3 - "$image" "$template" "$step" "$pixel_step" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/vision/find_image"
import json, sys
print(json.dumps({
    "image": sys.argv[1],
    "template": sys.argv[2],
    "step": int(sys.argv[3]),
    "pixelStep": int(sys.argv[4]),
}))
PY
    ;;
  vision-click-image|vision_click_image)
    template="${2:?TEMPLATE_PATH required}"
    image="${3:-}"
    step="${4:-4}"
    pixel_step="${5:-4}"
    python3 - "$template" "$image" "$step" "$pixel_step" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/vision/click_image"
import json, sys
body = {
    "template": sys.argv[1],
    "step": int(sys.argv[3]),
    "pixelStep": int(sys.argv[4]),
}
if sys.argv[2]:
    body["image"] = sys.argv[2]
print(json.dumps(body))
PY
    ;;
  ocr)
    image="${2:-}"
    language="${3:-eng}"
    psm="${4:-6}"
    left="${5:-}"
    top="${6:-}"
    right="${7:-}"
    bottom="${8:-}"
    python3 - "$image" "$language" "$psm" "$left" "$top" "$right" "$bottom" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/ocr"
import json, sys
body = {"language": sys.argv[2], "psm": int(sys.argv[3])}
if sys.argv[1]:
    body["image"] = sys.argv[1]
for key, value in zip(("left", "top", "right", "bottom"), sys.argv[4:8]):
    if value:
        body[key] = int(value)
print(json.dumps(body))
PY
    ;;
  ocr-find-text|ocr_find_text)
    text="${2:?TEXT required}"
    image="${3:-}"
    language="${4:-eng}"
    psm="${5:-6}"
    left="${6:-}"
    top="${7:-}"
    right="${8:-}"
    bottom="${9:-}"
    python3 - "$text" "$image" "$language" "$psm" "$left" "$top" "$right" "$bottom" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/ocr/find_text"
import json, sys
body = {"text": sys.argv[1], "language": sys.argv[3], "psm": int(sys.argv[4])}
if sys.argv[2]:
    body["image"] = sys.argv[2]
for key, value in zip(("left", "top", "right", "bottom"), sys.argv[5:9]):
    if value:
        body[key] = int(value)
print(json.dumps(body))
PY
    ;;
  ocr-click-text|ocr_click_text)
    text="${2:?TEXT required}"
    image="${3:-}"
    language="${4:-eng}"
    psm="${5:-6}"
    min_confidence="${6:-0}"
    left="${7:-}"
    top="${8:-}"
    right="${9:-}"
    bottom="${10:-}"
    python3 - "$text" "$image" "$language" "$psm" "$min_confidence" "$left" "$top" "$right" "$bottom" <<'PY' | curl -fsS -H 'Content-Type: application/json' -X POST -d @- "$BASE_URL/ocr/click_text"
import json, sys
body = {"text": sys.argv[1], "language": sys.argv[3], "psm": int(sys.argv[4]), "minConfidence": float(sys.argv[5])}
if sys.argv[2]:
    body["image"] = sys.argv[2]
for key, value in zip(("left", "top", "right", "bottom"), sys.argv[6:10]):
    if value:
        body[key] = int(value)
print(json.dumps(body))
PY
    ;;
  verify)
    json="${2:?JSON required}"
    curl -fsS -H 'Content-Type: application/json' -X POST -d "$json" "$BASE_URL/verify"
    ;;
  action-json|action_json)
    json="${2:?JSON required}"
    curl -fsS -H 'Content-Type: application/json' -X POST -d "$json" "$BASE_URL/action"
    ;;
  *)
    usage
    exit 2
    ;;
esac
