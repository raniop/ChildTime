import SwiftUI

struct UnlockedView: View {
    @EnvironmentObject var progress: ProgressStore
    @Environment(\.horizontalSizeClass) private var hsc
    @Environment(\.scenePhase) private var scenePhase
    @State private var secondsRemaining: Int = 0
    @State private var timer: Timer?
    @StateObject private var companion = CompanionController()
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

                VStack(spacing: AppSpacing.md) {
                    Text("נוֹתְרוּ")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                    timerRow
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: AppRadius.huge, style: .continuous))

                Text("עַכְשָׁיו אֶפְשָׁר לַעֲבוֹר לָאַפְּלִיקַצְיָה שֶׁ\(Gendered.g("אַתָּה רוֹצֶה", "אַתְּ רוֹצָה")) לְשַׂחֵק בָּהּ 🚀")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)

                Spacer()

                // Always offer a way OUT of play mode — otherwise a parent's manual
                // grant traps the device on this screen with no exit. Earned time
                // refunds its unused minutes; a manual grant just locks (nothing was
                // spent from the earned pool, so there's nothing to bank back).
                Button {
                    endEarly()
                } label: {
                    Text(progress.unlockIsManual ? "עֲצֹר וּשְׁמֹר אֶת הַזְּמַן ❄️" : "סִיַּמְתִּי לְשַׂחֵק")
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
            // A play session means the device is now the kid's — re-lock the parent
            // gate so re-entering Settings asks for the PIN again (a parent who opened
            // manual time with the PIN, then the kid taps "finish", must not leave the
            // gate open behind them).
            ParentSettings.shared.sessionUnlocked = false
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
        // Returning from another app (or the app switcher) pauses the Timer —
        // recompute from the absolute end time and restart so it's never frozen.
        .onChangeCompat(of: scenePhase) { _, phase in
            if phase == .active {
                secondsRemaining = progress.unlockSecondsRemaining
                startTimer()
            }
        }
    }

    /// The countdown as labeled columns — each number sits above its unit
    /// (שעות / דקות / שניות) so a young child can read what every digit means.
    /// Hours only appear once an hour or more is left; big grants (a parent's
    /// "until end of day") would otherwise show "801:27", which reads as nonsense.
    private var timerRow: some View {
        let showHours = secondsRemaining >= 3600
        let h = secondsRemaining / 3600
        let m = (secondsRemaining % 3600) / 60
        let s = secondsRemaining % 60
        return HStack(alignment: .top, spacing: isCompact ? 4 : 8) {
            if showHours {
                timeColumn(h, "שָׁעוֹת")
                timerColon
            }
            timeColumn(m, "דַּקּוֹת")
            timerColon
            timeColumn(s, "שְׁנִיּוֹת")
        }
        // A clock always reads hours→minutes→seconds left-to-right, even in the RTL
        // UI — otherwise the columns flip and seconds land on the left.
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
    }

    private func timeColumn(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(String(format: "%02d", value))
                .font(.system(size: timerSize, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .glow(AppColor.starGold, radius: 12)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: isCompact ? 15 : 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// The ":" separator — sized like the digits and pinned to the top so it lines
    /// up with the numbers, not the unit labels below them.
    private var timerColon: some View {
        Text(":")
            .font(.system(size: timerSize, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
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
        // A manual (parent) grant now FREEZES its leftover so it isn't wasted — the
        // child can resume it later from the home screen. An earned window refunds
        // its unused minutes to the wallet as before.
        if progress.unlockIsManual {
            progress.pauseManualUnlock()
            LiveEventReporter.report(.screenTimeEnd, extra: ["minutes": 0])
        } else {
            let remaining = progress.endUnlockAndReturnRemainingMinutes()
            // Child chose to stop early — tell the parent (+ minutes banked back).
            LiveEventReporter.report(.screenTimeEnd, extra: ["minutes": remaining])
        }
    }
}

#Preview {
    UnlockedView()
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
