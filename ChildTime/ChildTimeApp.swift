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
        // (e.g. "כן, העלו רמה" / "✅ בוצע — אשרו") are delivered even on a cold
        // launch FROM the action. didFinishLaunching is already on the main
        // actor, so set the delegate SYNCHRONOUSLY — a deferred Task could let
        // the action be delivered before the delegate exists and get dropped.
        MainActor.assumeIsolated {
            UNUserNotificationCenter.current().delegate = PushManager.shared
            PushManager.shared.configureCategories()
        }
        // Cold launch via the "מצב ילד" Quick Action.
        if let sc = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem,
           sc.type == KidModeManager.shortcutType {
            Task { @MainActor in KidModeManager.shared.pendingEntry = true }
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

    /// SILENT push ("wake"): a parent issued a command (±minutes, gift, reset,
    /// revoke, remote lock/unlock). The Firestore listeners are already attached
    /// on a child device — we just need the app to be AWAKE for a few seconds so
    /// they fire and the command applies (a backgrounded app otherwise only
    /// caught up when the kid reopened Tofy — useless for a remote LOCK).
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let type = userInfo["type"] as? String ?? ""
        // "wake" = silent command wake. "remote-lock" = the visible lock push
        // (its content-available also lands here when the app is backgrounded);
        // the NSE already applied the shield — this drain lets the Firestore
        // listener consume `remoteLockAt`, close the play window, and ACK.
        guard type == "wake" || type == "remote-lock" else { completionHandler(.noData); return }
        Task { @MainActor in
            TofyLink("silent wake push (\(userInfo["reason"] as? String ?? "")) — letting listeners drain")
            // Firestore delivers pending snapshots on wake; give them a moment.
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            completionHandler(.newData)
        }
    }

    // Home-screen Quick Action ("מצב ילד") while the app is already running.
    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        let handled = shortcutItem.type == KidModeManager.shortcutType
        if handled {
            Task { @MainActor in KidModeManager.shared.pendingEntry = true }
        }
        completionHandler(handled)
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
    @StateObject private var characters: CharacterStore
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
        _characters = StateObject(wrappedValue: CharacterStore.shared)

        if Self.demoScreen != nil { Self.seedDemo() }
        // Live Activity "עצור ושמור": iOS may launch the app HEADLESS to run the
        // intent — the root view's .task never runs then. Register here so the
        // request is applied immediately (apps re-lock) instead of on next open.
        if Self.demoScreen == nil {
            // A previous DEMO run seeded fake profiles/progress into local
            // storage. A NORMAL launch on the same install must wipe them
            // BEFORE any sync starts — this is exactly how demo "דנה/יואב"
            // once leaked into a production household.
            Self.purgeDemoLeftoversIfNeeded()
            StopAndSaveBridge.start()
            StopAndSaveBridge.applyIfRequested()
        }
    }

    /// App Store screenshot mode — render a specific screen with sample data.
    /// Activated only via the DEMO_SCREEN launch env var; never in production.
    static var demoScreen: String? { ProcessInfo.processInfo.environment["DEMO_SCREEN"] }

    /// Profiles seeded by a DEMO_SCREEN run — recorded so the next NORMAL
    /// launch on this install wipes them before any sync starts.
    private static let demoSeededIDsKey = "demo.seededProfileIDs"

    private static func seedDemo() {
        if ProfileStore.shared.profiles.isEmpty {
            let dana = Profile(name: "דָּנָה", gender: .girl, age: .grade1)
            ProfileStore.shared.add(dana)
            let yoav = Profile(name: "יוֹאָב", gender: .boy, age: .grade1)
            ProfileStore.shared.add(yoav)
            ProfileStore.shared.setActive(dana)
            UserDefaults.standard.set([dana.id.uuidString, yoav.id.uuidString],
                                      forKey: demoSeededIDsKey)
        }
        ProgressStore.shared.seedForDemo()
        if Self.demoScreen == "leaderboard" { FriendsManager.shared.seedDemo() }
    }

    /// A previous DEMO run left fake profiles + progress in local storage; a
    /// normal launch would otherwise sync them into a REAL production family
    /// (the leaked "דנה/יואב" household). Runs before any cloud sync starts.
    private static func purgeDemoLeftoversIfNeeded() {
        let d = UserDefaults.standard
        guard let raw = d.stringArray(forKey: demoSeededIDsKey), !raw.isEmpty else { return }
        NSLog("[Demo] purging %d demo-seeded profiles left by a DEMO_SCREEN run", raw.count)
        for r in raw {
            if let id = UUID(uuidString: r) { ProfileStore.shared.purgeDemoProfile(id) }
        }
        ProgressStore.shared.resetAll()   // demo run seeds only on an EMPTY device
        d.removeObject(forKey: demoSeededIDsKey)
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
                .environmentObject(characters)
                .task {
                    guard Self.demoScreen == nil else { return }   // no system prompts in screenshot mode
                    StopAndSaveBridge.start()                // Live Activity "עצור ושמור" listener
                    StopAndSaveBridge.applyIfRequested()     // handle a request that raced launch
                    let role = settings.deviceRole == .parent ? "parent"
                             : settings.deviceRole == .child ? "child" : "unset"
                    AppAnalytics.setUserProperty(role, "device_role")
                    AppAnalytics.setSubscribed(subs.isPremium)
                    // Screen Time (Family Controls) is only needed where apps get
                    // shielded: a CHILD device. A parent's own phone must not be
                    // prompted — and neither may a FRESH install still on the
                    // role picker (role .unset counted as "not parent" and the
                    // scary system dialog popped before the family chose
                    // anything). Prompt ONLY on an actual child device; parent
                    // flows that need it (Kid Mode, quick-open) ask themselves.
                    if settings.deviceRole == .child {
                        await shields.requestAuthorizationIfNeeded()
                    } else {
                        shields.refreshStatus()
                    }
                    progress.applyDailyRolloverIfNeeded()   // release minutes banked for "tomorrow"
                    enforceShieldStateIfNeeded()
                }
                .onChangeCompat(of: scenePhase) { _, phase in
                    if phase == .active, Self.demoScreen == nil {
                        progress.applyDailyRolloverIfNeeded()
                        StopAndSaveBridge.applyIfRequested()   // Live Activity "עצור ושמור" fallback
                        enforceShieldStateIfNeeded()
                        WidgetBridge.refreshKid()
                    }
                    // Child LEFT the app → send the single "finished playing" report
                    // now (covers all adventures this sitting). Self-guards: no-op if
                    // nothing was played. NOT fired per-adventure, which spammed the parent.
                    if phase == .background, Self.demoScreen == nil {
                        progress.endSittingAndReport()
                        // Flush the debounced (~3s) snapshot upload BEFORE iOS
                        // suspends us: a kid who stops play and immediately leaves
                        // Tofy otherwise keeps the parent's dashboard stale (a
                        // frozen 💝 leftover showed "—" until Tofy's next launch).
                        // Same role guard as the debounced path — a parent monitor
                        // device must never push its own local state.
                        if ParentSettings.shared.deviceRole != .parent || KidModeManager.shared.active {
                            RemoteSyncManager.shared.pushNow()
                        }
                        // Re-lock the parent gate when the app leaves the foreground.
                        ParentSettings.shared.sessionUnlocked = false
                        WidgetBridge.refreshKid()
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
                        // Detect parent-vs-child + confirm BEFORE changing anything —
                        // never silently flip an existing parent device into a child.
                        JoinCoordinator.shared.present(url.absoluteString)
                    } else if FriendLink.isFriendURL(url) {
                        // A friend invite link → remember the code; the leaderboard
                        // adds it the next time the child opens it.
                        FriendsManager.shared.pendingFriendCode = FriendLink.code(from: url.absoluteString)
                    } else if GameLink.isGameURL(url) {
                        // A live-game invite → remember the id; the home screen joins.
                        LiveGameManager.shared.pendingGameID = GameLink.id(from: url.absoluteString)
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    // Universal Link opened from the native Camera / Safari.
                    guard let url = activity.webpageURL else { return }
                    if JoinLink.isJoinURL(url) {
                        // Detect parent-vs-child + confirm BEFORE changing anything —
                        // never silently flip an existing parent device into a child.
                        JoinCoordinator.shared.present(url.absoluteString)
                    } else if FriendLink.isFriendURL(url) {
                        FriendsManager.shared.pendingFriendCode = FriendLink.code(from: url.absoluteString)
                    } else if GameLink.isGameURL(url) {
                        LiveGameManager.shared.pendingGameID = GameLink.id(from: url.absoluteString)
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
            .onAppear { if let id = ProfileStore.shared.activeID { HouseholdManager.shared.seedDemoLiveWindow(childID: id) } }
        case "starshop": StarShopView()   // DEMO_SCREEN=starshop (+ STARSHOP_DEMO=1 for sample packs)
        case "paywall":  PaywallView()    // DEMO_SCREEN=paywall — the "טופי+" subscription screen (App Review proof)
        case "unlocked": UnlockedView().onAppear { ProgressStore.shared.startUnlock(minutes: 670, manual: false) }  // DEMO_SCREEN=unlocked — game-time countdown
        case "leaderboard": LeaderboardView()   // DEMO_SCREEN=leaderboard
        case "livegame": LiveGameDemoHost()      // DEMO_SCREEN=livegame — live quiz setup/flow
        case "gameinvite": WorldMapView().onAppear { LiveGameManager.shared.seedDemoInvite() }  // invite banner
        case "devicecontrols": ChildDeviceControlsView()   // parent controls on child device
        case "joinguard":                                  // parent-scans-child-code block dialog
            JoinConfirmView().environmentObject(ParentSettings.shared)
                .onAppear { ParentSettings.shared.deviceRole = .parent; JoinCoordinator.shared.seedDemo(childCode: true) }
        case "friendtest":                      // DEMO_SCREEN=friendtest — runs the live Firestore diagnostic
            Text("Friends diagnostic — see console ([Friends])")
                .padding().task { await FriendsManager.shared.runDiagnostic() }
        default:         WorldMapView()   // "worldmap"
        }
    }

    /// Decides whether the shield should be on or off based on current unlock window.
    /// If the unlock window has expired or never started → ensure shield is on.
    /// If the unlock window is still active → keep shield off.
    private func enforceShieldStateIfNeeded() {
        guard shields.isAuthorized else { return }
        // Kid Mode owns the shield while it's on — re-assert its lock and let the
        // normal per-app enforcement stand down so it can't clobber it.
        if KidModeManager.shared.active {
            KidModeManager.shared.reassertIfActive()
            return
        }
        // App DELETION lock is tied to the DEVICE being a child's — NOT to whether
        // any apps are currently blocked. Otherwise a child device with an empty
        // block-list (or mid-unlock) could be deleted, dropping the shield and
        // unlocking everything. A parent's own phone stays unrestricted.
        // EXCEPTION: a parent can open a short "allow deletion" window from Settings
        // (to legitimately uninstall Tofy); it auto-re-locks when the window ends.
        let removalAllowed = (settings.appRemovalUnlockedUntil ?? .distantPast) > Date()
        shields.setAppRemovalLocked(settings.deviceRole == .child && !removalAllowed)
        // Nothing managed on this device (e.g. a parent's phone with no block-list
        // and no block-all allowlist) → make sure nothing is left shielded,
        // including a stale Kid Mode web/app lock.
        let hasBlockList = !SelectionStorage.isEmpty(settings.activitySelectionData)
        guard hasBlockList || settings.blockAllActive else {
            shields.clearShield()
            return
        }

        // Re-sync with the DeviceActivity monitor, which clears the shared grant
        // ONLY when it's truly spent (real usage reached the limit, or the long
        // safety backstop ended) — NOT when the iPad was merely locked/idle.
        progress.reloadUnlockFromShared()
        if progress.hasLiveUnlockGrant {
            // Grant still live → keep apps open. Usage-based re-locking is owned by
            // the monitor extension, so we must NOT burn unused minutes just
            // because the wall-clock deadline elapsed while the device was locked.
            shields.clearShield()
            return
        }

        // Re-apply the locked baseline (block-all-except-allowlist, or the classic
        // block-list honoring a temporary per-app allowance).
        if !(settings.allowExceptionActive) && settings.allowExceptionEndsAt != nil {
            settings.clearAllowException()
        }
        shields.applyDefaultLock()
    }
}
