#!/bin/bash
# Convert a Mixamo character into a SceneKit-ready .scn dropped into the app.
# Accepts a static .fbx (Characters tab) OR an idle .dae (Animations tab → the
# idle's relaxed first frame is baked, giving a natural pose, no T-pose).
# Usage: tools/convert_character.sh <path/to/character.fbx|.dae> <name>
set -e

SRC="$1"
NAME="${2:-character}"
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$(cd "$HERE/.." && pwd)/ChildTime/Characters3D"
BLENDER="/Applications/Blender.app/Contents/MacOS/Blender"
TMP="$(mktemp -d)"

if [ ! -f "$SRC" ]; then echo "Not found: $SRC"; exit 1; fi
if [ ! -x "$BLENDER" ]; then echo "Blender not found at $BLENDER"; exit 1; fi

EXT="$(echo "${SRC##*.}" | tr '[:upper:]' '[:lower:]')"
echo "[1/2] Blender: $EXT -> OBJ…"
if [ "$EXT" = "dae" ]; then
  "$BLENDER" --background --factory-startup --python "$HERE/dae_to_obj.py" -- "$SRC" "$TMP/$NAME.obj" 1 2>&1 | grep -E "OBJDONE|Error" || true
  # Mixamo .dae references external textures in a sibling folder — bring them
  # next to the OBJ so the diffuse resolves.
  cp "$(dirname "$SRC")/textures/"* "$TMP/" 2>/dev/null || true
else
  "$BLENDER" --background --factory-startup --python "$HERE/fbx_to_obj.py" -- "$SRC" "$TMP/$NAME.obj" 2>&1 | grep -E "OBJDONE|Error" || true
fi

echo "[2/2] Model I/O: OBJ -> .scn…"
swift "$HERE/obj_to_scn.swift" "$TMP/$NAME.obj" "$DEST/$NAME.scn"

rm -rf "$TMP"
echo "✅ $DEST/$NAME.scn"
