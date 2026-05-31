import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var auth: AuthManager
    @StateObject private var household = HouseholdManager.shared

    /// Guests (no account) can answer this many questions before registration
    /// is required.
    static let guestQuestionLimit = 30

    var body: some View {
        Group {
            if !settings.hasSeenWelcome {
                // Very first launch — explain what the app is + the Screen Time
                // notice, before anything else.
                WelcomeIntroView()
            } else if settings.deviceRole == .unset {
                // Choose the device's role FIRST: a child's play device (joins by
                // scanning a QR — no sign-in) or a parent's monitoring device
                // (needs an account). This steers the whole flow.
                RolePickerView()
            } else if settings.deviceRole == .child {
                childFlow
            } else {
                parentFlow
            }
        }
        // Global presence heartbeat: while a CHILD device is open (any screen),
        // refresh "last seen" every 30s so the parent sees "משחק עכשיו" live —
        // not just while inside a question.
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            if settings.deviceRole == .child, auth.isSignedIn, let cid = profiles.activeID {
                Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
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
        if !auth.isSignedIn {
            // Signing in anonymously — brief, automatic, no UI to fill in.
            ChildAuthLoadingView()
        } else if let joined = settings.joinedChildID, let cid = UUID(uuidString: joined) {
            if profiles.profiles.contains(where: { $0.id == cid }) {
                childPlay(cid: cid)
            } else if household.isLoading {
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
            if progress.isUnlocked { UnlockedView() } else { WorldMapView() }
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
