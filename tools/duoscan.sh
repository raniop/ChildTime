#!/bin/bash
# 📐 Shoot every DEMO_SCREEN on a simulator — built for the foldable iPhone Duo,
# works for any device. Needs Xcode 27.1 (the Duo only exists on iOS 27.1).
#
#   tools/duoscan.sh <device-udid> <out-dir> [lang]            # all screens
#   SCREENS="kidhome paywall" tools/duoscan.sh <udid> <out>    # just these
#   swift tools/grid.swift sheet.png 7 300 <out>/*.png         # read them as a grid
#   SIM_DISPLAY=<uuid> tools/duoscan.sh …                       # a foldable's INNER screen
#     (the Duo has two: `xcrun simctl io <udid> enumerate` lists them — the outer
#      466×678pt one is the default; the inner 951×669pt one needs its UUID)
#
# The app must already be installed. What the screen measured is printed by the
# app itself (DisplayGeometry, DEBUG) — see tools/measure in the commit notes:
#   xcrun simctl launch --console-pty <udid> com.rani.ChildTime | grep 📐
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode-27.1.app/Contents/Developer}
DEV="$1"; OUT="$2"; LANG_CODE="${3:-he}"
[ -z "$DEV" ] || [ -z "$OUT" ] && { echo "usage: duoscan.sh <udid> <out-dir> [lang]"; exit 2; }
mkdir -p "$OUT"
SCREENS=${SCREENS:-"applock askparent askworld campaignpopup campaignpopupkid childdifficulty childjoin childscreentime childworlds choreskid choresparent createchild dailychest dashboard devicecontrols familychoice gate giftearly giftended giftlate gradepicker kidflow kidhome kidmode kidpass kidpin leaderboard levelup mathgrade onboarding opening openinggift packask packdetail packnew packoffer packowned packrequest packreveal parentassist parenthelp parenthome parentsettings paywall paywallgift question rolepicker shop starshop unlocked welcome whatsnew wheel worldpass worldshelf worldunlock"}
# One reset launch first, so the demo child is seeded in THIS language.
xcrun simctl terminate "$DEV" com.rani.ChildTime 2>/dev/null
env SIMCTL_CHILD_DEMO_LANG="$LANG_CODE" SIMCTL_CHILD_DEMO_RESET=1 SIMCTL_CHILD_DEMO_SCREEN=kidhome \
  xcrun simctl launch "$DEV" com.rani.ChildTime >/dev/null; sleep 8
for s in $SCREENS; do
  xcrun simctl terminate "$DEV" com.rani.ChildTime 2>/dev/null
  env SIMCTL_CHILD_DEMO_LANG="$LANG_CODE" SIMCTL_CHILD_DEMO_SCREEN="$s" \
      SIMCTL_CHILD_DEMO_WORLD=math SIMCTL_CHILD_DEMO_GRADE=3 \
    xcrun simctl launch "$DEV" com.rani.ChildTime >/dev/null
  sleep 6
  xcrun simctl io "$DEV" screenshot ${SIM_DISPLAY:+--display=$SIM_DISPLAY} "$OUT/$s.png" >/dev/null 2>&1 && echo "✔ $s" || echo "✗ $s"
done
