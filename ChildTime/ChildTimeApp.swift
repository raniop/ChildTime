import SwiftUI
import UIKit

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

/// Forwards the APNs device token from the system to PushManager, which hands
/// it to Firebase Messaging and uploads the resulting FCM token to the parent's
/// account. SwiftUI apps need this adaptor because remote-notification
/// callbacks are only delivered to a UIApplicationDelegate.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Firebase's recommended spot — runs at the UIKit entry point, before
        // any singleton touches Auth/Firestore, so the "default Firebase app has
        // not yet been configured" warning never fires.
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        #endif
        // Own notification handling from the very start so tapped action buttons
        // (e.g. "כן, העלו רמה") are delivered even on a cold launch.
        Task { @MainActor in
            UNUserNotificationCenter.current().delegate = PushManager.shared
            PushManager.shared.configureCategories()
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.didRegisterAPNs(deviceToken) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }
}

@main
struct ChildTimeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings: ParentSettings
    @StateObject private var progress: ProgressStore
    @StateObject private var shields: ShieldManager
    @StateObject private var auth: AuthManager
    @StateObject private var subs: SubscriptionManager
    @StateObject private var profiles: ProfileStore
    @StateObject private var cosmetics: CosmeticStore
    @Environment(\.scenePhase) private var scenePhase

    /// Animated welcome splash plays once per cold launch (never in screenshot
    /// mode). Starts true so it covers the very first frame.
    @State private var showSplash: Bool = (ProcessInfo.processInfo.environment["DEMO_SCREEN"] == nil)

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

        if Self.demoScreen != nil { Self.seedDemo() }
    }

    /// App Store screenshot mode — render a specific screen with sample data.
    /// Activated only via the DEMO_SCREEN launch env var; never in production.
    static var demoScreen: String? { ProcessInfo.processInfo.environment["DEMO_SCREEN"] }

    private static func seedDemo() {
        if ProfileStore.shared.profiles.isEmpty {
            let dana = Profile(name: "דָּנָה", gender: .girl, age: .grade1)
            ProfileStore.shared.add(dana)
            let yoav = Profile(name: "יוֹאָב", gender: .boy, age: .grade1)
            ProfileStore.shared.add(yoav)
            ProfileStore.shared.setActive(dana)
        }
        ProgressStore.shared.seedForDemo()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // A base layer in the brand gradient (matching the launch
                // screen + splash) so the first SwiftUI frame is the same blue
                // backdrop — never a flat purple or white flash.
                AppGradient.dreamy.ignoresSafeArea()
                if let demo = Self.demoScreen { demoRoot(demo) } else { ContentView() }

                // Animated welcome splash on top of the first frame, then it
                // fades away to reveal the app.
                if showSplash {
                    SplashScreenView { showSplash = false }
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
                .environment(\.layoutDirection, .rightToLeft)
                .environmentObject(settings)
                .environmentObject(progress)
                .environmentObject(shields)
                .environmentObject(auth)
                .environmentObject(subs)
                .environmentObject(profiles)
                .environmentObject(cosmetics)
                .task {
                    guard Self.demoScreen == nil else { return }   // no system prompts in screenshot mode
                    let role = settings.deviceRole == .parent ? "parent"
                             : settings.deviceRole == .child ? "child" : "unset"
                    AppAnalytics.setUserProperty(role, "device_role")
                    AppAnalytics.setSubscribed(subs.isPremium)
                    await shields.requestAuthorizationIfNeeded()
                    enforceShieldStateIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, Self.demoScreen == nil {
                        enforceShieldStateIfNeeded()
                    }
                }
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    // Google Sign-In returns control to the app via this URL.
                    if GIDSignIn.sharedInstance.handle(url) { return }
                    #endif
                    // A scanned join link (from the native Camera or a shared
                    // link): capture the code and start the child-join flow.
                    if JoinLink.isJoinURL(url) {
                        settings.pendingJoinPayload = JoinLink.payload(from: url.absoluteString)
                        if settings.deviceRole != .child { settings.deviceRole = .child }
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    // Universal Link opened from the native Camera / Safari.
                    if let url = activity.webpageURL, JoinLink.isJoinURL(url) {
                        settings.pendingJoinPayload = JoinLink.payload(from: url.absoluteString)
                        if settings.deviceRole != .child { settings.deviceRole = .child }
                    }
                }
        }
    }

    @ViewBuilder
    private func demoRoot(_ name: String) -> some View {
        switch name {
        case "question": QuestionRunnerView(mode: .smartFeed, purpose: .earnTime)
        case "wheel":    LuckyWheelView(onClose: {})
        case "dashboard": ParentDashboardView(isRoot: true)
        default:         WorldMapView()   // "worldmap"
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
            // Currently inside a full unlock window — make sure shield is OFF.
            shields.clearShield()
            return
        }
        // No active full unlock — clear a stale window if any.
        if progress.unlockEndsAt != nil {
            progress.endUnlock()
        }

        // A per-app allowance keeps the chosen apps open while the rest stay
        // locked. When it expires, drop it and re-apply the full shield.
        if settings.allowExceptionActive, let aData = settings.allowExceptionData {
            shields.applyShield(from: selection, allowing: SelectionStorage.decode(aData))
        } else {
            if settings.allowExceptionEndsAt != nil { settings.clearAllowException() }
            shields.applyShield(from: selection)
        }
    }
}
