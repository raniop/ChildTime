import Foundation
import Combine
import UserNotifications
import UIKit

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Handles parent-device push: notification permission, APNs/FCM token
/// registration, and writing the token to the parent's account so the
/// `sendLiveEvent` Cloud Function can target it.
///
/// The FCM-specific code is compiled only when FirebaseMessaging is in the
/// build (add it via SPM — see BACKEND_SETUP.md). Until then, this still
/// requests permission and registers for remote notifications.
@MainActor
final class PushManager: NSObject, ObservableObject {
    static let shared = PushManager()

    @Published private(set) var authorized = false
    /// This device's FCM token, cached so live-events can exclude the playing
    /// device (the parent's other device still gets notified, even on the same
    /// account).
    @Published private(set) var currentToken: String?

    /// Ask the parent for notification permission, then register with APNs.
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        configureCategories()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        authorized = granted
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized
    }

    /// Prompt for permission ONLY if the user hasn't decided yet. Safe to call on
    /// every launch / screen-appear: a child device that was registered before we
    /// ever asked gets the system prompt now, an already-authorized device just
    /// re-registers its token, and anyone who declined is left alone (no nagging).
    func requestAuthorizationIfNotDetermined() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined:
            await requestAuthorization()                 // shows the iOS prompt
        case .authorized, .provisional, .ephemeral:
            authorized = true
            UIApplication.shared.registerForRemoteNotifications()   // refresh token
        default:
            authorized = false                           // .denied → respect it
        }
    }

    /// Self-test: ensures permission + a token, then writes a `pushTests` doc that
    /// the `sendTestPush` Cloud Function turns into a real push back to THIS
    /// device. If it arrives, the whole APNs→FCM path works.
    @discardableResult
    func sendTestPush() async -> String {
        await requestAuthorization()
        guard authorized else { return "צריך לאשר התראות קודם" }
        UIApplication.shared.registerForRemoteNotifications()
        #if canImport(FirebaseFirestore)
        guard let uid = AuthManager.shared.userID else { return "אין משתמש מחובר" }
        do {
            try await Firestore.firestore().collection("pushTests").addDocument(data: [
                "uid": uid,
                "createdAt": Date().timeIntervalSince1970
            ])
            return "נשלחה בקשת בדיקה — ההתראה אמורה להגיע תוך כמה שניות"
        } catch {
            return "שגיאה: \(error.localizedDescription)"
        }
        #else
        return "Firestore לא זמין"
        #endif
    }

    /// Called by the AppDelegate when APNs returns a device token.
    func didRegisterAPNs(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().delegate = self
        Messaging.messaging().apnsToken = deviceToken
        Messaging.messaging().token { [weak self] token, _ in
            if let token { self?.uploadFCMToken(token) }
        }
        #endif
    }

    /// Persist the FCM token, SEPARATED BY DEVICE ROLE so notifications target the
    /// right audience:
    ///  • PARENT device → `fcmTokens` (family broadcasts: a kid started/finished,
    ///    reports, help — `sendLiveEvent`/`weeklyReport` read ONLY this).
    ///  • CHILD device → `childFcmTokens` (kid-to-kid is ONLY live-game invites,
    ///    which read this).
    /// A child's token must NOT sit in `fcmTokens`, or a sibling's device would get
    /// the parent's "started playing" notifications. We also remove the token from
    /// the OTHER field in case this device changed role.
    func uploadFCMToken(_ token: String) {
        currentToken = token
        #if canImport(FirebaseFirestore) && canImport(FirebaseMessaging)
        guard let uid = AuthManager.shared.userID else { return }
        let isChild = ParentSettings.shared.deviceRole == .child
        let mine  = isChild ? "childFcmTokens" : "fcmTokens"
        let other = isChild ? "fcmTokens" : "childFcmTokens"
        let ref = Firestore.firestore().collection("parents").document(uid)
        ref.setData([mine: FieldValue.arrayUnion([token])], merge: true)
        ref.updateData([other: FieldValue.arrayRemove([token])])   // move if role changed
        // ALSO stamp the token on this device's own childDevices row, so Cloud
        // Functions can target THIS child's device(s) precisely (the account-level
        // childFcmTokens list is family-wide — a lock push through it reached
        // siblings' devices too).
        if isChild, let cid = ParentSettings.shared.joinedChildID {
            let docID = "\(cid)_\(DeviceIdentity.installID)"
            Firestore.firestore().collection("childDevices").document(docID)
                .setData(["fcmToken": token], merge: true)
        }
        #endif
    }
}

