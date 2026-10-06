# Android release checklist — Tofy (com.rani.tofy)

> Companion to the iOS RELEASE_CHECKLIST.md. Verified 2026-10-06: `./gradlew assembleRelease` and
> `./gradlew bundleRelease` both **build successfully with R8** (minify on) using the rules now in
> `android/app/proguard-rules.pro`; native lib (`libandroidx.graphics.path.so`) is 16 KB-page aligned.

---

## 1. Version numbers — one scheme for both platforms

iOS today: `MARKETING_VERSION = 2026.10.5`, `CURRENT_PROJECT_VERSION = 199`.
Android today (`android/app/build.gradle.kts`): `versionName = "2026.10.6"`, `versionCode = 1`.

**Policy (proposal):**

| Field | Rule | Example |
|---|---|---|
| `versionName` | = the iOS **marketing version** that has the same feature set (date-style `YYYY.M.D`). Users and support see the same "2026.10.5" on both stores. | `"2026.10.5"` |
| `versionCode` | = **iOS build × 10 + Android respin (0–9)**. Monotonic as long as iOS builds only go up; an Android-only fix gets `+1` without touching iOS; the iOS build is readable from it (`1993 → build 199, respin 3`). | iOS build 199 → `1990`; an Android hotfix → `1991` |

Why not just `versionCode = iOS build`: an Android-only rebuild would need an iOS bump (or collide).
Why not a separate counter: the date-style name + a ×10 code tells support which iOS build a bug report matches.
Rules: never reuse or lower a versionCode (Play rejects it); the first upload can start at any value — start at `1990`.
`KidIdentity.appVersion` already reports `"versionName (versionCode)"` on device rows, so the parent dashboard shows e.g. `2026.10.5 (1990)`.

Per release:
1. `android/app/build.gradle.kts` → `versionCode` / `versionName` per the table.
2. Release notes ("What's new") in he/en/ru/ar — reuse the iOS `WhatsNewContent` text, no emoji problems on Play (≤500 chars per language).
3. If the iOS memory rule "what's new every update" should hold on Android too, the Android What's-New popup needs the same `case` for the new versionCode (check `ui/settings` WHATS_NEW sheet).

## 2. Upload key (once)

```bash
mkdir -p ~/keys && cd ~/keys
keytool -genkeypair -v \
  -keystore tofy-upload.jks -storetype PKCS12 \
  -alias upload -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Rani Ophir, O=Tofy, L=Ramat Gan, C=IL"
# prints the fingerprints you'll need for Firebase:
keytool -list -v -keystore tofy-upload.jks -alias upload | grep -E "SHA1|SHA256"
```

- Store the `.jks` **outside the repo** (e.g. `~/keys/`), back it up (1Password / iCloud Drive encrypted). Losing it is recoverable (Play Console → App signing → Request upload key reset) but takes days.
- Passwords go into `~/.gradle/gradle.properties` (never into the repo):
  ```properties
  TOFY_UPLOAD_STORE_FILE=/Users/raniophir/keys/tofy-upload.jks
  TOFY_UPLOAD_STORE_PASSWORD=…
  TOFY_UPLOAD_KEY_ALIAS=upload
  TOFY_UPLOAD_KEY_PASSWORD=…
  ```
