import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore

    var body: some View {
        Group {
            if !settings.onboardingCompleted {
                OnboardingView()
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
        .environment(\.layoutDirection, .rightToLeft)
}
