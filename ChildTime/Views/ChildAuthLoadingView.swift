import SwiftUI

/// Shown on a CHILD device while it gets an anonymous identity in the background
/// (no sign-in screen). If that fails or hangs (e.g. Anonymous sign-in isn't
/// enabled, or no network), we surface a clear error + retry instead of spinning
/// forever — and an escape to re-pick the device type.
struct ChildAuthLoadingView: View {
    @EnvironmentObject var auth: AuthManager
    @EnvironmentObject var settings: ParentSettings

    @State private var attempt = 0
    @State private var timedOut = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: AppSpacing.lg) {
                if timedOut && !auth.isSignedIn {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                    Text("לֹא הִצְלַחְנוּ לְהִתְחַבֵּר")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(auth.lastError ?? "בִּדְקוּ אֶת חִבּוּר הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)

                    Button {
                        Haptic.light()
                        retry()
                    } label: {
                        Text("נַסּוּ שׁוּב")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 36).padding(.vertical, 14)
                            .background(AppGradient.gold, in: Capsule())
                            .glow(AppColor.starGold, radius: 10)
                    }
                    .buttonStyle(.juicy)

                    Button {
                        Haptic.light()
                        settings.deviceRole = .unset   // back to the device-type picker
                    } label: {
                        Text("הַחְלִיפוּ סוּג מַכְשִׁיר")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 20).padding(.vertical, 10)
                            .background(.white.opacity(0.16), in: Capsule())
                    }
                } else {
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(.white)
                    Text("מִתְחַבְּרִים…")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .task(id: attempt) { await runAttempt() }
    }

    private func runAttempt() async {
        timedOut = false
        auth.signInAnonymouslyIfNeeded()
        try? await Task.sleep(nanoseconds: 8_000_000_000)
        if !auth.isSignedIn { timedOut = true }
    }

    private func retry() {
        attempt += 1   // re-runs the .task
    }
}
