import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore

    var body: some View {
        Group {
            if !settings.onboardingCompleted {
                // Brand-new family — run them through onboarding first.
                OnboardingView()
            } else if profiles.isEmpty || profiles.activeID == nil {
                // Either no profiles yet OR the parent signed out of a
                // profile — Netflix-style picker handles both.
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
        .environment(\.layoutDirection, .rightToLeft)
}
