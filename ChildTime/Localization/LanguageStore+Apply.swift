import Foundation
import WidgetKit

/// 🌍 Everything that has to hear about a language change, in one place.
///
/// The in-app picker and the remote switch a parent throws from their own phone
/// both land here, so the two can never drift apart — which is exactly how the
/// widgets once kept showing Hebrew after the app had moved on.
extension LanguageStore {

    static func reloadEverythingOutsideTheApp() {
        WidgetCenter.shared.reloadAllTimelines()
        ShieldBridge.refresh()
        WatchBridge.shared.resendLastSnapshot()
        // …and notifications: their buttons, and what the server sends.
        PushManager.shared.configureCategories()
        if let token = PushManager.shared.currentToken { PushManager.shared.uploadFCMToken(token) }
    }

    /// Record the choice on the child this device belongs to, stamped so the
    /// merge can tell it apart from an older parent-side write.
    ///
    /// Only a CHILD device does this: on a parent's phone the picker changes the
    /// parent's own app, and writing it onto whichever child happens to be
    /// selected would silently re-language that child's iPad.
    static func stampActiveChild(_ language: AppLanguage) {
        let settings = ParentSettings.shared
        guard settings.deviceRole == .child,
              let boundID = settings.joinedChildID,
              var profile = ProfileStore.shared.profiles.first(where: { $0.id.uuidString == boundID }),
              profile.language != language.rawValue else { return }
        profile.language = language.rawValue
        profile.languageUpdatedAt = .now
        ProfileStore.shared.update(profile)
    }
}
