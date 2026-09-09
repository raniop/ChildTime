import Foundation
import FamilyControls
import ManagedSettings
import os.log

/// 🔑 Screen Time tokens expire.
///
/// The `ApplicationToken`s behind the parent's block-list are opaque handles
/// that iOS invalidates over time (a re-install, an app update, a restore). An
/// expired token silently stops matching its app: the shield still *looks*
/// applied in Tofy, the parent believes the device is locked, and the child
/// opens YouTube. Nothing in the app could detect it — until iOS 26.5 added a
/// notification and a refresh call.
///
/// This listens for the expiry notification, re-mints every selection we store,
/// and re-applies the shield so enforcement continues without the parent ever
/// knowing something was about to break. On older systems it does nothing at
/// all, and the app behaves exactly as before.
@MainActor
final class TokenRefresher {
    static let shared = TokenRefresher()
    private var observer: NSObjectProtocol?
    private var lastRefreshAt: Date?

    private init() {}

    /// Start listening. Safe to call more than once.
    func start() {
        guard #available(iOS 26.5, *) else { return }
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: ManagedSettingsStore.TokenExpiryMessage.name,
            object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                screenTimeLog.notice("[TokenRefresher] iOS reported expired tokens — re-minting")
                TokenRefresher.shared.refreshNow(reason: "expiry-notification")
            }
        }
        screenTimeLog.notice("[TokenRefresher] listening for token expiry")
        // A device that was asleep when the notification fired would never hear
        // it, so sweep once at launch too.
        refreshNow(reason: "launch")
    }

    /// Re-mint every stored selection and re-apply the shield.
    /// Throttled: a sweep more than once a minute is always redundant.
    func refreshNow(reason: String) {
        guard #available(iOS 26.5, *) else { return }
        if let last = lastRefreshAt, Date().timeIntervalSince(last) < 60 { return }
        lastRefreshAt = Date()

        let s = ParentSettings.shared
        var changed = false
        for (label, keyPath) in Self.selectionKeyPaths {
            guard let data = s[keyPath: keyPath] else { continue }
            var selection = SelectionStorage.decode(data)
            guard Self.refresh(&selection, label: label) else { continue }
            s[keyPath: keyPath] = SelectionStorage.encode(selection)
            changed = true
        }
        guard changed else { return }
        // Re-apply so the freshly minted tokens actually take effect. Only when
        // the shield is supposed to be up — never re-lock a child mid-window.
        if !ProgressStore.shared.isUnlocked {
            ShieldManager.shared.applyShield(from: SelectionStorage.decode(s.activitySelectionData))
        }
        screenTimeLog.notice("[TokenRefresher] refreshed (\(reason, privacy: .public)) — shield re-applied")
    }

    /// Every place a parent's app/category choice is persisted.
    private static let selectionKeyPaths: [(String, ReferenceWritableKeyPath<ParentSettings, Data?>)] = [
        ("blocked", \.activitySelectionData),
        ("allowed", \.allowedAppsData),
        ("alwaysAllowed", \.alwaysAllowedAppsData),
        ("allowException", \.allowExceptionData),
    ]

    /// Re-mint one selection in place. Returns true if anything actually moved.
    @available(iOS 26.5, *)
    private static func refresh(_ selection: inout FamilyActivitySelection, label: String) -> Bool {
        var moved = false
        var apps = Array(selection.applicationTokens)
        if !apps.isEmpty {
            do {
                let before = apps.count
                try ManagedSettingsStore.refresh(&apps)
                let fresh = Set(apps)
                // Never let a refresh SHRINK the parent's list — a dropped token
                // means an app quietly stops being blocked. Keep the old set and
                // let the next sweep try again.
                guard apps.count == before, fresh.count == selection.applicationTokens.count else {
                    screenTimeLog.error("[TokenRefresher] \(label, privacy: .public) applicationTokens: refresh changed the count — keeping the old set")
                    throw CocoaError(.coderInvalidValue)
                }
                if fresh != selection.applicationTokens { selection.applicationTokens = fresh; moved = true }
            } catch {
                screenTimeLog.error("[TokenRefresher] \(label, privacy: .public) apps: \(error.localizedDescription, privacy: .public)")
            }
        }
        var cats = Array(selection.categoryTokens)
        if !cats.isEmpty {
            do {
                let before = cats.count
                try ManagedSettingsStore.refresh(&cats)
                let fresh = Set(cats)
                // Never let a refresh SHRINK the parent's list — a dropped token
                // means an app quietly stops being blocked. Keep the old set and
                // let the next sweep try again.
                guard cats.count == before, fresh.count == selection.categoryTokens.count else {
                    screenTimeLog.error("[TokenRefresher] \(label, privacy: .public) categoryTokens: refresh changed the count — keeping the old set")
                    throw CocoaError(.coderInvalidValue)
                }
                if fresh != selection.categoryTokens { selection.categoryTokens = fresh; moved = true }
            } catch {
                screenTimeLog.error("[TokenRefresher] \(label, privacy: .public) categories: \(error.localizedDescription, privacy: .public)")
            }
        }
        var webs = Array(selection.webDomainTokens)
        if !webs.isEmpty {
            do {
                let before = webs.count
                try ManagedSettingsStore.refresh(&webs)
                let fresh = Set(webs)
                // Never let a refresh SHRINK the parent's list — a dropped token
                // means an app quietly stops being blocked. Keep the old set and
                // let the next sweep try again.
                guard webs.count == before, fresh.count == selection.webDomainTokens.count else {
                    screenTimeLog.error("[TokenRefresher] \(label, privacy: .public) webDomainTokens: refresh changed the count — keeping the old set")
                    throw CocoaError(.coderInvalidValue)
                }
                if fresh != selection.webDomainTokens { selection.webDomainTokens = fresh; moved = true }
            } catch {
                screenTimeLog.error("[TokenRefresher] \(label, privacy: .public) webDomains: \(error.localizedDescription, privacy: .public)")
            }
        }
        return moved
    }
}
