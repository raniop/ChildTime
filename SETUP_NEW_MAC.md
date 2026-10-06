# מק חדש: מה צריך כדי שטופי תעבוד שוב

הקוד כולו ב-GitHub. המסמך הזה מכסה את מה ש**לא** נמצא שם — כלים, מפתחות והגדרות
מקומיות. בלי זה אפשר לקרוא את הקוד, אבל אי אפשר לבנות, לחתום או להעלות גרסה.

---

## 1. לפני שעוזבים את המק הישן

- [ ] **מפתח ההעלאה לאנדרואיד** — `~/.tofy-keys/upload.jks` + הסיסמה שלו.
      🔴 היחיד שאי אפשר ליצור מחדש לבד. בלעדיו אין עדכונים ל-Google Play.
      הסיסמה שמורה ב-Keychain בשם "Tofy Android upload key", וגם ב-`~/.gradle/gradle.properties`.
- [ ] **מפתח App Store Connect** — `~/.appstoreconnect/private_keys/AuthKey_2N6QHTA4QJ.p8`
      (אפשר ליצור חדש באפל, אבל אז צריך לעדכן את `tools/asc.js` ואת סקריפטי ההעלאה).
- [ ] שניהם למנהל הסיסמאות (1Password / Bitwarden) — **לא** למייל ולא לדרייב לא מוצפן.
      `tools/backup-secrets.sh` אורז אותם לקובץ `.dmg` מוצפן אם מעדיפים ענן.
- [ ] גיבוי Time Machine אחרון לדיסק חיצוני.
- [ ] לוודא ש-`git status` נקי ושהכול נדחף.

> העברה עם **Migration Assistant** בכבל Thunderbolt מעבירה גם את ה-Keychain,
> את `~/.tofy-keys`, את `~/.gradle` ואת ההתחברויות ל-Firebase ו-gcloud.
> עדיין כדאי שהמפתחות יהיו במנהל הסיסמאות — Migration Assistant נכשל לפעמים.

---

## 2. על המק החדש

### כלים בסיסיים
```bash
xcode-select --install          # כלי שורת הפקודה
```
- **Xcode** מה-App Store (27.1 ומעלה — יש קוד שמותנה ב-27.1 בשביל ה-iPhone המתקפל).
  בפתיחה הראשונה הוא מוריד את סימולטור iOS. **לא למחוק גרסאות סימולטור ביד** —
  זה מה שגרם להורדה מחדש של 8GB באוקטובר 2026.
- **Node 22** ו-**Python 3.9+** (מגיעים עם macOS או דרך Homebrew).
- **Firebase CLI**: `npm i -g firebase-tools` ואז `firebase login`.
- **gcloud** (רק אם נוגעים ב-Pub/Sub של חיובי Google Play): `gcloud auth login`.

### כלי אנדרואיד
Homebrew על המק הישן היה התקנה של Intel ולא עבד, לכן הכול הותקן ידנית ל-`~/Android`:
```bash
mkdir -p ~/Android && cd ~/Android
# JDK 17 (לבנייה) ו-JDK 21 (לאמולטורים של Firebase)
curl -fsSL -o jdk17.tar.gz "https://api.adoptium.net/v3/binary/latest/17/ga/mac/aarch64/jdk/hotspot/normal/eclipse" && tar xzf jdk17.tar.gz
curl -fsSL -o jdk21.tar.gz "https://api.adoptium.net/v3/binary/latest/21/ga/mac/aarch64/jdk/hotspot/normal/eclipse" && tar xzf jdk21.tar.gz
# Android SDK
curl -fsSL -o cl.zip "https://dl.google.com/android/repository/commandlinetools-mac-13114758_latest.zip"
mkdir -p sdk/cmdline-tools && unzip -q cl.zip -d sdk/cmdline-tools && mv sdk/cmdline-tools/cmdline-tools sdk/cmdline-tools/latest
export JAVA_HOME=~/Android/jdk-17*/Contents/Home
yes | sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$PWD/sdk --licenses
sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$PWD/sdk "platform-tools" "platforms;android-35" "build-tools;35.0.0" "emulator" "system-images;android-35;google_apis;arm64-v8a"
sdk/cmdline-tools/latest/bin/avdmanager create avd -n tofy -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_7
```
אחר כך `android/local.properties` (לא בגיט):
```
sdk.dir=/Users/<USER>/Android/sdk
```

### שחזור המפתחות
```bash
mkdir -p ~/.tofy-keys ~/.appstoreconnect/private_keys
# להעתיק מ-1Password:
#   upload.jks                  → ~/.tofy-keys/upload.jks
#   AuthKey_2N6QHTA4QJ.p8       → ~/.appstoreconnect/private_keys/
chmod 700 ~/.tofy-keys && chmod 600 ~/.tofy-keys/upload.jks
```
ואז `~/.gradle/gradle.properties` (גם לא בגיט):
```
TOFY_UPLOAD_STORE_FILE=/Users/<USER>/.tofy-keys/upload.jks
TOFY_UPLOAD_STORE_PASSWORD=<מ-1Password>
TOFY_UPLOAD_KEY_ALIAS=tofy-upload
TOFY_UPLOAD_KEY_PASSWORD=<אותה סיסמה>
```

### תעודות החתימה של אפל
לפתוח את Xcode ← Settings ← Accounts ← להתחבר עם חשבון המפתח ←
"Download Manual Profiles". הבנייה משתמשת ב-`-allowProvisioningUpdates`,
כך שאפל מנפיקה מה שחסר לבד.

---

## 3. בדיקה שהכול עובד

```bash
# iOS
xcodebuild -project ChildTime.xcodeproj -scheme ChildTime \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO

# אנדרואיד — דיבאג, בדיקות, ו-release חתום
cd android
JAVA_HOME=~/Android/jdk-17*/Contents/Home ./gradlew assembleDebug testDebugUnitTest
JAVA_HOME=~/Android/jdk-17*/Contents/Home ./gradlew bundleRelease
```
אם ה-release נבנה **חתום** — המפתח שוחזר נכון.

---

## 4. מספרים שצריך לדעת

| מה | ערך |
|---|---|
| Apple Team ID | TFG2H9C76N |
| App Store app id | 6773805449 |
| ASC Key ID / Issuer | 2N6QHTA4QJ / 69a6de6e-f3cf-47e3-e053-5b8c7c11a4d1 |
| Firebase project | childtime-86e98 |
| חבילת אנדרואיד | com.rani.tofy |
| SHA-1 של מפתח ההעלאה | 44:1A:A6:59:3F:FD:97:69:B0:8C:38:71:3C:EB:29:A4:F4:C5:A3:7E |

אם ה-SHA-1 על המק החדש שונה — המפתח לא שוחזר, אלא נוצר חדש. לעצור ולבדוק:
```bash
keytool -list -v -keystore ~/.tofy-keys/upload.jks -alias tofy-upload | grep SHA1
```
