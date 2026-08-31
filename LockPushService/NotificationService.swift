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

    private let store = ManagedSettingsStore(named: .init("childtime.shield"))
    private let appGroupID = "group.com.childtime.shared"

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
        if let urlString = request.content.userInfo["photoURL"] as? String,
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
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".jpg")
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

    /// Mirror of DeviceActivityMonitorExtension.reapplyShield() — the proven
    /// out-of-app re-lock path (same named store, same app-group keys). Kept in
    /// sync by hand; if you change one, change the other.
    private func applyShieldNow() {
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let decoder = JSONDecoder()

        // A remote lock ends any open window — clear the marker like the
        // monitor extension does when it re-locks.
        defaults.removeObject(forKey: "unlockEndsAt")

        // Keep app DELETION blocked — deleting Tofy would wipe the shield.
        // EXCEPTION: honor a parent's short "allow deletion" window (see the
        // monitor extension) — a late-arriving lock push must not silently
        // re-block an uninstall the parent just enabled.
        let removalWindow = defaults.object(forKey: "appRemovalUnlockedUntil") as? Date
        if let removalWindow, removalWindow > Date() {
            store.application.denyAppRemoval = nil
        } else {
            store.application.denyAppRemoval = true
        }

        // Block-all-except-allowlist mode — only when an allowlist actually exists
        // (otherwise we'd shield Tofy itself and brick the device).
        let blockAll = (defaults.object(forKey: "blockAllExceptAllowed") as? Bool) ?? true
        if blockAll,
           let allowedData = defaults.data(forKey: "allowedAppsData"),
           let allowed = try? decoder.decode(FamilyActivitySelection.self, from: allowedData),
           !(allowed.applicationTokens.isEmpty && allowed.categoryTokens.isEmpty && allowed.webDomainTokens.isEmpty) {
            store.shield.applications = nil
            store.shield.applicationCategories = .all(except: allowed.applicationTokens)
            store.shield.webDomains = nil
            store.shield.webDomainCategories = .all(except: allowed.webDomainTokens)
            lockLog.notice("nse: applied block-all shield")
            return
        }

        guard let data = defaults.data(forKey: "activitySelection"),
              let selection = try? decoder.decode(FamilyActivitySelection.self, from: data) else {
            lockLog.error("nse: no activitySelection to apply — shield NOT restored")
            return
        }

        // Honor an ACTIVE temporary parent exception (unexpired per-app allowance).
        var allowedApps: Set<ApplicationToken> = []
        if let endsAt = defaults.object(forKey: "allowExceptionEndsAt") as? Date, endsAt > Date(),
           let exData = defaults.data(forKey: "allowExceptionData"),
           let exSel = try? decoder.decode(FamilyActivitySelection.self, from: exData) {
            allowedApps = exSel.applicationTokens
        }

        // Permanent "always allowed" whitelist — never re-shielded.
        if let alwaysData = defaults.data(forKey: "alwaysAllowedAppsData"),
           let alwaysSel = try? decoder.decode(FamilyActivitySelection.self, from: alwaysData) {
            allowedApps.formUnion(alwaysSel.applicationTokens)
        }

        let blockedApps = selection.applicationTokens.subtracting(allowedApps)
        store.shield.applications = blockedApps.isEmpty ? nil : blockedApps
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? .none
            : .specific(selection.categoryTokens, except: allowedApps)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = .none
        lockLog.notice("nse: applied block-list shield (\(blockedApps.count, privacy: .public) apps blocked)")
    }
}
