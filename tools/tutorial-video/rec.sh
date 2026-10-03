#!/bin/zsh
# rec.sh start <simid> <name> | rec.sh stop
T=/private/tmp/claude-501/-Users-raniophir-ChildTime/1dc2083a-3de8-4dc0-b3fd-aa18f2342293/scratchpad/tutorial
if [ "$1" = start ]; then
  nohup xcrun simctl io $2 recordVideo --codec=h264 --force $T/rec/$3.mov > $T/rec/$3.log 2>&1 &
  echo $! > $T/rec/pid; sleep 1.5; echo "rec pid $(cat $T/rec/pid)"
else
  kill -INT $(cat $T/rec/pid); sleep 2.5; ls -la $T/rec/*.mov | tail -1
fi
