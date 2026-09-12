#!/bin/bash
# Website screenshots in one language. Usage: shots.sh <lang> <outdir>
set -e
LANG_CODE="$1"; OUT="$2"
D=427C2D37-8D77-48AD-957F-3C69EDD4D1C3
APP=/private/tmp/claude-501/-Users-raniophir-ChildTime/1dc2083a-3de8-4dc0-b3fd-aa18f2342293/scratchpad/dd/Build/Products/Debug-iphonesimulator/ChildTime.app
HERE="$(cd "$(dirname "$0")" && pwd)"
TMP=$(mktemp -d)
mkdir -p "$OUT"
xcrun simctl install $D "$APP" >/dev/null
# The demo profile stores the child's NAME, seeded once. Left over from a run in
# another language it would put "דָּנָה" on a Russian marketing screenshot, so the
# first launch wipes the demo data and re-seeds it in this language.
xcrun simctl terminate $D com.rani.ChildTime 2>/dev/null || true
env SIMCTL_CHILD_DEMO_LANG="$LANG_CODE" SIMCTL_CHILD_DEMO_RESET=1 SIMCTL_CHILD_DEMO_SCREEN=kidhome \
  xcrun simctl launch $D com.rani.ChildTime >/dev/null
sleep 8

# One screen. The app is verified to be RUNNING right before the shutter —
# without that, a launch that died left the simulator's home screen in the
# frame, and "question.jpg" on the Russian site was a picture of the iOS
# springboard. Three tries, then say so loudly instead of shipping it.
shoot() {  # shoot <file> <DEMO_SCREEN> [extra env assignments…]
  local name="$1"; shift
  local screen="$1"; shift
  local try
  for try in 1 2 3; do
    xcrun simctl terminate $D com.rani.ChildTime 2>/dev/null || true
    env SIMCTL_CHILD_DEMO_LANG="$LANG_CODE" SIMCTL_CHILD_DEMO_SCREEN="$screen" "$@" \
      xcrun simctl launch $D com.rani.ChildTime >/dev/null
    sleep 9
    if ! xcrun simctl spawn $D launchctl list 2>/dev/null | grep -q "UIKitApplication:com.rani.ChildTime\["; then
      echo "  ↻ $name — the app was not running (try $try)"
      continue
    fi
    xcrun simctl io $D screenshot "$TMP/$name.png" >/dev/null 2>&1
    # …and the frame is checked, not just the process. Every Tofy screen sits on
    # the brand's blue-purple gradient, so the average pixel is blue-dominant.
    # A dead launch gives the beige springboard (warm) and a launch that hasn't
    # drawn yet gives black — both fail this, and both shipped before it existed.
    local rgb; rgb=$(python3 "$HERE/avgcolor.py" "$TMP/$name.png")
    local r g b; read -r r g b <<< "$rgb"
    if [ $b -lt $((r + 15)) ] || [ $b -lt 60 ]; then
      echo "  ↻ $name — not a Tofy screen (rgb $r,$g,$b, try $try)"
      continue
    fi
    sips -s format jpeg -s formatOptions 82 -Z 1782 "$TMP/$name.png" --out "$OUT/$name.jpg" >/dev/null
    echo "  ✔ $name"
    return 0
  done
  echo "  ✗ $name — GAVE UP, the screen never came up"
  return 1
}

shoot kidhome         kidhome
shoot question        mathgrade      SIMCTL_CHILD_DEMO_WORLD=math SIMCTL_CHILD_DEMO_GRADE=3
shoot choreskid       choreskid
shoot wheel           wheel
shoot shop            shop
shoot leaderboard     leaderboard
shoot dailychest      dailychest
shoot dashboard       dashboard
shoot parenthome      dashboard
shoot giftearly       dashboard      SIMCTL_CHILD_DEMO_GIFT_MINUTES=10
shoot devicecontrols  childscreentime
shoot childscreentime childscreentime
shoot childworlds     childworlds
shoot childdifficulty childdifficulty
shoot choresparent    choresparent
shoot packdetail      packdetail
echo "→ $OUT"
