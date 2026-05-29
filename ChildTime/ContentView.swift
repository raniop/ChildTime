import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var auth: AuthManager
    @StateObject private var household = HouseholdManager.shared

    var body: some View {
        Group {
            if !auth.isSignedIn {
                // Login is the very first gate — kid profiles, progress,
                // and cosmetics only sync across devices when the parent
                // is signed in. Required from day one.
                LoginGateView()
            } else if !settings.hasConsented {
                // Privacy by Design: explicit parental consent before any
                // child profile or data exists.
                ConsentView()
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
