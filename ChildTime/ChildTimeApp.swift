import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct ChildTimeApp: App {
    @StateObject private var settings = ParentSettings.shared
    @StateObject private var progress = ProgressStore.shared
    @StateObject private var shields = ShieldManager.shared
    @StateObject private var auth = AuthManager.shared
    @StateObject private var subs = SubscriptionManager.shared
    @StateObject private var profiles = ProfileStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if canImport(FirebaseCore)
        // Safe to call once at launch. No-op if GoogleService-Info.plist is missing
        // (will print a console warning, but won't crash the app).
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.layoutDirection, .rightToLeft)
                .environmentObject(settings)
                .environmentObject(progress)
                .environmentObject(shields)
                .environmentObject(auth)
                .environmentObject(subs)
                .environmentObject(profiles)
                .task {
                    await shields.requestAuthorizationIfNeeded()
                    enforceShieldStateIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        enforceShieldStateIfNeeded()
                    }
                }
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    // Google Sign-In returns control to the app via this URL.
                    _ = GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
    }

    /// Decides whether the shield should be on or off based on current unlock window.
    /// If the unlock window has expired or never started → ensure shield is on.
    /// If the unlock window is still active → keep shield off.
    private func enforceShieldStateIfNeeded() {
        guard shields.isAuthorized else { return }
        guard let data = settings.activitySelectionData else { return }
        let selection = SelectionStorage.decode(data)

        if progress.isUnlocked {
            // Currently inside an unlock window — make sure shield is OFF.
            shields.clearShield()
        } else {
            // No active unlock — make sure shield is ON.
            // (This also re-applies after an unlock window has expired.)
            if progress.unlockEndsAt != nil {
                progress.endUnlock()
            }
            shields.applyShield(from: selection)
        }
    }
}
