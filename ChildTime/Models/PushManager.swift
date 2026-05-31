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

    /// Persist the FCM token on the parent's record (array-union, multi-device).
    func uploadFCMToken(_ token: String) {
        currentToken = token
        #if canImport(FirebaseFirestore) && canImport(FirebaseMessaging)
        guard let uid = AuthManager.shared.userID else { return }
        Firestore.firestore()
            .collection("parents").document(uid)
            .setData(["fcmTokens": FieldValue.arrayUnion([token])], merge: true)
        #endif
    }
}

// MARK: - Interactive notification actions

extension PushManager {
    enum Category {
        /// A "strength" insight that offers to raise the child's level.
        static let insightLevelUp = "INSIGHT_LEVELUP"
    }
    enum Action {
        static let levelUpYes = "LEVELUP_YES"
        static let levelUpNo  = "LEVELUP_NO"
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
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    /// Apply a tapped "raise level" action: bump the named topic's difficulty by
    /// one step and confirm back with a short follow-up notification.
    func handleLevelUpDecision(_ actionID: String, userInfo: [AnyHashable: Any]) {
        guard actionID == Action.levelUpYes else { return }  // "no"/default → nothing
        guard let raw = userInfo["topic"] as? String, let topic = Topic(rawValue: raw) else { return }

        let levels: [Difficulty] = [.easy, .medium, .hard]
        let current = ParentSettings.shared.difficulty(for: topic)
        guard let idx = levels.firstIndex(of: current) else { return }
        let next = levels[min(levels.count - 1, idx + 1)]
        let changed = next != current
        if changed { ParentSettings.shared.setDifficulty(next, for: topic) }

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
        }
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
