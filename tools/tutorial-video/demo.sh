#!/bin/zsh
# usage: demo.sh <simid> <screen> [reset]
ID=$1; SCR=$2; RESET=${3:-0}
xcrun simctl terminate $ID com.rani.ChildTime 2>/dev/null
if [ "$RESET" = 1 ]; then
 env SIMCTL_CHILD_DEMO_LANG=he SIMCTL_CHILD_DEMO_RESET=1 SIMCTL_CHILD_DEMO_SCREEN=$SCR xcrun simctl launch $ID com.rani.ChildTime
else
 env SIMCTL_CHILD_DEMO_LANG=he SIMCTL_CHILD_DEMO_SCREEN=$SCR xcrun simctl launch $ID com.rani.ChildTime
fi
