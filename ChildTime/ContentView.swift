import SwiftUI

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
            ParentDashboardView(isRoot: true)
        }
    }

    /// Child device → NO sign-in screen. Get an anonymous identity in the
    /// background (so it can join the family + sync), then scan the parent's QR
    /// and play.
    @ViewBuilder
    private var childFlow: some View {
        if !auth.isSignedIn {
            // Signing in anonymously — brief, automatic, no UI to fill in.
            familyLoadingView
                .task { auth.signInAnonymouslyIfNeeded() }
        } else if profiles.isEmpty && household.isLoading {
            familyLoadingView
        } else if profiles.isEmpty {
            // Not joined yet → scan/enter the code the parent created.
            ChildJoinView()
        } else if profiles.activeID == nil {
            ProfilePickerView()
        } else if progress.isUnlocked {
            UnlockedView()
        } else {
            WorldMapView()
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