- Add to `android/app/build.gradle.kts` (not done — needs Rani's go-ahead, it changes the build):
  ```kotlin
  android {
      signingConfigs {
          create("upload") {
              val f = providers.gradleProperty("TOFY_UPLOAD_STORE_FILE").orNull
              if (f != null) {
                  storeFile = file(f)
                  storePassword = providers.gradleProperty("TOFY_UPLOAD_STORE_PASSWORD").get()
                  keyAlias = providers.gradleProperty("TOFY_UPLOAD_KEY_ALIAS").get()
                  keyPassword = providers.gradleProperty("TOFY_UPLOAD_KEY_PASSWORD").get()
              }
          }
      }
      buildTypes {
          release {
              // unsigned when the properties are absent (CI / other machines) — still builds
              if (providers.gradleProperty("TOFY_UPLOAD_STORE_FILE").isPresent)
                  signingConfig = signingConfigs.getByName("upload")
              isMinifyEnabled = true
              proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
          }
      }
  }
  ```

## 3. Play App Signing (once, at the first upload)

1. Play Console → Create app → name "טופי" / default language Hebrew (iw-IL) → App → **Free** → declarations.
2. First AAB upload (Internal testing is fine) → **"Use Google-generated key"** (default, recommended). Google keeps the app signing key; you only ever hold the upload key.
3. Play Console → Test and release → **App integrity → App signing** → copy the **App signing key certificate** SHA-1 and SHA-256 (and confirm the Upload key certificate matches step 2).

## 4. Firebase — register every signing certificate (Google sign-in breaks without this)

`android/app/google-services.json` currently has **no Android OAuth client** (only the web client, type 3), i.e. no SHA fingerprints are registered for `com.rani.tofy` in project `childtime-86e98`.

Firebase Console → Project settings → Your apps → **com.rani.tofy** → *Add fingerprint*, four times:
- debug keystore (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`) — SHA-1
- upload key — SHA-1 + SHA-256
- **Play app signing key** — SHA-1 + SHA-256 (from step 3 — this is the one real users' installs are signed with)

Then download the new `google-services.json` into `android/app/` and rebuild. Test Google sign-in from an **Internal testing** install (Play-signed), not only from a local build.

## 5. Build

```bash
cd /Users/raniophir/ChildTime/android
export JAVA_HOME=~/Android/jdk-17.0.20.1+1/Contents/Home
./gradlew clean bundleRelease          # → app/build/outputs/bundle/release/app-release.aab
# optional local APK for a sanity install on a phone:
./gradlew assembleRelease              # → app/build/outputs/apk/release/
```

- The AAB already carries the R8 mapping (`BUNDLE-METADATA/com.android.tools.build.obfuscation/proguard.map`), so Play Console de-obfuscates crash stack traces automatically — no separate upload.
- Before uploading, smoke-test a **release** build on a real device (R8 bugs only show up there): sign-in (Google + email), parent dashboard loads, add child, child device join via QR, a question round (content JSON parsing = kotlinx-serialization), chore photo, push arrives, the guard locks/unlocks.

## 6. R8 / ProGuard rules (`android/app/proguard-rules.pro` — written and verified)

What each library needs:

| Library | Needs project rules? | Why |
|---|---|---|
| Firebase Auth / Firestore / Messaging / Functions | No | Consumer rules ship in the AARs. We never use `toObject()` (all reads are Maps via `data/Fields.kt`) — if POJO mapping is ever added, keep those model classes. |
| Jetpack Compose / AndroidX / Navigation / Lifecycle | No | Consumer rules shipped. |
| kotlinx-serialization 1.7.3 | Mostly no (bundled since 1.5) | Explicit keeps for `com.rani.tofy` `@Serializable` companions/`$$serializer` added for R8 full mode (AGP 8 default). |
| Credential Manager (Google sign-in) | **Yes** | `androidx.credentials.playservices.**` is loaded reflectively — Google's documented rule. |
| zxing core + zxing-android-embedded | No | Pure Java; `CaptureActivity` kept via its manifest. `-dontwarn` added for safety. |
| Coil | No | Consumer rules shipped. |
| Our manifest components (TofyGuardService, TofyMessagingService) | No (AAPT keeps them) | Explicit keeps added so a rename can't break the reviewed accessibility service. |

Current file content:

```proguard
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** { *; }

-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers @kotlinx.serialization.Serializable class com.rani.tofy.** {
    static ** Companion;
    *** Companion;
    kotlinx.serialization.KSerializer serializer(...);
}
-keepclassmembers class com.rani.tofy.**$$serializer { *; }
-keepclasseswithmembers class com.rani.tofy.** {
    kotlinx.serialization.KSerializer serializer(...);
}

-keep class com.rani.tofy.kid.enforce.TofyGuardService { <init>(); }
-keep class com.rani.tofy.push.TofyMessagingService { <init>(); }

-dontwarn com.google.zxing.**
```

Verified in `app/build/outputs/mapping/release/mapping.txt`: `TofyGuardService`, `TofyMessagingService`, `MainActivity`, `TofyApp` and `CredentialProviderPlayServicesImpl` keep their names.

## 7. Before the FIRST upload — fixes found while preparing this (not done; outside this task's files)

1. **Target SDK.** `targetSdk = 35`. Google raises the requirement every August (API 35 from 31 Aug 2025; the 2026 step is expected to be **API 36 from 31 Aug 2026**). Check Play Console → Policy status / the upload warning. If 36 is required: AGP 8.7.3 → ≥ 8.9.1, `compileSdk`/`targetSdk = 36`, and re-test edge-to-edge, predictive back, and that the app is resizable on tablets (API 36 ignores orientation locks on ≥600 dp screens).
2. **Camera feature.** zxing-android-embedded adds `<uses-feature android:name="android.hardware.camera.any"/>` (required by default) → Play **hides Tofy from devices without a camera** (some tablets, Chromebooks — likely parent devices). Add to `AndroidManifest.xml`:
   `<uses-feature android:name="android.hardware.camera.any" android:required="false" tools:replace="android:required" />`
   and keep a code-entry fallback when there is no camera (the join flow already has "type the code").
3. **App-removal command is a no-op on Android** (see families-policy.md §6.2) — parent sees ✅, nothing unlocks.
4. **Lock-off push copy is iOS-only** (`functions/index.js` ~1136: "Screen Time access… Screen Time passcode") — wrong for an Android child device.
5. **Payments wording**: "הרכישה נעשית במכשיר של הילד, עם קוד ההורים" (ui/activity/HomeBanners.kt) and "download from the App Store" (ui/onboarding/ConnectScreens.kt) — see families-policy.md §6.4.
6. **Deep links**: `autoVerify="false"` — friend/join links open a chooser (or the browser). Publishing `https://tofyapp.com/.well-known/assetlinks.json` with the **Play app signing** SHA-256 and switching to `autoVerify="true"` makes them open Tofy directly. Note: `docs/` has `.nojekyll`, so a `.well-known` folder will be served.

## 8. Play Billing (being added in parallel — `billing/`, `verifyPlayPurchase`)

- Products to create in Play Console are listed in `billing/ProductIds.kt` (and the setup doc the billing work references, `docs/PLAY_BILLING_SETUP.md`): `tofy_plus_monthly` / `tofy_plus_yearly` (subscriptions), `stars_small|medium|large`, `pack_<id>` / `pack_<id>_sibling`, `pass_<topic>` / `pass_<topic>_sibling` (one-time, consumable). Products can only be created **after** an AAB containing the billing library has been uploaded to any track.
- A **payments profile / merchant account** is required to sell. For a personal developer account that sells, Google shows the developer's **address publicly** on the store page — the privacy policy already publishes it, but Rani should confirm that.
- Add the review account and Rani's testers under Settings → **License testing** so test purchases are free.
- R8: `billing-ktx` ships its own consumer rules; nothing to add to proguard-rules.pro.
- When billing ships: Data safety → Purchase history = collected; Content rating → digital purchases = Yes; add the Tofy+ block to the listings (listing-*.md).

## 9. Upload & roll out

1. Internal testing → install from Play on 2 devices (parent + child) → smoke test (§5).
2. Promote the same release to **Closed testing** (closed-testing.md) — 14 days, ≥12 testers.
3. Apply for production → staged rollout 20% → 50% → 100% while watching Android vitals (crash rate < 1.09%, ANR < 0.47%).
4. After each release: tag the commit `android-<versionName>-<versionCode>`.
