import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var settings: ParentSettings
    /// Read, not observed: the root only needs "is a play window open", and
    /// observing the whole store re-ran it on every star of every answer.
    private var progress: ProgressStore { ProgressStore.shared }
    /// Flips when the window opens/closes — the only progress change that
    /// should redraw the root (the body still reads the live value).
    @State private var windowShowing = ProgressStore.shared.isUnlocked || ProgressStore.shared.isOpeningWindow
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var auth: AuthManager
    @StateObject private var household = HouseholdManager.shared
    @StateObject private var kidMode = KidModeManager.shared
    @StateObject private var joinCoord = JoinCoordinator.shared
    @StateObject private var liveGame = LiveGameManager.shared
    @QuietAppStorage(ChildLockSetup.pendingKey) private var lockSetupPending = false
    @ObservedObject private var location = LocationSharing.shared
    /// 📍 The child's explanation shows at most once per launch and 3 times in
    /// all — iOS asks for "always" only once, so a kid who declined is not nagged.
    @State private var locationPromptShown = false
    @QuietAppStorage("location.promptCount") private var locationPromptCount = 0

    /// Guests (no account) can answer this many questions before registration
    /// is required.

    var body: some View {
        let _ = BodyLog.hit("ContentView")
        Group {
            if kidMode.active {
                // Parent's phone temporarily acting as the kid's device.
                kidModeRoot
            } else if !settings.hasSeenWelcome {
                // Very first launch — explain what the app is + the Screen Time
                // notice, before anything else.
                WelcomeIntroView()
            } else if settings.deviceRole == .unset {
                // Choose the device's role FIRST: a child's play device (joins by
                // scanning a QR — no sign-in) or a parent's monitoring device
                // (needs an account). This steers the whole flow.
                //
                // SELF-HEAL first: settings live in the APP-GROUP defaults while
                // profiles live in STANDARD defaults. If the group container is
                // ever wiped/unavailable (iOS update, restore, container glitch),
                // the role+binding vanish while the child's profile survives —
                // and an established CHILD device suddenly showed the role
                // picker. If the evidence says "this was a bound child device",
                // restore the role+binding instead of asking a kid to choose.
                RolePickerView()
                    .onAppear { healLostChildRoleIfNeeded() }
            } else if settings.deviceRole == .child {
                childFlow
            } else {
                parentFlow
            }
        }
        // Redraw the root only when the play window opens or closes. The store
        // publishes BEFORE it changes, so read the value a beat later.
        .onReceive(ProgressStore.shared.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            let open = progress.isUnlocked || progress.isOpeningWindow
            if open != windowShowing { windowShowing = open }
        }
        // Global presence heartbeat: while a CHILD device is open (any screen),
        // refresh "last seen" every 15s so the parent sees "משחק עכשיו" live —
        // not just while inside a question.
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            // Kid Mode counts as a play device for the child being played as —
            // otherwise its open window is invisible to the child's own devices.
            if auth.isSignedIn, let cid = kidMode.active ? kidMode.childID : (settings.deviceRole == .child ? profiles.activeID : nil) {
                Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
            }
            // A PARENT's phone registers too, from the moment it has a household —
            // not only while Kid Mode is on. Without this a parent device is
            // invisible in the dashboard even though it reads and writes the
            // children's data, which is why "which device is doing this?" took an
            // hour to answer instead of a glance.
            if auth.isSignedIn, settings.deviceRole != .child {
                Task { await HouseholdManager.shared.registerParentDevice() }
            }
        }
        // …and an immediate beat the moment a child device appears (no 15s wait).
        .task {
            if auth.isSignedIn, let cid = kidMode.active ? kidMode.childID : (settings.deviceRole == .child ? profiles.activeID : nil) {
                await HouseholdManager.shared.registerDevice(forChildID: cid)
            }
            if auth.isSignedIn, settings.deviceRole != .child {
                await HouseholdManager.shared.registerParentDevice()
            }
        }
        // Home-screen Quick Action → present the Kid Mode entry flow.
        .sheet(isPresented: Binding(get: { kidMode.pendingEntry && !kidMode.active },
                                    set: { kidMode.pendingEntry = $0 })) {
            KidModeEntryView()
                .environment(\.layoutDirection, .app)
        }
        // DEBUG design preview: `simctl launch ... -SchoolYearPreviewVariant N`
        // overlays the September party for screenshots (Rani reviews variants).
        .overlay {
            let v = UserDefaults.standard.integer(forKey: "SchoolYearPreviewVariant")
            if v > 0 {
                SchoolYearCelebrationView(gradeName: tr("כִּתָּה ב'"), childName: tr("דן המלך"),
                                          gender: .boy, onDone: {})
            }
            if UserDefaults.standard.bool(forKey: "ParentGreetingPreview") {
                // Delayed so the party (and its confetti burst) starts AFTER the
                // launch splash — matching how the real fullScreenCover attaches.
                DelayedPartyPreview()
            }
            if UserDefaults.standard.bool(forKey: "WhatsNewPreview") {
                WhatsNewView(onDone: {})
            }
        }
        // Any scanned/typed family-or-child code → detect type + confirm first.
        .fullScreenCover(isPresented: $joinCoord.active) {
            JoinConfirmView()
                .environmentObject(settings)
                .environment(\.layoutDirection, .app)
        }
        // 🔔 A parent is beeping this phone — "מָצָאתִי!" over everything.
        .background(
            Color.clear.fullScreenCover(isPresented: $location.beeping) {
                KidBeepOverlay().environment(\.layoutDirection, .app)
            }
        )
        // 📍 A parent switched location sharing on — the kid's one-time words
        // before Apple's own question.
        .background(
            Color.clear.sheet(isPresented: Binding(
                get: { settings.deviceRole == .child && !kidMode.active && location.needsPermissionPrompt
                        && !locationPromptShown && locationPromptCount < 3 },
                set: { if !$0 { locationPromptShown = true; locationPromptCount += 1 } })) {
                KidLocationPermissionSheet().environment(\.layoutDirection, .app)
            }
        )
    }

    /// The kid experience shown while Kid Mode is on (parent's phone). Same play
    /// surface as a child device, plus a discreet, parent-gated exit.
    @ViewBuilder
    private var kidModeRoot: some View {
        // Exit from Kid Mode now lives inside the parent-gated settings (the gear
        // → "בקרת המכשיר" → "צא ממצב ילד"), instead of a floating button that
        // overlapped the top-bar buttons (and could disappear behind covers).
        Group {
            if let cid = kidMode.childID {
                childPlay(cid: cid)
            } else {
                WorldMapView()
            }
        }
    }

    /// Parent device → account REQUIRED, consent, then the family control
    /// center. Guest mode was removed (Rani, 2026-08-30): Tofy has exactly one
    /// trial — 30 days of טופי+ AFTER signing up. An existing guest install
    /// (legacy isGuest=true) lands back on the login gate; the kids' local
    /// data survives and uploads to the new family on sign-in (createdHere).
    @ViewBuilder
    private var parentFlow: some View {
        if !auth.isRealAccount {
            LoginGateView(limitBanner: auth.isGuest)
        } else if settings.pendingJoinFamily && auth.isSignedIn {
            // Co-parent who chose "join an existing family" → a focused, guided
            // join screen BEFORE the dashboard (clears the flag on join/skip).
            JoinFamilyFlowView()
        } else if household.household == nil, household.pendingEmailInvite != nil {
            // This email was pre-invited by the family owner — one-tap join.
            EmailInviteWelcomeView()
        } else if household.household == nil, household.needsFamilyChoice {
            // 🧭 A new account: step ① of the new-parent flow — the family's
            // name, with the parental consent on the same screen (it used to be
            // a separate privacy screen in front of this one).
            FamilyChoiceView()
        } else if household.familyNotLoaded, profiles.profiles.isEmpty {
            // 🔌 Signed in, the family still on its way (or its load failed):
            // nothing true to show yet. The empty dashboard here invited a
            // "צרו ילד/ה" that duplicated the family's real child (Eli, 9.10).
            FamilyConnectingView()
        } else if !settings.hasConsented, household.household != nil {
            // A parent who reached a family another way (co-parent join, email
            // invite) still gives the parental consent once.
            ConsentView()
        } else {
            // The control center is locked behind the parent code + Face ID.
            ParentGateView(allowClose: false) {
                ParentDashboardView(isRoot: true)
            }
        }
    }

    /// Child device → NO sign-in screen. Get an anonymous identity in the
    /// background, then scan the parent's QR to bind THIS device to ONE specific
    /// child. A child device must scan to join — it never auto-drops into a
    /// profile just because the account already has children.
    @ViewBuilder
    private var childFlow: some View {
        // A device already BOUND to a child whose profile is here locally plays
        // OFFLINE-FIRST: auth/network are only needed for sync and joining, so a
        // dead connection (or a lost anonymous session) must never strand the kid
        // on a "connecting" screen — that screen's escape hatch is how kids ended
        // up on the role picker. Auth heals in the background; sync catches up.
        if let joined = settings.joinedChildID, let cid = UUID(uuidString: joined),
           profiles.profiles.contains(where: { $0.id == cid }) {
            childPlay(cid: cid)
                .task {
                    // Before signing in: if the app was deleted and reinstalled,
                    // the Keychain still holds the old anonymous account and would
                    // put this device straight back into its previous family.
                    await auth.dropSessionIfReinstalled()
                    auth.signInAnonymouslyIfNeeded()
                }
        } else if !auth.isSignedIn {
            // Not bound (or profile not local yet) — joining requires a uid.
            ChildAuthLoadingView()
        } else if let joined = settings.joinedChildID, UUID(uuidString: joined) != nil {
            if household.isLoading {
                familyLoadingView
            } else {
                // The bound child isn't here (removed / not synced) → re-scan.
                ChildJoinView()
            }
        } else {
            // Not bound to a child on this device yet → must scan a code.
            ChildJoinView()
        }
    }

    /// Play as the bound child — make sure that profile is the active one.
    @ViewBuilder
    private func childPlay(cid: UUID) -> some View {
        Group {
            // A live-game invite was tapped (pendingGameID) or a game is active →
            // always show WorldMap, which hosts the live-game cover. Otherwise an
            // active screen-time window would land on UnlockedView and the tap
            // would never open the game.
            let _ = windowShowing
            if (progress.isUnlocked || progress.isOpeningWindow) && liveGame.pendingGameID == nil && liveGame.game == nil && !liveGame.isSettingUp {
                UnlockedView()
            } else {
                WorldMapView()
            }
        }
        // 🧭 Step ④ — just joined: approve Screen Time (and its passcode)
        // before the child's home, with the parent still holding the phone.
        .fullScreenCover(isPresented: Binding(get: { lockSetupPending && !kidMode.active },
                                              set: { if !$0 { lockSetupPending = false } })) {
            ChildLockSetupView { lockSetupPending = false }
        }
        .onAppear {
            if profiles.activeID != cid { profiles.setActiveID(cid) }
            // A device that JOINED a moment ago subscribes to its child doc only
            // once the profile lands locally, so a gift sent in that window used
            // to sit until the next launch. Read it once, here.
            Task { await RemoteSyncManager.shared.consumePendingCommandsNow(for: cid) }
            if let p = profiles.active {
                AppAnalytics.describeAudience(
                    role: "child",
                    ageBand: "age_\(p.age.rawValue)",
                    gender: p.gender?.rawValue)
            }
        }
    }

    /// The app-group settings said "no role", but the STANDARD-domain profile
    /// store says a child was active here and no real parent account is cached —
    /// that's a bound child device whose group container got wiped. Restore it.
    /// A parent device (real sign-in cached) is left alone: they can re-pick
    /// parent and their cached account signs them right back in.
    private func healLostChildRoleIfNeeded() {
        guard settings.deviceRole == .unset, settings.joinedChildID == nil else { return }
        // "התנתק ומחק מהמכשיר" produces the same signature as a lost container.
        // Without this the reset bounced straight back into the child's app,
        // bound to the old profile and unable to reach any family.
        if UserDefaults.standard.bool(forKey: "device.deliberateReset") { return }
        guard let raw = UserDefaults.standard.string(forKey: "profiles.activeID"),
              let id = UUID(uuidString: raw),
              profiles.profiles.contains(where: { $0.id == id }) else { return }
        // A cached REAL account (Apple/Google/email) marks a parent device.
        if let data = UserDefaults.standard.data(forKey: "auth.cachedUser"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           (json["provider"] as? String)?.isEmpty == false {
            return
        }
        // Guest trial (parent playing without an account) has NO cached user at
        // all — same signature as a child device. Don't hijack it into one.
        if UserDefaults.standard.bool(forKey: "isGuestMode") { return }
        TofyLink("healLostChildRole: role was unset but child \(raw.prefix(8)) is active locally → restoring child role + binding")
        settings.joinedChildID = raw
        settings.deviceRole = .child
    }

    private var familyLoadingView: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                ProgressView().scaleEffect(1.4).tint(.white)
                Text(tr("טוֹעֲנִים אֶת הַמִּשְׁפָּחָה שֶׁלָּכֶם…"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

/// Design-review helper: attaches the party 5s in, like a real presentation.
private struct DelayedPartyPreview: View {
    @State private var show = false
    var body: some View {
        ZStack {
            if show {
                ParentSchoolYearPartyView(profiles: [
                    Profile(name: tr("דן המלך"), gender: .boy, grade: 2, gradeSchoolYear: Profile.schoolYear()),
                    Profile(name: tr("נוני"), gender: .girl, grade: 4, gradeSchoolYear: Profile.schoolYear()),
                    Profile(name: tr("יהלי"), gender: .girl, grade: 1, gradeSchoolYear: Profile.schoolYear()),
                ], onDone: {})
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 5) { show = true } }
    }
}

#Preview {
    ContentView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ShieldManager.shared)
        .environmentObject(ProfileStore.shared)
        .environmentObject(AuthManager.shared)
        .environment(\.layoutDirection, .app)
}