// MARK: - Interactive notification actions

extension PushManager {
    enum Category {
        /// A "strength" insight that offers to raise the child's level.
        static let insightLevelUp = "INSIGHT_LEVELUP"
        /// A child asked for help — interactive notification with the two answer
        /// options as buttons (rendered by HelpContentExtension). Must match the
        /// extension's `UNNotificationExtensionCategory`.
        static let parentHelp = "PARENT_HELP"
    }
    enum Action {
        static let levelUpYes = "LEVELUP_YES"
        static let levelUpNo  = "LEVELUP_NO"
        /// The parent kept option A / option B from a help notification.
        static let helpOptionA = "HELP_OPT_A"
        static let helpOptionB = "HELP_OPT_B"
    }

    /// Register interactive notification categories so the strength-insight push
    /// shows "כן, העלו רמה" / "לא" buttons. Safe to call repeatedly.
    func configureCategories() {
        let yes = UNNotificationAction(
            identifier: Action.levelUpYes,
            title: "👑 כן, העלו רמה",
            options: [])
        let no = UNNotificationAction(
            identifier: Action.levelUpNo,
            title: "לא, להשאיר",
            options: [])
        let cat = UNNotificationCategory(
            identifier: Category.insightLevelUp,
            actions: [yes, no],
            intentIdentifiers: [],
            options: [])

        // Parent-help: two answer buttons. The titles here are only a fallback
        // (collapsed banner); HelpContentExtension replaces them with the real
        // option texts when the notification is expanded. Actions are NOT
        // `.foreground` — the tap is handled in the background, no app launch.
        let optA = UNNotificationAction(identifier: Action.helpOptionA, title: "אפשרות א׳", options: [])
        let optB = UNNotificationAction(identifier: Action.helpOptionB, title: "אפשרות ב׳", options: [])
        let helpCat = UNNotificationCategory(
            identifier: Category.parentHelp,
            actions: [optA, optB],
            intentIdentifiers: [],
            options: [])

        UNUserNotificationCenter.current().setNotificationCategories([cat, helpCat])
    }

