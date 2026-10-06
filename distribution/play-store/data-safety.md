# Google Play — Data safety form (Tofy, com.rani.tofy)

> Play Console → Policy and programs → App content → **Data safety**.
> Every answer here comes from reading the Android code (android/app/src/main/java/com/rani/tofy/**),
> `functions/index.js`, `firestore.rules` and the live privacy policy (docs/en/privacy.html), on 2026-10-06.
> Rule used throughout: data that is processed **only on the device** is not "collected" (Google's definition),
> and transfers to **service providers** (Google Firebase / Gmail) are not "sharing".

---

## Step 1 — Data collection and security

| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes** | Parent account, child profile, progress, chore photos, push tokens. |
| Is all of the user data collected by your app encrypted in transit? | **Yes** | Every call goes through the Firebase SDKs (Auth, Firestore, Functions, FCM) over TLS; the chore-photo URL is `https://…cloudfunctions.net/chorePhoto`. No cleartext HTTP anywhere (no `usesCleartextTraffic`). |
| Which account creation methods does your app support? | **Username and password** + **OAuth** | Email + password (`AuthRepository.register`), Google sign-in via Credential Manager. Child devices get an anonymous Firebase account that is created by joining a parent's family (QR / code) — not a user-facing sign-up. |
| Delete account URL | **https://tofyapp.com/delete-account** (page to create — draft below). Fallback until it exists: `https://tofyapp.com/en/support` (it has a "How do I delete data?" answer, but Google wants a page whose main purpose is deletion). | Play requires a web link that works without reinstalling the app. |
| Can users request deletion of some data without deleting the account? | **Yes** | Delete one child's profile from the child's card; remove a friend; chore photos auto-delete (≤7 days); email request to the privacy contact. |
| Committed to the Play Families Policy? | **Yes** (shown once Target audience includes children) | |
| Independent security review (MASA)? | **No** | Optional. |

### In-app deletion path (to quote anywhere Google asks)
Parent device → ⚙️ Settings → **"מחק את כל הנתונים שלי" / "Delete all my data"** → type the confirmation word → (re-sign-in if Firebase asks) → the household, every child, progress, chores, friend cards and device rows are deleted from the cloud, then the Firebase account itself (`SettingsRepository.deleteEverything` → `AuthRepository.deleteAccount`).

---

## Step 2 — Data types

Legend: **C** = collected · **S** = shared · **Eph** = processed ephemerally · **Req** = required or optional.

### Personal info

| Type | C | S | Eph | Req | Purposes | What exactly (source) |
|---|---|---|---|---|---|---|
| **Name** | ✅ | ❌ | No | Required | App functionality, Account management | Parent display name (`parents/{uid}.displayName`, from Google or sign-up form); child first name / nickname (`children/{id}.name`), shown to the family and on friend cards. |
| **Email address** | ✅ | ❌ | No | Required (parent accounts) | App functionality, Account management | Parent sign-in email (`parents/{uid}.email`). Also used for the 18-month inactivity deletion notice (account management, via Gmail as service provider). Child devices have no email. |
| **User IDs** | ✅ | ❌ | No | Required | App functionality, Account management, Fraud prevention / security | Firebase UID, household ID, child ID, friend code; security rules gate every read by household membership. |
| **Address / Phone / Race / Political / Religious / Sexual orientation** | ❌ | | | | | |
| **Other info** | ✅ | ❌ | No | Required | App functionality, Personalization | Child's grade, approximate age, gender (used only so Hebrew/Arabic/Russian copy addresses the child correctly), chosen character; household time zone (`households/{hid}.timeZone`, for day boundaries). |

### Financial info

> ⚠️ Play Billing is being added in parallel (`android/app/src/main/java/com/rani/tofy/billing/`, `billing-ktx 7.1.1`, `verifyPlayPurchase` in functions). Answer for the build you actually upload.

| Type | C | S | Eph | Req | Purposes | What |
|---|---|---|---|---|---|---|
| **Purchase history** | ✅ *(build with billing)* / ❌ *(build without)* | ❌ | No | Optional | App functionality, Fraud prevention / security | Product id, purchase token, order dates and the household id (`obfuscatedAccountId`) are sent to our `verifyPlayPurchase` function, which checks them with Google and writes the entitlement (`households.premiumUntil`, packs, 💎). |
| Payment info / credit score / other financial info | ❌ | | | | | Card details are handled entirely by Google Play; we never see them. |

### Location
**Not collected.** No location permission. The household time zone is not location under Google's definition (approximate location = ≥3 km² area); IP addresses are processed by Google's servers to deliver data but never used to derive location.

### Health and fitness · Messages (email/SMS) · Audio · Files and docs · Calendar · Contacts · Web browsing
**Not collected.** (No RECORD_AUDIO — read-aloud is on-device TextToSpeech output only. No contacts, no SMS, no browser.)

### Messages

| Type | C | S | Eph | Req | Purposes | What |
|---|---|---|---|---|---|---|
| **Other in-app messages** | ✅ | ❌ | No | Optional | App functionality | Free-text feedback a **parent** sends to the developer (`parentFeedback`: message, app version, locale, UID). Children cannot send any free text to anyone. |

### Photos and videos

| Type | C | S | Eph | Req | Purposes | What |
|---|---|---|---|---|---|---|
| **Photos** | ✅ | ❌ | No | Optional | App functionality | Chore proof photo a child may attach (camera or the system photo picker, ≤900 px JPEG) — stored on that chore, visible only to the family's parents, deleted when the parent approves/archives it and after 7 days at most (`pruneChorePhotos`). Android parents can't add a profile photo; profile photos added on iOS are only displayed. |
| Videos | ❌ | | | | | |

### App activity

| Type | C | S | Eph | Req | Purposes | What |
|---|---|---|---|---|---|---|
| **App interactions** | ✅ | ❌ | No | Required | App functionality, Personalization, **Analytics** (see note) | Questions answered and results, stars/diamonds, minutes earned and play windows, daily learning history, chores done/approved, help requests to a parent, live-quiz answers and score, leaderboard star count. |
| In-app search history | ❌ | | | | | |
| **Installed apps** | ❌ | | | | | **On-device only.** The accessibility guard sees the foreground package name in memory to decide lock/open; the "what stays open" picker lists launchable apps locally (`EnforcementStore`, SharedPreferences). Neither is ever written to Firestore or sent anywhere. Only the boolean "lock is on" leaves the device (`childDevices.shieldAuthorized`). |
| **Other user-generated content** | ✅ | ❌ | No | Optional | App functionality | Chore titles/rewards a parent types; question reports ("this question is wrong" + reason + child's first name). |
| **Other actions** | ✅ | ❌ | No | Required | App functionality | Device-control events: remote lock/unlock commands and their acks, "parent code opened on the child device", lock switched on/off, time gifts / transfers. |

> **Note on "Analytics":** the app has **no analytics SDK** (no Firebase Analytics, no Crashlytics — verify `app/build.gradle.kts`). But the founder dashboard (`refreshAdminStats`, `adminJourney`, funnel) computes first-party aggregate numbers from the same Firestore data. Google counts any use of collected data "to analyze how users use the app" as the Analytics *purpose*, regardless of who does it. Declaring it is the safe side; it does **not** mean "third-party analytics". (Decision for Rani — see open questions.)

### App info and performance

| Type | C | S | Eph | Req | Purposes | What |
|---|---|---|---|---|---|---|
| Crash logs | ❌ | | | | | No Crashlytics. (Play Console's own vitals come from Android, not from the app.) |
| Diagnostics | ❌ | | | | | |
| **Other app performance data** | ✅ | ❌ | No | Required | App functionality | App version, Android version and device model / user-set device name on each connected-device row (`childDevices`, so the parent sees "Pixel 7 · last seen"). |

### Device or other IDs

| Type | C | S | Eph | Req | Purposes | What |
|---|---|---|---|---|---|---|
| **Device or other IDs** | ✅ | ❌ | No | Required | App functionality, Developer communications | FCM registration token (`parents/{uid}.fcmTokens`, device rows) and a random per-install UUID (`kid.installID`, reset on reinstall). **No** Android ID, advertising ID, IMEI, MAC, serial or SSID — none are read (Families policy forbids transmitting those from children). |

> "Developer communications" = the admin campaigns that push **parents** about new worlds/packs (`dispatchCampaigns`). If those pushes ever carry promotional offers, Google may read that as "Advertising or marketing" — keep campaigns parent-only and informational, or add that purpose.

---

## Step 3 — Data sharing: **none declared**

Why each transfer is not "sharing":
- **Google Firebase (Auth, Firestore, Functions, FCM) and Gmail** — service providers processing on our behalf (exempt).
- **Friend cards / leaderboards / live quiz** — a child's first name or nickname, character and star count become visible to other Tofy users only after a user action (adding a friend, opening the leaderboard, joining a quiz). Google exempts "user-initiated" transfers the user reasonably expects. ⚠️ Judgment call: the **"All players" global leaderboard** shows the card to any signed-in user. If a reviewer disagrees, declare *Name* + *App interactions* as **Shared** (purpose: App functionality). See families-policy.md for the bigger issue this raises.

---

## Step 4 — Privacy policy vs. the Android app: mismatches

The live policy (docs/en/privacy.html, updated 2026-09-11; docs/privacy.html in Hebrew; plus ru/ar) was written for iOS. **Fix before the Android app goes to production** — Play reviewers read the policy against the Data safety form.

| # | Policy says | Android reality | Fix |
|---|---|---|---|
| 1 | "This policy covers the Tofy app for iPhone and iPad (incl. Apple Watch + widgets)" | Android app exists | Add "and Android phones and tablets". |
| 2 | Device permissions = Notifications, Camera, Screen Time / Family Controls | Android uses **Accessibility service**, **Usage access** (PACKAGE_USAGE_STATS), Camera, Notifications, the system **photo picker** | New Android paragraph (draft below). |
| 3 | "App blocking runs through Apple's Screen Time framework … we don't receive a list of the apps your child uses" | True in substance on Android too, but via a different mechanism | Say it explicitly for Android (draft below). |
| 4 | "Parent code: stored hashed **on the device** and never sent as plain text" | The code is a salted SHA-256 hash stored in the cloud at `households/{hid}.parentPinHash` (that is how a child device verifies it, `kid/ui/ParentGate.kt`) — iOS does the same | Reword: "stored only as a salted hash (in the family's record), never as plain text". **Applies to iOS too.** |
| 5 | "Purchases are processed by Apple. We receive a record of the transaction" | Android purchases (being added) go through **Google Play Billing**; we receive the purchase token/product/dates and verify them server-side | "Purchases are processed by Apple (iPhone/iPad) or Google Play (Android)…" — and add Google Play to the service-provider list. |
| 6 | Parents can "Export my data (JSON)" from Parent settings | **No export on Android** (SettingsScreen.kt says so) | Add "(on iPhone/iPad; on Android, ask us by email and we'll send it)" — or port the export. |
| 7 | Child profile = first name/nickname, grade, approximate age, character | Also **gender** (iOS too) | Add "and whether to address the child as a boy or a girl (for grammar in Hebrew, Arabic and Russian)". |
| 8 | Service providers: Google (Firebase, Gmail) and Apple | On Android: Google sign-in through Google Play services / Credential Manager; push via FCM directly | Add "On Android, Google Play services handles Google sign-in and push delivery." |
| 9 | "turn notifications off at any time in iOS Settings" | Android: Settings → Apps → Tofy → Notifications | "in your device's settings". |
| 10 | "In line with the App Store Kids category rules, the Firebase Analytics component is not included" | Also not included on Android (true) | Add "and Google Play's Families policy". |
| 11 | Hebrew page (docs/privacy.html, 12.9) is a short version and lacks COPPA, consent, sharing/friends, IP, retention-for-friends, etc. | — | Not Android-specific, but a Hebrew-first app whose Hebrew policy is thinner than the English one is a review risk. Bring he (and check ru/ar) to parity with en. |

Note: `docs/privacy-policy.html` is only a redirect to `privacy.html`; the paragraphs below belong in **docs/en/privacy.html** (section "Device permissions" + "What we don't collect"), **docs/privacy.html**, and the ru/ar pages.

### Proposed text — English (for docs/en/privacy.html, "Device permissions")

> **On Android**
> - **Accessibility service (child's device only).** To keep other apps locked until your child earns time, Tofy uses Android's Accessibility service on the child's device. A parent turns it on after an in-app explanation and can turn it off at any time in Settings → Accessibility. The service only learns which app has just come to the front, so Tofy can decide whether it is open or locked and, if locked, show Tofy's lock screen over it. It does not read what is on the screen, cannot see messages, passwords or anything typed, and never types or taps. The name of the app is used on the device for that decision only — it is not stored, and it is never sent to us or to anyone. The only thing reported to the family is whether the lock is on or was turned off.
> - **Usage access (optional, child's device only).** If a parent grants it, Tofy reads which app was most recently in front right after the phone restarts, so the lock applies immediately. This stays on the device and is never stored or sent.
> - **Uninstall and device settings.** On a child's device, Android's Settings and the uninstall screen open only with the parent code, so a child cannot switch the lock off. Parents can always open them from Tofy, and can uninstall Tofy at any time.
> - **Photos.** A child can pick a chore photo with Android's photo picker, which shares only the one photo chosen; Tofy does not get access to the photo library.
> - **Device information.** Each connected device's name or model, Android version and Tofy version appear in the parent's device list.
> We don't use the advertising ID, Android ID, IMEI, MAC address or any other hardware identifier.

### Proposed text — Hebrew (for docs/privacy.html, "הרשאות מכשיר")

> **באנדרואיד**
> - **שירות הנגישות (רק במכשיר של הילד).** כדי לנעול את שאר האפליקציות עד שהילד מרוויח זמן, טופי משתמש בשירות הנגישות של אנדרואיד במכשיר של הילד. ההורה מפעיל אותו אחרי הסבר באפליקציה, ויכול לכבות אותו בכל רגע בהגדרות ← נגישות. השירות יודע רק איזו אפליקציה נפתחה עכשיו, כדי שטופי יחליט אם היא פתוחה או נעולה, ואם היא נעולה — יציג מעליה את מסך הנעילה של טופי. הוא לא קורא את מה שכתוב על המסך, לא רואה הודעות, סיסמאות או כל דבר שמוקלד, ולא מקליד או לוחץ במקומכם. שם האפליקציה משמש רק להחלטה הזאת במכשיר עצמו — הוא לא נשמר ולא נשלח אלינו או לאף אחד. למשפחה מדווחים רק אם הנעילה פועלת או כובתה.
> - **גישה לנתוני שימוש (אופציונלי, רק במכשיר של הילד).** אם ההורה מאשר, טופי בודק איזו אפליקציה הייתה פתוחה אחרונה מיד אחרי שהמכשיר נדלק מחדש, כדי שהנעילה תחול מיד. המידע נשאר במכשיר, לא נשמר ולא נשלח.
> - **הסרת האפליקציה והגדרות המכשיר.** במכשיר של הילד, ההגדרות של אנדרואיד ומסך הסרת האפליקציה נפתחים רק עם קוד ההורה, כדי שהילד לא יוכל לכבות את הנעילה. ההורה תמיד יכול לפתוח אותם מתוך טופי ולהסיר את טופי בכל עת.
> - **תמונות.** ילד יכול לבחור צילום למטלה דרך בוחר התמונות של אנדרואיד, שמעביר רק את התמונה שנבחרה; לטופי אין גישה לגלריה.
> - **פרטי המכשיר.** שם המכשיר או הדגם, גרסת אנדרואיד וגרסת טופי של כל מכשיר מחובר מופיעים ברשימת המכשירים של ההורה.
> איננו משתמשים במזהה הפרסום, ב-Android ID, ב-IMEI, בכתובת MAC או בכל מזהה חומרה אחר.

### Proposed page — https://tofyapp.com/delete-account (for the Data safety "Delete account URL")

> **Delete your Tofy account and data**
> **In the app (fastest):** on the parent's phone or tablet, open Tofy → Settings (⚙️) → **Delete all my data** → type the confirmation word. This deletes your family, every child profile, progress and learning history, chores and photos, friend cards and connected-device records from our servers, and then your account. It can't be undone.
> **To delete one child only:** parent dashboard → the child's card → ⋯ → Delete.
> **Without the app:** email **ranioph@gmail.com** (or hello@tofyapp.com) from the address you sign in with, with the subject "Delete my Tofy account". We verify that the request comes from the family's parent and delete within 30 days.
> **What is kept:** nothing from your family, except that our database's rolling recovery window keeps deleted data for up to 7 days before it is gone for good.
