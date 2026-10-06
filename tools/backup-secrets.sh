#!/bin/bash
# אורז את המפתחות שקיימים רק על המחשב הזה לקובץ .dmg מוצפן,
# שבטוח להעלות לכל ענן. מבקש סיסמה — תשמור אותה במנהל הסיסמאות.
#
#   ./tools/backup-secrets.sh [תיקיית-יעד]     # ברירת מחדל: ~/Desktop
set -euo pipefail
OUT="${1:-$HOME/Desktop}"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

copy() { [ -e "$1" ] && cp -R "$1" "$STAGE/" && echo "  ✓ $(basename "$1")" || echo "  — חסר: $1"; }

echo "אוסף מפתחות:"
copy "$HOME/.tofy-keys/upload.jks"
copy "$HOME/.appstoreconnect/private_keys/AuthKey_2N6QHTA4QJ.p8"
[ -f "$HOME/.gradle/gradle.properties" ] && grep -h '^TOFY_UPLOAD_' "$HOME/.gradle/gradle.properties" > "$STAGE/gradle-upload.properties" && echo "  ✓ gradle-upload.properties (כולל הסיסמה)"

cat > "$STAGE/README.txt" <<TXT
מפתחות טופי — גיבוי מ-$(date '+%Y-%m-%d')
upload.jks            : חתימת אפליקציית Google Play (alias: tofy-upload)
AuthKey_*.p8          : App Store Connect
gradle-upload.properties : הסיסמה של upload.jks
הוראות שחזור מלאות: SETUP_NEW_MAC.md במאגר.
TXT

DMG="$OUT/tofy-secrets-$(date '+%Y-%m-%d').dmg"
echo "יוצר $DMG — תתבקש להקליד סיסמה פעמיים:"
hdiutil create -encryption AES-256 -srcfolder "$STAGE" -volname "Tofy Secrets" -format UDZO "$DMG"
echo "✅ מוכן: $DMG"
echo "   להעלות לענן / מנהל הסיסמאות, ולשמור את הסיסמה במקום נפרד."
