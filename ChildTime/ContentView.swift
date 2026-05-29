import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore
    @EnvironmentObject var auth: AuthManager

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
