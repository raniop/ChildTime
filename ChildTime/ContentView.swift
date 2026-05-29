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
            if !auth.isSignedIn && !auth.isGuest {
                // Login is the first gate — but a child may also tap "play
                // without an account" to try up to 30 questions as a guest.
                LoginGateView()
            } else if auth.isGuest && !auth.isSignedIn
                        && progress.totalAnswered >= Self.guestQuestionLimit {
                // Free-trial limit reached — registration required to continue.
                LoginGateView(allowGuest: false, limitBanner: true)
            } else if settings.deviceRole == .unset {
                // First launch: is this a child's play device or a parent's
                // monitoring device? Steers the whole UI from here on.
                RolePickerView()
            } else if !settings.hasConsented {
                // Privacy by Design: explicit parental consent before any
                // child profile or data exists.
                ConsentView()
            } else if settings.deviceRole == .parent {
                // Parent's device → straight into the family monitoring view.
                ParentDashboardView(isRoot: true)
            } else if !settings.onboardingCompleted {
                // Logged in but parent hasn't finished setup yet.
                OnboardingView()
            } else if profiles.isEmpty && household.isLoading {
                // Signed in but the family is still downloading from the cloud —
                // wait instead of prematurely offering to create a child.
                familyLoadingView
            } else if profiles.isEmpty || profiles.activeID == nil {
                // Onboarding done — Netflix-style picker (covers both
                // 'no profiles yet' and 'parent signed out of a profile').
                ProfilePickerView()
            } else if progress.isUnlocked {
                UnlockedView()
            } else {
                WorldMapView()
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
