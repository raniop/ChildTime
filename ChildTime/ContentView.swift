import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var auth: AuthManager
    @StateObject private var household = HouseholdManager.shared
    @StateObject private var kidMode = KidModeManager.shared
    @StateObject private var joinCoord = JoinCoordinator.shared
    @StateObject private var liveGame = LiveGameManager.shared

    /// Guests (no account) can answer this many questions before registration
    /// is required.
    static let guestQuestionLimit = 30

    var body: some View {
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
        // Global presence heartbeat: while a CHILD device is open (any screen),
        // refresh "last seen" every 15s so the parent sees "משחק עכשיו" live —
        // not just while inside a question.
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            if settings.deviceRole == .child, auth.isSignedIn, let cid = profiles.activeID {
                Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
            }
        }
        // …and an immediate beat the moment a child device appears (no 15s wait).
        .task {
            if settings.deviceRole == .child, auth.isSignedIn, let cid = profiles.activeID {
                await HouseholdManager.shared.registerDevice(forChildID: cid)
            }
        }
        // Home-screen Quick Action → present the Kid Mode entry flow.
        .sheet(isPresented: Binding(get: { kidMode.pendingEntry && !kidMode.active },
                                    set: { kidMode.pendingEntry = $0 })) {
            KidModeEntryView()
                .environment(\.layoutDirection, .rightToLeft)
        }
        // Any scanned/typed family-or-child code → detect type + confirm first.
        .fullScreenCover(isPresented: $joinCoord.active) {
            JoinConfirmView()
                .environmentObject(settings)
                .environment(\.layoutDirection, .rightToLeft)
        }
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

    /// Parent device → account required (or guest trial), consent, then the
    /// family control center.
    @ViewBuilder
    private var parentFlow: some View {
        if !auth.isSignedIn && !auth.isGuest {
            LoginGateView()
        } else if auth.isGuest && !auth.isSignedIn
                    && progress.totalAnswered >= Self.guestQuestionLimit {
            LoginGateView(allowGuest: false, limitBanner: true)
        } else if !settings.hasConsented {
            ConsentView()
        } else if settings.pendingJoinFamily && auth.isSignedIn {
            // Co-parent who chose "join an existing family" → a focused, guided
            // join screen BEFORE the dashboard (clears the flag on join/skip).
            JoinFamilyFlowView()
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
                .task { auth.signInAnonymouslyIfNeeded() }
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
            if progress.isUnlocked && liveGame.pendingGameID == nil && liveGame.game == nil && !liveGame.isSettingUp {
                UnlockedView()
            } else {
                WorldMapView()
            }
        }
        .onAppear {
            if profiles.activeID != cid { profiles.setActiveID(cid) }
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
        guard let raw = UserDefaults.standard.string(forKey: "profiles.activeID"),
              let id = UUID(uuidString: raw),
              profiles.profiles.contains(where: { $0.id == id }) else { return }
        // A cached REAL account (Apple/Google/email) marks a parent device.
        if let data = UserDefaults.standard.data(forKey: "auth.cachedUser"),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           (json["provider"] as? String)?.isEmpty == false {
            return
        }
        TofyLink("healLostChildRole: role was unset but child \(raw.prefix(8)) is active locally → restoring child role + binding")
        settings.joinedChildID = raw
        settings.deviceRole = .child
    }

    private var familyLoadingView: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                ProgressView().scaleEffect(1.4).tint(.white)
                Text("טוֹעֲנִים אֶת הַמִּשְׁפָּחָה שֶׁלָּכֶם…")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ShieldManager.shared)
        .environmentObject(ProfileStore.shared)
        .environmentObject(AuthManager.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