    /// Apply the parent's tapped answer: the option they kept stays on the child's
    /// screen, the other is removed. Written to the `helpRequests/{id}` doc, which
    /// the child's app is listening to — all in the background, no app launch.
    ///
    /// MUST be awaited from `didReceive`: a tapped non-foreground action only wakes
    /// the app briefly in the background. A fire-and-forget `setData` would just be
    /// queued locally and the app could suspend before it ever reaches the server,
    /// so the child's listener would never fire. Awaiting the write keeps the
    /// background task alive until Firestore confirms it.
    func handleParentHelpDecision(_ actionID: String, userInfo: [AnyHashable: Any]) async {
        guard actionID == Action.helpOptionA || actionID == Action.helpOptionB else { return }
        guard let requestID = userInfo["helpRequestID"] as? String else { return }
        let optionA = (userInfo["optionA"] as? String) ?? ""
        let optionB = (userInfo["optionB"] as? String) ?? ""
        let keptA = (actionID == Action.helpOptionA)
        let kept = keptA ? optionA : optionB
        let removed = keptA ? optionB : optionA
        guard !kept.isEmpty, !removed.isEmpty else { return }

        #if canImport(FirebaseFirestore)
        do {
            try await Firestore.firestore().collection("helpRequests").document(requestID).setData([
                "keptOption": kept,
                "removedOption": removed,
                "status": "answered",
                "respondedByUID": AuthManager.shared.userID ?? "",
                "respondedAt": Date().timeIntervalSince1970,
            ], merge: true)
        } catch {
            print("[ParentHelp] write-back failed: \(error.localizedDescription)")
            return
        }
        #endif

        // Quietly confirm to the parent.
        let childName = (userInfo["childName"] as? String) ?? "הילד"
        let content = UNMutableNotificationContent()
        content.title = "✅ הָעֶזְרָה נִשְׁלְחָה"
        content.body = "עָזַרְתָּ לְ\(childName) — נִשְׁאֲרָה הָאֶפְשָׁרוּת \(kept)."
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "help.confirm.\(requestID)", content: content, trigger: nil))
    }

    /// Apply a tapped "raise level" action: bump the named topic's difficulty by
    /// one step and confirm back with a short follow-up notification.
    func handleLevelUpDecision(_ actionID: String, userInfo: [AnyHashable: Any]) {
        guard actionID == Action.levelUpYes else { return }  // "no"/default → nothing
        guard let raw = userInfo["topic"] as? String, let topic = Topic(rawValue: raw) else { return }

        // Difficulty is per-child — bump THIS child's level for the topic and sync
        // it to their device. The notification carries the child's id.
        let idStr = (userInfo["childID"] as? String) ?? ""
        guard let cid = UUID(uuidString: idStr),
              var profile = ProfileStore.shared.profiles.first(where: { $0.id == cid }) else { return }

        let levels: [Difficulty] = [.easy, .medium, .hard]
        let current = profile.difficulty(for: topic)
        guard let idx = levels.firstIndex(of: current) else { return }
        let next = levels[min(levels.count - 1, idx + 1)]
        let changed = next != current
        if changed {
            profile.difficultyByTopic[topic.rawValue] = next.rawValue
            ProfileStore.shared.update(profile)
        }

        let name = (userInfo["childName"] as? String) ?? "הילד"
        let content = UNMutableNotificationContent()
        if changed {
            content.title = "👑 עָלִינוּ רָמָה!"
            content.body = "מֵעַכְשָׁיו \(name) יְקַבֵּל שְׁאֵלוֹת בְּרָמָה \(next.displayName) יוֹתֵר בְּ\(topic.displayName). תָּמִיד אֶפְשָׁר לְשַׁנּוֹת בַּהַגְדָּרוֹת."
        } else {
            content.title = "כְּבָר בָּרָמָה הַגְּבוֹהָה 💪"
            content.body = "\(name) כְּבָר מְקַבֵּל אֶת הַשְּׁאֵלוֹת הֲכִי מְאַתְגְּרוֹת בְּ\(topic.displayName)."
        }
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "levelup.confirm.\(topic.rawValue)",
            content: content,
            trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

extension PushManager: UNUserNotificationCenterDelegate {
    // Show notifications even when the parent has the app in the foreground.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Handle a tapped action button (e.g. "כן, העלו רמה").
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let actionID = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        await MainActor.run {
            PushManager.shared.handleLevelUpDecision(actionID, userInfo: info)
            // A tapped live-game invite → remember the game id; the home screen
            // joins it as soon as the app is active.
            if info["type"] as? String == "liveGameInvite",
               let gameID = info["gameID"] as? String {
                LiveGameManager.shared.pendingGameID = gameID
            }
        }
        // Awaited (not fire-and-forget) so the Firestore write-back completes
        // before iOS suspends the briefly-woken background app — otherwise the
        // child's listener never sees the parent's answer.
        await PushManager.shared.handleParentHelpDecision(actionID, userInfo: info)
    }
}

#if canImport(FirebaseMessaging)
extension PushManager: MessagingDelegate {
    // FCM tokens can refresh at any time — upload the new one so pushes keep
    // reaching this device.
    nonisolated func messaging(_ messaging: Messaging,
                               didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in self.uploadFCMToken(fcmToken) }
    }
}
#endif
