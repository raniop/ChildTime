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
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        authorized = granted
        guard granted else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized
    }

    /// Called by the AppDelegate when APNs returns a device token.
    func didRegisterAPNs(_ deviceToken: Data) {
        #if canImport(FirebaseMessaging)
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

extension PushManager: UNUserNotificationCenterDelegate {
    // Show notifications even when the parent has the app in the foreground.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
