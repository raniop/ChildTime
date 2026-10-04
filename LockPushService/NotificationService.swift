import UserNotifications
import ManagedSettings
import FamilyControls
import Foundation
import os.log

/// Same subsystem/category as the app's `screenTimeLog` so Console.app shows the
/// app, the DeviceActivity monitor, and this service together.
private let lockLog = Logger(subsystem: "com.rani.ChildTime", category: "ScreenTime")

/// Notification SERVICE extension — runs the moment a `mutable-content` push
/// arrives, even when Tofy itself was force-quit. This is the reliability
/// backstop for the parent's remote lock: the old silent-wake path depended on
/// iOS deigning to wake the app (it often doesn't — Low Power Mode, force-quit,
/// plain throttling), which is why "נעל טלפון" sometimes only worked after the
/// kid reopened Tofy. A visible high-priority push + this extension applies the
/// shield within seconds of the parent's tap.
///
/// Firestore remains the source of truth: the app still consumes `remoteLockAt`
/// and writes the ack on its next wake — this extension only makes the PHYSICAL
/// lock immediate. A lock is the safe-side action, so applying it here without
/// cross-checking stamps is correct; if a newer unlock exists, the app's
/// stamp-ordered reconciliation restores it on next launch.
class NotificationService: UNNotificationServiceExtension {

    private let appGroupID = TofyShield.appGroupID

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttempt: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttempt = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if (request.content.userInfo["type"] as? String) == "remote-lock" {
            lockLog.notice("nse: remote-lock push → applying shield now")
            applyShieldNow()
            // Diagnostics stamp for the app (and a tripwire in Console).
            UserDefaults(suiteName: appGroupID)?
                .set(Date().timeIntervalSince1970, forKey: "nseLockAppliedAt")
        }

        // 🧹📸 Chore-done push with a proof photo — fetch it (token-gated URL,
        // served by the chorePhoto function) and attach, so the parent sees the
        // tidy room right in the notification. Any failure falls back to the
        // plain text push; serviceExtensionTimeWillExpire covers a hung fetch.
        // 📣 A campaign push with an image uses the same path (imageURL).
        if let urlString = (request.content.userInfo["photoURL"] as? String)
                            ?? (request.content.userInfo["imageURL"] as? String),
           let url = URL(string: urlString) {
            attachPhoto(from: url, to: request)
            return
        }

        contentHandler(bestAttempt ?? request.content)
    }

    private func attachPhoto(from url: URL, to request: UNNotificationRequest) {
        URLSession.shared.downloadTask(with: url) { [weak self] tmpURL, _, _ in
            guard let self, let handler = self.contentHandler else { return }
            defer { handler(self.bestAttempt ?? request.content) }
            guard let tmpURL else { return }
            // UNNotificationAttachment needs a file the system can claim, with a
            // type-revealing extension.
            let ext = ["png", "gif", "jpeg", "jpg"].first { url.pathExtension.lowercased() == $0 } ?? "jpg"
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "." + ext)
            do {
                try FileManager.default.moveItem(at: tmpURL, to: dest)
                let attachment = try UNNotificationAttachment(identifier: "chorePhoto", url: dest)
                self.bestAttempt?.attachments = [attachment]
            } catch {
                lockLog.error("nse: chore photo attach failed: \(error.localizedDescription)")
            }
        }.resume()
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttempt { contentHandler(bestAttempt) }
    }

    /// The out-of-app re-lock path for a parent's remote lock.
    private func applyShieldNow() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

        // A remote lock ends any open window — clear the marker like the
        // monitor extension does when it re-locks.
        defaults.removeObject(forKey: "unlockEndsAt")

        // One brain for all three processes (see `ShieldPolicy.swift`). This was
        // a third hand-written copy of the policy, with the same hole: its
        // block-list branch could not cover an app the child installed after the
        // parent picked their list. `TofyShield.relock` also owns
        // `denyAppRemoval` and honors the parent's delete window.
        TofyShield.relock(reason: "lock-push", log: lockLog)
    }
}
