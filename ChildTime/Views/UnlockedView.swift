import SwiftUI

struct UnlockedView: View {
    @EnvironmentObject var progress: ProgressStore
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var secondsRemaining: Int = 0
    @State private var timer: Timer?
    @State private var companion = CompanionController()
    @State private var greeted = false

    private var isCompact: Bool { hsc == .compact }
    private var heroEmojiSize: CGFloat { isCompact ? 96 : 140 }
    private var titleSize: CGFloat { isCompact ? 42 : 56 }
    private var timerSize: CGFloat { isCompact ? 68 : 96 }
    private var companionSize: CGFloat { isCompact ? 60 : 70 }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 14, size: 14)

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                Text("🎮")
                    .font(.system(size: heroEmojiSize))
                    .float()
                    .glow(AppColor.successMint, radius: 24)

                Text("זְמַן מִשְׂחָק!")
                    .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .glow(AppColor.successMint, radius: 14)

                VStack(spacing: AppSpacing.sm) {
                    Text(timeString)
                        .font(.system(size: timerSize, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .glow(AppColor.starGold, radius: 12)
                        .contentTransition(.numericText())
                    Text("נוֹתְרוּ")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, AppSpacing.xxxl)
                .padding(.vertical, AppSpacing.xxl)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.huge, style: .continuous))

                Text("עַכְשָׁיו אֶפְשָׁר לַעֲבֹר לָאַפְּלִיקַצְיָה שֶׁ\(Gendered.g("אַתָּה רוֹצֶה", "אַתְּ רוֹצָה")) לְשַׂחֵק בָּהּ 🚀")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer()

                Button {
                    endEarly()
                } label: {
                    Text("סִיַּמְתִּי לְשַׂחֵק")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.md)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.juicy)
                .padding(.bottom, AppSpacing.xxl)
            }

            // Sleepy companion
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    CompanionView(controller: companion, size: companionSize)
                        .opacity(0.6)
                        .padding(.trailing, AppSpacing.lg)
                }
            }
            .padding(.bottom, 100)
        }
        .onAppear {
            startTimer()
            if !greeted {
                greeted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    companion.cheer("\(Gendered.g("שִׂחַקְתָּ", "שִׂחַקְתְּ")) יָפֶה!")
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    companion.state = .sleep
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }

    private var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimer() {
        secondsRemaining = progress.unlockSecondsRemaining
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                secondsRemaining = progress.unlockSecondsRemaining
                if secondsRemaining <= 0 {
                    // Time's up — re-apply the shield in-app (the extension would normally do this,
                    // but this covers the case where the kid is still inside ChildTime).
                    ShieldManager.shared.cancelScheduledReshield()
                    if let data = ParentSettings.shared.activitySelectionData {
                        let selection = SelectionStorage.decode(data)
                        ShieldManager.shared.applyShield(from: selection)
                    }
                    progress.endUnlock()
                    timer?.invalidate()
                    // Window ran out — let the parent know play time ended.
                    LiveEventReporter.report(.screenTimeEnd, extra: ["minutes": 0])
                }
            }
        }
    }

    private func endEarly() {
        ShieldManager.shared.cancelScheduledReshield()
        if let data = ParentSettings.shared.activitySelectionData {
            let selection = SelectionStorage.decode(data)
            ShieldManager.shared.applyShield(from: selection)
        }
        // Refund any remaining full minutes back to the pending pool
        let remaining = progress.endUnlockAndReturnRemainingMinutes()
        // Child chose to stop early — tell the parent (+ minutes banked back).
        LiveEventReporter.report(.screenTimeEnd, extra: ["minutes": remaining])
    }
}

#Preview {
    UnlockedView()
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
