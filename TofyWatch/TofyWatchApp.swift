import SwiftUI
import UserNotifications

/// ⌚️ Tofy on the wrist — a tiny PARENT companion. Two jobs:
/// 1. A glanceable family screen (data pushed from the iPhone over
///    WatchConnectivity — no Firebase on the watch).
/// 2. A rich notification scene for chore approvals: mirrored notifications
///    can't show image attachments, so this scene downloads the proof photo
///    itself (the `photoURL` travels in the push payload) and renders it with
///    the approve button underneath.
@main
struct TofyWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        WKNotificationScene(controller: ChoreNotificationController.self,
                            category: "CHORE_APPROVAL")
    }
}
