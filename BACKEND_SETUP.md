# ChildTime — Backend Setup (Parent Platform)

The Parent Experience platform ships with backend artifacts in this repo. The
**iOS code is complete**, but these pieces must be **deployed by you** (they need
your Firebase project + Apple Developer account). Each is optional to compile —
the app builds and runs without them, degrading gracefully.

## 1. Firestore security rules  (`firestore.rules`)

Enforce family data separation (a parent can only touch children in a household
that lists their uid).

```bash
firebase deploy --only firestore:rules
```

Data model created by the app:

```
parents/{uid}                               account, fcmTokens, consent
households/{householdID}                     parentUIDs[], childIDs[]
children/{childID}                           name, age, grade, interests, level, householdID
children/{childID}/state/current             ProgressSnapshot (synced progress)
children/{childID}/dailyStats/{YYYY-MM-DD}   daily learning history
children/{childID}/events/{autoID}           live events (push triggers)
invites/{CODE}                               co-parent join codes
weeklyReports/{childID}/weeks/{date}         generated weekly summaries
```

## 2. Cloud Functions  (`functions/`)

Live-event push + the weekly report job.

```bash
cd functions && npm install && cd ..
firebase deploy --only functions
```

- `sendLiveEvent` → on a new `children/{id}/events` doc, pushes to the *other*
  parents in the household (session start, milestone, streak, wheel, discovery,
  assist request).
- `weeklyReport` → Mondays 18:00 Asia/Jerusalem, writes `weeklyReports` and pushes a digest.

## 3. Push notifications (APNs + FCM)

1. **Xcode**: add the **Push Notifications** capability to the `ChildTime` target,
   and **Background Modes → Remote notifications**.
2. **SPM**: add the **FirebaseMessaging** product to the target. `PushManager` /
   `AppDelegate` light up automatically (they're behind `#if canImport(FirebaseMessaging)`).
3. **Apple Developer**: create an **APNs Auth Key (.p8)** and upload it in
   Firebase Console → Project Settings → Cloud Messaging.
4. Add an `AppDelegate` to forward the APNs token (snippet below).

```swift
// In ChildTimeApp.swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ app: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        Task { @MainActor in PushManager.shared.didRegisterAPNs(token) }
    }
}
```

The parent enables notifications from **Parent Settings → התראות להורה**.

## 4. Firebase Auth providers

In Firebase Console → Authentication → Sign-in method, enable:
- **Apple**, **Google** (already used), and **Email/Password** (new).
- (Optional) **Phone** for 2FA / multi-factor — the `twoFactorEnabled` flag on
  `parents/{uid}` is reserved for the enrollment UI (future).

## Notes
- Everything is **opt-in / additive**: without deploy, sync still works on the
  legacy paths' successor (`children/{id}/state`), analytics/coaching run fully
  on-device, and the app never crashes for lack of a backend.
- Data export & full deletion run client-side; deletion also cascades Firestore
  via `HouseholdManager.deleteAllData()`.
