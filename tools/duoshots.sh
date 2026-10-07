#!/bin/bash
# 📸 App Store screenshots on the iPhone Duo, in one language — the same five
# screens as the listing (kidhome, question, wheel, parenthome, choreskid).
#   tools/duoshots.sh <udid> <app> <lang> <outdir> [display-uuid]
# Uninstalls first (the demo child's NAME is seeded once per container — see
# shots.sh), warms up once (a cold start lands on the splash), then checks every
# frame is a Tofy screen, retrying up to three times.
D="$1"; APP="$2"; L="$3"; OUT="$4"; DISP="$5"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"
xcrun simctl uninstall "$D" com.rani.ChildTime 2>/dev/null
xcrun simctl install "$D" "$APP"
env SIMCTL_CHILD_DEMO_LANG="$L" SIMCTL_CHILD_DEMO_RESET=1 SIMCTL_CHILD_DEMO_SCREEN=kidhome \
  xcrun simctl launch "$D" com.rani.ChildTime >/dev/null; sleep 10
shoot() {  # shoot <n-name> <screen> [env…]
  local name="$1" screen="$2"; shift 2
  for try in 1 2 3; do
    xcrun simctl terminate "$D" com.rani.ChildTime 2>/dev/null
    env SIMCTL_CHILD_DEMO_LANG="$L" SIMCTL_CHILD_DEMO_SCREEN="$screen" "$@" \
      xcrun simctl launch "$D" com.rani.ChildTime >/dev/null
    sleep 9
    xcrun simctl io "$D" screenshot ${DISP:+--display=$DISP} "$OUT/$name.png" >/dev/null 2>&1
    read -r r g b <<< "$(python3 "$HERE/avgcolor.py" "$OUT/$name.png")"
    if [ "$b" -ge $((r + 15)) ] && [ "$b" -ge 60 ]; then echo "  ✔ $L/$name"; return 0; fi
    echo "  ↻ $L/$name (rgb $r,$g,$b, try $try)"
  done
  echo "  ✗ $L/$name — GAVE UP"; return 1
}
shoot 1-kidhome    kidhome
shoot 2-question   mathgrade SIMCTL_CHILD_DEMO_WORLD=math SIMCTL_CHILD_DEMO_GRADE=3
shoot 3-wheel      wheel
shoot 4-parenthome parenthome
shoot 5-choreskid  choreskid
