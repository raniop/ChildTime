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
    /// 🌍 Changing it rebuilds the whole tree in the new language and direction.
    @ObservedObject private var language = LanguageStore.shared
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
            // Grades set, so the kid-facing grade picker never covers a demo screen.
            let dana = Profile(name: "דָּנָה", gender: .girl, age: .grade1, grade: 3)
            ProfileStore.shared.add(dana)
            let yoav = Profile(name: "יוֹאָב", gender: .boy, age: .grade1, grade: 1)
            ProfileStore.shared.add(yoav)
            ProfileStore.shared.setActive(dana)
            UserDefaults.standard.set([dana.id.uuidString, yoav.id.uuidString],
                                      forKey: demoSeededIDsKey)
        }
        for var p in ProfileStore.shared.profiles where p.grade == nil { p.grade = 3; ProfileStore.shared.update(p) }
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
                Group { if let demo = Self.demoScreen { demoRoot(demo) } else { ContentView() } }
                    .id(language.current)

                // Animated welcome splash on top of the first frame, then it
                // fades away to reveal the app.
                if showSplash {
                    SplashScreenView { showSplash = false }
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
                .environment(\.layoutDirection, language.current.layoutDirection)
                // Hebrew keeps the device locale exactly as before; other languages bring their own.
                .environment(\.locale, language.current == .he ? .current : language.current.locale)
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
                    // A parent MONITOR device holds a VIEW of a child, not that
                    // child's play: rolling ITS copy over at midnight zeroed the
                    // child's today-counters (and re-released the carry-over
                    // bank) in a copy that could then win the merge.
                    if settings.deviceRole != .parent || KidModeManager.shared.active {
                        progress.applyDailyRolloverIfNeeded()   // release minutes banked for "tomorrow"
                    }
                    ConversionConfig.shared.start()   // what a free child sees (admin knobs)
                    enforceShieldStateIfNeeded()
                }
                .onChangeCompat(of: scenePhase) { _, phase in
                    if phase == .active, Self.demoScreen == nil {
                        if settings.deviceRole != .parent || KidModeManager.shared.active {
                            progress.applyDailyRolloverIfNeeded()
                        }
                        StopAndSaveBridge.applyIfRequested()   // Live Activity "עצור ושמור" fallback
                        // 🔑 Re-mint Screen Time tokens that iOS expired while we
                        // were away — an expired token silently stops shielding
                        // its app (iOS 26.5+; a no-op below that).
                        TokenRefresher.shared.start()
                        // ☁️ Pull any question topics the admin changed since last
                        // time (one tiny read; full topics only when versions move).
                        RemoteQuestionBank.shared.syncIfNeeded()
                        enforceShieldStateIfNeeded()
                        WidgetBridge.refreshKid()
                        ShieldBridge.refresh()   // keep the locked-app screen truthful
                        // Ask Apple again on every return: a subscription that
                        // lapsed while the app was closed must stop unlocking.
                        Task { await SubscriptionManager.shared.refreshSubscriptionStatus() }
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
                        ShieldBridge.refresh()   // keep the locked-app screen truthful
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
        case "mathgrade":                                   // DEMO_SCREEN=mathgrade DEMO_GRADE=8 [DEMO_WORLD=reading] — a world at a grade
            QuestionRunnerView(mode: .world(Worlds.all.first { $0.topic.rawValue == (ProcessInfo.processInfo.environment["DEMO_WORLD"] ?? "math") } ?? Worlds.all[0]), purpose: .earnTime)
                .onAppear {
                    if var p = ProfileStore.shared.active {
                        p.grade = Int(ProcessInfo.processInfo.environment["DEMO_GRADE"] ?? "") ?? 8
                        p.gradeSchoolYear = Profile.schoolYear()
                        ProfileStore.shared.update(p)
                    }
                }
        case "wheel":    LuckyWheelView(onClose: {})
        case "dashboard": ParentDashboardView(isRoot: true)
            .onAppear {
                if let id = ProfileStore.shared.activeID {
                    HouseholdManager.shared.seedDemoLiveWindow(childID: id)
                    LearningHistoryStore.shared.seedDemo(childID: id)
                }
            }
        case "starshop": StarShopView()   // DEMO_SCREEN=starshop (+ STARSHOP_DEMO=1 for sample packs)
        case "shop": ShopView()   // DEMO_SCREEN=shop — the kid's character shop
        case "parentsettings": ParentSettingsView()   // DEMO_SCREEN=parentsettings
        case "splash": SplashScreenView { }             // DEMO_SCREEN=splash
        case "welcome": WelcomeIntroView()              // DEMO_SCREEN=welcome
        case "rolepicker": RolePickerView()             // DEMO_SCREEN=rolepicker
        case "onboarding": OnboardingView()             // DEMO_SCREEN=onboarding — parent sign-up
        case "childjoin": ChildJoinView()               // DEMO_SCREEN=childjoin
        case "familychoice": FamilyChoiceView()         // DEMO_SCREEN=familychoice
        case "applock": ChildAppLockSetupView()         // DEMO_SCREEN=applock
        case "createchild":                             // DEMO_SCREEN=createchild — as the PARENT sees it
            ProfileEditorView(mode: .create) { _ in } onDelete: { _ in }
                .onAppear { ParentSettings.shared.deviceRole = .parent }   // demo: age / grade rows are parent-only
        case "kidmode": KidModeEntryView()              // DEMO_SCREEN=kidmode
        case "packdetail":                              // DEMO_SCREEN=packdetail — ⚽ pack page (parent)
            PackDetailView(pack: QuestionPacks.all[0], onClose: {})
                .environmentObject(ProfileStore.shared)
                .onAppear { ParentSettings.shared.deviceRole = .parent; PINManager.shared.setPIN("1234"); ParentSettings.shared.hasSetParentPIN = true }
        case "packreveal":                              // DEMO_SCREEN=packreveal — kid home: 🎁 the pack just arrived
            WorldMapView()
                .onAppear {
                    if ProgressStore.shared.isUnlocked { ProgressStore.shared.endUnlock() }
                    if var p = ProfileStore.shared.active {
                        PackKidState.reset(childID: p.id)
                        p.ownedPacks.insert("soccer"); ProfileStore.shared.update(p)
                    }
                }
        case "packnew":                                 // DEMO_SCREEN=packnew — kid home: revealed, "חדש!" tile pinned first
            WorldMapView()
                .onAppear {
                    if ProgressStore.shared.isUnlocked { ProgressStore.shared.endUnlock() }
                    if var p = ProfileStore.shared.active {
                        PackKidState.reset(childID: p.id); PackKidState.markRevealed("soccer", childID: p.id)
                        p.ownedPacks.insert("soccer"); ProfileStore.shared.update(p)
                    }
                }
        case "packask":                                 // DEMO_SCREEN=packask — kid: "בקש מאבא או אמא" for a pack
            PackAskParentView(pack: QuestionPacks.all[0], onClose: {})
        case "packoffer":                               // DEMO_SCREEN=packoffer — kid home with the 🎁 offer tile (not owned)
            WorldMapView()
                .onAppear {
                    if ProgressStore.shared.isUnlocked { ProgressStore.shared.endUnlock() }
                    if var p = ProfileStore.shared.active { p.ownedPacks.remove("soccer"); ProfileStore.shared.update(p) }
                }
        case "campaignpopup":                           // DEMO_SCREEN=campaignpopup — parent home with the in-app pop-up
            ParentDashboardView(isRoot: true)
                .onAppear {
                    if var p = ProfileStore.shared.profiles.first { p.ownedPacks.remove("soccer"); ProfileStore.shared.update(p) }
                    CampaignTracker.shared.seedDemoPopup(Campaign(sampleFor: "soccer"))
                }
        case "campaignpopupkid":                        // DEMO_SCREEN=campaignpopupkid — kid home with the child pop-up
            WorldMapView()
                .onAppear {
                    if ProgressStore.shared.isUnlocked { ProgressStore.shared.endUnlock() }
                    if var p = ProfileStore.shared.active { p.ownedPacks.remove("soccer"); ProfileStore.shared.update(p) }
                    CampaignTracker.shared.seedDemoPopup(Campaign(sampleFor: "soccer"))
                }
        case "worldpass":                               // DEMO_SCREEN=worldpass — parent page of a base world (30 days / Tofy+)
            PackDetailView(pack: WorldPasses.pass(for: .math)!, onClose: {})
                .environmentObject(ProfileStore.shared)
                .onAppear { ParentSettings.shared.deviceRole = .parent; PINManager.shared.setPIN("1234"); ParentSettings.shared.hasSetParentPIN = true }
        case "worldshelf":                              // DEMO_SCREEN=worldshelf — parent home (no Tofy+) with the worlds shelf + a request
            ParentDashboardView(isRoot: true)
                .onAppear {
                    let ps = ProfileStore.shared.profiles
                    if var a = ps.first { a.ownedPacks.insert("reading"); a.packExpiry["reading"] = Date().timeIntervalSince1970 + 12 * 86_400; ProfileStore.shared.update(a) }
                    if let b = ps.dropFirst().first {
                        HouseholdManager.shared.seedDemoLiveWindow(childID: b.id)
                        RemoteSyncManager.shared.seedDemoPremiumRequest(childID: b.id, topic: "math")
                    }
                }
        case "kidpass":                                 // DEMO_SCREEN=kidpass — kid home: a 30-day math pass just arrived
            WorldMapView()
                .onAppear {
                    if ProgressStore.shared.isUnlocked { ProgressStore.shared.endUnlock() }
                    if var p = ProfileStore.shared.active {
                        PackKidState.reset(childID: p.id); PackKidState.markRevealed("math", childID: p.id)
                        p.ownedPacks.insert("math"); p.packExpiry["math"] = Date().timeIntervalSince1970 + 30 * 86_400
                        p.ownedPacks.remove("soccer"); ProfileStore.shared.update(p)
                    }
                }
        case "packrequest":                             // DEMO_SCREEN=packrequest — parent home: a child asked for a pack
            ParentDashboardView(isRoot: true)
                .onAppear {
                    if var p = ProfileStore.shared.profiles.first {
                        p.ownedPacks.remove("soccer"); ProfileStore.shared.update(p)
                        RemoteSyncManager.shared.seedDemoPackRequest(childID: p.id, packID: "soccer")
                        HouseholdManager.shared.seedDemoLiveWindow(childID: p.id)
                    }
                }
        case "packowned":                               // DEMO_SCREEN=packowned — parent home after a purchase
            ParentDashboardView(isRoot: true)
                .onAppear {
                    if var p = ProfileStore.shared.profiles.first {
                        p.ownedPacks.insert("soccer"); ProfileStore.shared.update(p)
                        LearningHistoryStore.shared.seedDemo(childID: p.id, packTopic: .soccer)
                        HouseholdManager.shared.seedDemoLiveWindow(childID: p.id)
                    }
                }
        case "gate":                                    // DEMO_SCREEN=gate — the parent-code keypad
            ParentGateView(allowClose: true, respectSession: false) { Text("OK") }
                .onAppear {
                    // Demo only: a local code exists, so the keypad shows (not the
                    // "loading your family" wait).
                    PINManager.shared.setPIN("1234")
                    ParentSettings.shared.hasSetParentPIN = true
                }
        case "choresparent":                            // DEMO_SCREEN=choresparent — the parent's chores manager
            if let p = ProfileStore.shared.active { ChoresParentView(profile: p).onAppear { ChoreStore.shared.seedDemo(childID: p.id) } }
        case "childdifficulty": if let id = ProfileStore.shared.activeID { ChildDifficultyView(profileID: id) }
        case "childscreentime": if let id = ProfileStore.shared.activeID { ChildScreenTimeView(profileID: id) }
        case "childworlds": if let id = ProfileStore.shared.activeID { ChildWorldsView(profileID: id) }
        case "kidhome":                                     // DEMO_SCREEN=kidhome — the child's home
            WorldMapView()   // (+ DEMO_GIFT_MINUTES=30 to show the 💝 button)
                .onAppear {
                    // A previous DEMO_SCREEN=unlocked run leaves a fake open window
                    // behind; the home must start closed.
                    if ProgressStore.shared.isUnlocked { ProgressStore.shared.endUnlock() }
                    // …and a pack/pass from another demo would pop the 🎁 reveal here.
                    if var p = ProfileStore.shared.active, !p.ownedPacks.isEmpty {
                        p.ownedPacks = []; p.packExpiry = [:]; ProfileStore.shared.update(p)
                    }
                    // Demo only: a daily cap, so the strip reads "60/90" like the mockup.
                    if !ParentSettings.shared.dailyCapEnabled {
                        ParentSettings.shared.dailyCapEnabled = true
                        ParentSettings.shared.maxMinutesPerDay = 90
                    }
                }
        case "askworld": AskParentView(world: Worlds.all[0], onClose: {})   // DEMO_SCREEN=askworld — kid tapped a locked world
        case "askparent": AskParentView(onClose: {})   // DEMO_SCREEN=askparent — what a CHILD device shows instead of the paywall
        case "paywall":  PaywallView()    // DEMO_SCREEN=paywall — the "טופי+" subscription screen (App Review proof)
        case "unlocked": UnlockedView().onAppear { ProgressStore.shared.startUnlock(minutes: 670, manual: false) }  // DEMO_SCREEN=unlocked — game-time countdown
        case "kidflow":                                        // DEMO_SCREEN=kidflow — the real kid flow: home ↔ play screen
            KidFlowDemo()
        case "opening":  UnlockedView().onAppear { ProgressStore.shared.beginOpeningWindow(gift: false) }           // DEMO_SCREEN=opening — the "we're opening it" state
        case "openinggift": UnlockedView().onAppear { ProgressStore.shared.beginOpeningWindow(gift: true) }         // DEMO_SCREEN=openinggift
        case "whatsnew": WhatsNewView(onDone: {})   // DEMO_SCREEN=whatsnew — the release-notes sheet
        case "parenthome": ParentDashboardView(isRoot: true)   // DEMO_SCREEN=parenthome — the redesigned overview
            .onAppear {
                if let id = ProfileStore.shared.activeID {
                    HouseholdManager.shared.seedDemoLiveWindow(childID: id)
                    LearningHistoryStore.shared.seedDemo(childID: id)
                }
            }
        // 🎁 The conversion journey on the parent home (approved mockups):
        case "activation": ParentDashboardView(isRoot: true)   // free, one active day from the gift
            .onAppear { HouseholdManager.shared.seedDemoJourney(activation: (days: 2, questions: 64)) }
        case "giftearly": ParentDashboardView(isRoot: true)    // gift, 11 days left
            .onAppear {
                HouseholdManager.shared.seedDemoJourney(daysLeft: 11, familyName: "מִשְׁפַּחַת גּוֹלָן")
                // A family board worth showing: both kids with a device and a
                // month of history, one of them mid-window.
                for (i, p) in ProfileStore.shared.profiles.enumerated() {
                    LearningHistoryStore.shared.seedDemo(childID: p.id)
                    if i == 0 { HouseholdManager.shared.seedDemoLiveWindow(childID: p.id) }
                }
            }
        case "giftlate": ParentDashboardView(isRoot: true)     // gift ending in 3 days → personal card
            .onAppear { HouseholdManager.shared.seedDemoJourney(daysLeft: 3) }
        case "giftended": ParentDashboardView(isRoot: true)    // gift over, child asked for a world
            .onAppear {
                HouseholdManager.shared.seedDemoJourney(daysLeft: 0)
                if let id = ProfileStore.shared.activeID { RemoteSyncManager.shared.seedDemoPremiumRequest(childID: id, topic: "soccer") }
            }
        case "dailychest": DailyChestView()                    // DEMO_SCREEN=dailychest — 🎁 the daily gift box
        case "levelup": LevelUpView(newLevel: 5, onContinue: {})   // DEMO_SCREEN=levelup
        case "worldunlock": WorldUnlockView(world: Worlds.all[1], onContinue: {})   // DEMO_SCREEN=worldunlock
        case "gradepicker":                                    // DEMO_SCREEN=gradepicker
            if let p = ProfileStore.shared.active { ChildGradePickerView(profile: p, onPicked: { _ in }) }
        case "kidpin":                                         // DEMO_SCREEN=kidpin
            if let p = ProfileStore.shared.active { KidPINView(profile: p, mode: .verify(title: "הַדַּקּוֹת שֶׁלִּי 🔒"), onSuccess: { _ in }, onCancel: {}) }
        case "parentassist":                                   // DEMO_SCREEN=parentassist — the kid asks a parent
            WorldMapView().sheet(isPresented: .constant(true)) {
                ParentAssistView(question: Question(topic: .math, prompt: "כַּמָּה זֶה 7 + 8?", options: ["13", "15", "14", "16"], correctIndex: 1),
                                 topic: .math, onContinue: {})
                    .environment(\.layoutDirection, .rightToLeft)
            }
        case "parenthelp":                                     // DEMO_SCREEN=parenthelp — the parent answers
            ParentDashboardView(isRoot: true).sheet(isPresented: .constant(true)) {
                ParentHelpAnswerView(request: ParentHelpManager.demoRequest)
            }
        case "paywallgift": PaywallView()                      // the personal paywall, 2 days left
            .onAppear { HouseholdManager.shared.seedDemoJourney(daysLeft: 2) }
        case "leaderboard": LeaderboardView().onAppear { LiveGameManager.shared.seedDemoInvite() }   // DEMO_SCREEN=leaderboard (+ a waiting invite)
        case "livegame": LiveGameDemoHost()      // DEMO_SCREEN=livegame — live quiz setup/flow
        case "gameinvite": WorldMapView().onAppear { LiveGameManager.shared.seedDemoInvite() }  // invite banner
        case "choreskid":                                  // DEMO_SCREEN=choreskid (+ DEMO_GENDER=boy)
            ChoresKidView(onClose: {})
                .onAppear {
                    if ProcessInfo.processInfo.environment["DEMO_GENDER"] == "boy",
                       let boy = ProfileStore.shared.profiles.first(where: { $0.gender == .boy }) {
                        ProfileStore.shared.setActive(boy)
                    }
                    if let id = ProfileStore.shared.activeID { ChoreStore.shared.seedDemo(childID: id) }
                }
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

        // 🔐 A window may only stay open while WE hold the lease. If the child moved
        // play to their other device (or a takeover happened), this device closes
        // itself on the next foreground — this is what makes a wrong takeover
        // harmless, and it settles a lease the monitor extension closed in the
        // background (that process has no Firebase and cannot release it).
        if PlayWindowLeaseManager.isEnabled, let cid = ProfileStore.shared.activeID {
            PlayWindowLeaseManager.shared.drainExtensionReleaseIfNeeded(childID: cid)
            PlayWindowLeaseManager.shared.reconcileOfflineWindowIfNeeded(childID: cid)
            let lease = PlayWindowLeaseManager.shared.lease
            if progress.isUnlocked, progress.activeLeaseID != nil, lease.isHeldElsewhere() {
                ShieldManager.shared.relockBaseline()
                progress.stopAndSaveCurrentUnlock()
                return
            }
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

/// DEMO_SCREEN=kidflow — home and play screen switching exactly as they do in
/// the real app, so a screen recording can follow the whole loop end to end.
private struct KidFlowDemo: View {
    @StateObject private var progress = ProgressStore.shared
    var body: some View {
        Group {
            if progress.isUnlocked || progress.isOpeningWindow { UnlockedView() } else { WorldMapView() }
        }
    }
}
