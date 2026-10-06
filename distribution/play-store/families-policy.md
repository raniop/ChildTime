# Google Play — Target audience, Families, Ads, Accessibility & permissions

> Play Console → Policy and programs → **App content**. Fill these in this order — the first closed-test
> review will not start until every App content item is green.
> Code facts verified on 2026-10-06 against android/app (manifest, kid/enforce/*, merged release manifest).

---

## 1. Target audience and content

| Question | Answer | Notes |
|---|---|---|
| Target age groups | **6–8, 9–12** (core) **+ 13–15** (grades ז׳–ח׳) **+ 18 and over** (parents) | Content runs כיתה א׳–ח׳. Do **not** tick "5 and under" unless Rani wants the גן content to be a selling point — it adds nothing policy-wise but invites a stricter look at the parent gate. (Open question.) |
| Does the store listing unintentionally appeal to children? | n/a — children are a target audience | |
| Families policy | **I have read and will comply** | Applies to the whole app because ages under 13 are selected. |
| Is the app designed for families / children? | Yes → the app is reviewed under the **Families policy**. | |
| Teacher Approved | Nothing to fill — it is chosen by Google's reviewers. Eligible only when the app is in the Families program, has no ads/out-links reachable by kids without a gate, and the content is high quality. Tofy's best case; don't promise it. | |

### Families policy — how Tofy meets each requirement

| Requirement | Tofy (Android) | Status |
|---|---|---|
| No ads / only Families-certified ad SDKs | No ad SDK at all. | ✅ |
| No AAID, Android ID, IMEI, MAC, serial, SSID, BSSID, SIM from kids or unknown-age users | Merged release manifest has **no** `AD_ID`; code never reads those IDs. The only device IDs are the FCM token and a random install UUID. | ✅ |
| No location from kids | No location permission. | ✅ |
| Privacy policy linked in the listing and in the app | Listing (Store settings → Privacy policy URL = https://tofyapp.com/privacy) + Settings row "מדיניות פרטיות". | ✅ (but see data-safety.md §4 — the policy must describe Android) |
| Legal compliance (COPPA / GDPR-K) — verifiable parental consent | Parent signs in, sees the consent screen (`AccountRepository.recordConsent`), creates every child. A child device can only join from a parent's QR / code. | ✅ |
| Permissions only as needed | INTERNET, CAMERA (QR + chore photo), POST_NOTIFICATIONS, PACKAGE_USAGE_STATS (parent-granted fallback). Photo picker without READ_MEDIA. No SYSTEM_ALERT_WINDOW, no QUERY_ALL_PACKAGES, no Device Admin, no foreground service. | ✅ |
| Purchases behind a parental gate | Play Billing is being added (`billing/`): every purchase goes through `BillingParentGate` = the parent code, re-asked on every open (respectSession:false twin), also on a parent phone. Without billing, the kid's 💎 packs show "בְּקָרוֹב בְּאַנְדְּרוֹאִיד". | ✅ — re-check on the final build that no price is visible to a child before the gate |
| Links out of the app from kid screens | Privacy/terms/support links are on parent screens only. | ✅ verify on the kid home before review |
| **Social features** (friends leaderboard, "All players" board, live quiz) | Not free-form (no chat, no photos, no text) — but Google's rule for apps with kids in the audience is: (a) an **in-app reminder about online safety** before a child shares information, (b) a way for **adults to manage** the social feature (enable/disable), (c) **adult action** before a child exchanges personal information. Today: parents can see and remove friends, but there is **no on/off switch**, **no kid-facing safety reminder**, and the "All players" board shows the child's first name to any signed-in user without a parent action. | ⚠️ **Risk #1** — see §6 |

---

## 2. Ads

**Does your app contain ads? → No.**
(No ad SDK, no house ads to other apps. Admin "campaigns" are push notifications about Tofy's own worlds to **parents** only — not ads in Play's sense, but keep them off child devices.)

## 3. Advertising ID

**Does your app use advertising ID? → No.** (Confirmed: the merged release manifest has no `com.google.android.gms.permission.AD_ID`.)

## 4. App access (instructions for the reviewer)

Choose **"All or some functionality is restricted"** and add:

```
Tofy has two roles. A parent signs in on the parent's device; a child's device joins that family.

PARENT (test account — please use this):
  Email: [create e.g. playreview@tofyapp.com — Rani creates it, the password goes only into this Play form]
  Password: [ … ]
  1. Open Tofy → "המכשיר שלי (הורה)" / "My device (parent)" → Sign in with email.
  2. The dashboard shows a test child "Dana" with progress, chores and devices.
  Parent code (protects settings): 1234

CHILD DEVICE (optional, needs a second Android device or emulator):
  1. On the parent device: Dana's card → "Connect a device" → a QR code and a short code appear.
  2. On the second device: Tofy → "Who uses this device?" → "Your child learns and plays" → scan the QR or type the code.
  3. "Parent only" setup: the screen explains the Accessibility service → "Agree and continue"
     → turn on Tofy in Settings → Accessibility → return. Now every app except Tofy, Phone and
     the home screen is locked until Dana earns time by answering questions.
  4. Device settings and the uninstall screen open only with the parent code (1234):
     Tofy gear → parent code → "Open device settings for 10 minutes".

The app language follows the device; English, Hebrew, Russian and Arabic are supported.
```

> The review account must have a household with a premium/gift period so every world is reachable (the reviewer can't buy on Android). Rani: create it on a parent device, add a child "Dana", and gift it from the admin (`adminGiftHousehold`).

---

## 5. Accessibility API declaration

Play Console → App content → **Accessibility API** (appears after uploading a build that declares an AccessibilityService).

**Is the app an accessibility tool (isAccessibilityTool)?** → **No.** (Matches `res/xml/tofy_guard_service.xml`: `isAccessibilityTool="false"`.)

**Core functionality category:** Parental control.

**Describe how your app uses the AccessibilityService API** (paste):

```
Tofy is a parental-control and learning app. On a child's dedicated device, a parent enables Tofy's accessibility service so Tofy can lock other apps until the child earns screen time by answering learning questions.

The service subscribes only to TYPE_WINDOW_STATE_CHANGED events to learn which app has just come to the foreground (package name). It has canRetrieveWindowContent="false", performs no gestures and reads no text, fields, messages or passwords. If the foreground app is not on the parent's "always open" list and no earned play time is running, Tofy returns to the home screen and shows its own lock card (TYPE_ACCESSIBILITY_OVERLAY). The package name is used in memory on the device for this decision only; it is never stored, logged or transmitted. The only state reported to the family is whether the lock is on or off.

On the child's device, the device Settings app and the system uninstall dialog are treated as parent-only, so a child cannot disable the parental control; a parent unlocks them with the parent code ("Open device settings for 10 minutes"). This is the parental-control exception in the Accessibility API policy ("unless authorized by a parent or guardian through a parental control app").

Before redirecting to Accessibility settings, Tofy shows a prominent in-app disclosure on a parent-only screen explaining what the service does and does not do, with an affirmative "Agree and continue" button and a "Continue without the lock" option. The service can be turned off at any time in Settings → Accessibility.
```

**Video link:** an unlisted YouTube video (or a Drive link set to "anyone with the link"), ≤ 2–3 minutes — script below.

### Demo video — exact recording script

Record on a **real Android phone** with the built-in Screen recorder (Quick Settings → Screen record → "Record audio: off", "Show touches: on"). Set the phone language to **English** first (Settings → System → Languages), so the reviewer can read every screen. Use the review test account. Start from Tofy **uninstalled**. A second device (the parent phone) is only needed for scene 7.

| # | Scene (what to tap) | What must be visible / say in a caption |
|---|---|---|
| 1 | Install Tofy from the closed-testing link. Open it → "Who uses this device?" → **"Your child learns and plays"**. | Role picker. |
| 2 | On the parent phone: Dana → Connect device → QR. On the child phone: scan it (or type the code). | Child joins the family — shows the parent set it up. |
| 3 | The **"Parent only"** lock setup opens → the **disclosure screen** "Before turning on the lock". **Scroll slowly through all of it** (what Tofy does / doesn't do). Pause 3 s. | This is the prominent disclosure; it must be on screen **before** any Settings redirect. |
| 4 | Tap **"Agree and continue"**. Android Accessibility settings open → Downloaded apps → **Tofy** → toggle on → the system "Allow Tofy full control?" dialog → **Allow**. Press back to Tofy. | Affirmative consent + the user turning it on themselves. |
| 5 | "✓ The lock is on". Next step: **Usage access** → tap → Settings → Tofy → allow → back. Then **"What stays open"** → pick Clock → Save → Done. | Optional permission, parent choice. |
| 6 | **The feature:** go Home → open **YouTube** → Tofy's lock card appears and the phone returns home. Open **Clock** → it opens (allowed). Open Tofy → answer 3–4 questions → open the earned minutes → open YouTube → it plays. (Optional: a 1-minute window that ends → YouTube is covered again.) | The core use of the API. |
| 7 | Try to open **Settings** → locked. Tofy gear → parent code → **"Open device settings for 10 minutes"** → Settings → Accessibility → Tofy → **turn it off**. Show the parent phone's notification "🔓 Tofy's lock was turned off on Dana's phone". | Can be disabled at any time; parent is informed; nothing else is sent. |
| 8 | (Optional, if GUARD_UNINSTALL stays true) Long-press Tofy → Uninstall → lock card; then with the 10-minute settings window open → Uninstall works. | Shows uninstall is parent-authorized, not impossible. |

Edit nothing except trimming waits. Upload as **unlisted** to YouTube (not private — reviewers can't see private videos).

---

## 6. Risk notes (read before submitting)

1. **Social features (Families policy) — highest risk.** Fix before production, ideally before the closed test:
   - a parent switch "Friends & leaderboards" (default: on with consent, or off) on the child's settings;
   - a one-time kid-facing reminder before the first friend add / leaderboard ("Only share your nickname. Never share where you live or your phone number.") — in vowelled Hebrew, gentle;
   - consider hiding the **"All players"** tab on Android, or showing initials there.
   This is a product decision (iOS has the same features) — see open questions.
2. **Uninstall guard (`kid/enforce/AllowList.GUARD_UNINSTALL = true`).** The Accessibility API policy bans preventing uninstall *unless authorized by a parent through a parental control app* — Tofy fits that exception, but only if it is **disclosed**. Today the in-app disclosure mentions Settings ("הגדרות המכשיר נפתחות לילד רק עם קוד ההורה") but **not uninstall**. Add "ואת מסך הסרת האפליקציות" to that line (and to `tofy_guard_description`), and keep the declaration text above. If review still objects: flip `GUARD_UNINSTALL` to `false` (the parent still gets the "lock turned off" push).
   - ⚠️ **Bug found:** the parent's remote action "אַפְשֵׁר מְחִיקַת אַפְּלִיקַצְיוֹת (5 דַּק')" (ui/home/ActionsSheet.kt) is **acknowledged** by an Android child device (parent sees ✅) but does nothing: `KidSync.applyRemoteAppRemovalIfNeeded` emits `KidEvent.AppRemovalWindow`, which `KidExperience` ignores and the guard never reads. On Android it should call `EnforcementStore.allowTemporarily(ctx, AllowList.settingsPackages(ctx), 5)` (or the action should be hidden for Android child devices). A reviewer who tries "allow deleting apps" and still can't uninstall = rejection.
3. **Usage access (PACKAGE_USAGE_STATS).** There is no Play declaration form for it today. It is a parent-granted special access, used only as a fallback right after the guard reconnects, never leaves the device → **not** declared in Data safety (on-device only). If the Console ever asks ("Sensitive permissions"), paste:
   ```
   PACKAGE_USAGE_STATS is granted by a parent in Settings → Usage access on a child's device that runs Tofy's parental lock. Right after the device restarts or the lock reconnects, Tofy reads which app was last in the foreground so it can lock it immediately (accessibility events only report changes). It is optional, read on the device only, never stored or transmitted.
   ```
4. **Payments policy.** The parent's "wants Tofy+" banner says "הרכישה נעשית במכשיר של הילד, עם קוד ההורים" — fine once Play Billing ships on the child device (it is then a Play purchase); in a build **without** billing it points to a purchase made elsewhere (iOS), which Play forbids for digital content. Also: never mention App Store prices or "buy on iPhone" anywhere in the Android app. Families with Tofy+ bought on iOS may keep using it on Android (allowed: content bought elsewhere may be consumed). Same for the parent onboarding steps that say "download Tofy from the App Store" (ui/onboarding/ConnectScreens.kt:182, :314) — on Android, say "Google Play or the App Store".
5. **Review account must reach everything.** Reviewers can't complete a real purchase; locked worlds with no way in are filed as "broken functionality". Make the review family premium/gifted (see §4) and add a license-tester entry for the review email (Play Console → Settings → License testing) so they can try the purchase sheet without being charged.
6. **Kids see the lock card over other apps.** Its copy must stay gentle (no failure language) — it is the Android twin of the iOS shield; fine today.
7. **Server push copy is iOS-only.** When an Android child device's lock is switched off, `functions/index.js` (~line 1136) sends "Tofy's Screen Time access was switched off … allow Screen Time. A Screen Time passcode…" — wrong on Android (it is the Accessibility service, and the fix is the parent code). Branch on the device row's kind/OS before the video in scene 7 is recorded, or the reviewer sees iOS instructions.
8. **Store-listing statements must match the app**: "no chat, no photos" between users — true (chore photos go only to the family's parents).
