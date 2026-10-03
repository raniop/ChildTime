#!/bin/zsh
T=/private/tmp/claude-501/-Users-raniophir-ChildTime/1dc2083a-3de8-4dc0-b3fd-aa18f2342293/scratchpad/tutorial
f=$1; out=$2; shift 2; files=()
for t in "$@"; do $T/vtool frame $T/rec/$f.mov $t $T/shots/f_$t.png 300; files+=($T/shots/f_$t.png); done
$T/montage $T/shots/$out.jpg $files; rm $files
