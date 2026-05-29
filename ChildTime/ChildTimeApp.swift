import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct ChildTimeApp: App {
    @StateObject private var settings: ParentSettings
    @StateObject private var progress: ProgressStore
    @StateObject private var shields: ShieldManager
    @StateObject private var auth: AuthManager
    @StateObject private var subs: SubscriptionManager
    @StateObject private var profiles: ProfileStore
    @StateObject private var cosmetics: CosmeticStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if canImport(FirebaseCore)
        // MUST run before any singleton below is touched — several of them
        // (auth, progress, household sync) reach for Auth/Firestore in their
        // init, which warns "default Firebase app has not yet been configured"
        // if Firebase isn't up yet. Assigning the @StateObjects *inside* init,
        // after configure(), guarantees that ordering.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif

        _settings = StateObject(wrappedValue: ParentSettings.shared)
        _progress = StateObject(wrappedValue: ProgressStore.shared)
        _shields = StateObject(wrappedValue: ShieldManager.shared)
        _auth = StateObject(wrappedValue: AuthManager.shared)
        _subs = StateObject(wrappedValue: SubscriptionManager.shared)
        _profiles = StateObject(wrappedValue: ProfileStore.shared)
        _cosmetics = StateObject(wrappedValue: CosmeticStore.shared)
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
                .environmentObject(cosmetics)
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
