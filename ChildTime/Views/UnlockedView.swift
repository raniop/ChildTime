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
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            VStack(spacing: AppSpacing.xl) {
                Spacer()

                // Gift time from the parents wears the gift heart, never the
                // controller — the two pockets are never blurred (Rani).
                Text(progress.unlockIsManual ? "💝" : "🎮")
                    .font(.system(size: heroEmojiSize))
                    .float()
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)

                Text("זְמַן מִשְׂחָק!")
                    .font(.system(size: titleSize, weight: .black, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .shadow(color: .black.opacity(0.18), radius: 7, y: 2)

                // The countdown on one glass pane (the same glass as every screen).
                VStack(spacing: AppSpacing.md) {
                    Text(progress.unlockIsManual ? "מַתָּנָה מֵאַבָּא וְאִמָּא 💝 · נוֹתְרוּ" : "נוֹתְרוּ")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                    timerRow
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.lg)
                .frame(maxWidth: 420)
                .glassPane(radius: 28)

                Text("עַכְשָׁיו אֶפְשָׁר לַעֲבוֹר לָאַפְּלִיקַצְיָה שֶׁ\(Gendered.g("אַתָּה רוֹצֶה", "אַתְּ רוֹצָה")) לְשַׂחֵק בָּהּ 🚀")
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg).padding(.vertical, 10)
                    .frame(maxWidth: 480)
                    .glassInset(radius: 16)

                Spacer()

                // Always offer a way OUT of play mode — otherwise a parent's manual
                // grant traps the device on this screen with no exit. Earned time
                // refunds its unused minutes; a manual grant just locks (nothing was
                // spent from the earned pool, so there's nothing to bank back).
                Button {
                    endEarly()
                } label: {
                    Text(progress.unlockIsManual ? "עֲצֹר וּשְׁמֹר אֶת הַזְּמַן 💝" : "סִיַּמְתִּי לְשַׂחֵק")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .ctaGlass(Color(hex: "5E60CE"), Color(hex: "3E8BF0"))
                }
                .buttonStyle(.juicy)
                .frame(maxWidth: 480)
                .padding(.bottom, AppSpacing.xxl)
            }
            // Side margins like the home cards — the panes never touch the edges.
            .padding(.horizontal, 28)

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
                .font(.system(size: timerSize, weight: .black, design: .rounded))
                .foregroundStyle(GlassInk.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: isCompact ? 13 : 15, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// The ":" separator — sized like the digits and pinned to the top so it lines
    /// up with the numbers, not the unit labels below them.
    private var timerColon: some View {
        Text(":")
            .font(.system(size: timerSize, weight: .black, design: .rounded))
            .foregroundStyle(GlassInk.secondary)
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
                    // Baseline re-lock (Kid-Mode-aware; block-all vs block-list).
                    ShieldManager.shared.relockBaseline()
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
        // Baseline re-lock (Kid-Mode-aware; block-all vs block-list).
        ShieldManager.shared.relockBaseline()
        // A manual (parent) grant now FREEZES its leftover so it isn't wasted — the
        // child can resume it later from the home screen. An earned window refunds
        // its unused minutes to the wallet as before.
        // MUST go through stopAndSaveCurrentUnlock — it is the one place that also
        // RELEASES the family's play-window lease. Calling pauseManualUnlock /
        // endUnlockAndReturnRemainingMinutes directly (as this did) closed the
        // window locally while the cloud still said this device was playing: the
        // sibling kept showing "פתוח במכשיר השני" forever, and its transfer
        // request could never be honoured because this device was no longer
        // unlocked and had nothing left to stop.
        let banked = progress.stopAndSaveCurrentUnlock()
        // Child chose to stop early — tell the parent (+ minutes banked back).
        LiveEventReporter.report(.screenTimeEnd, extra: ["minutes": banked])
        // Upload the pocket change NOW (not after the ~3s debounce): the "stopped
        // playing" push races the snapshot — the parent must see the frozen 💝 /
        // banked 🎮 leftover, not a stale "—", even if the kid leaves right away.
        RemoteSyncManager.shared.pushNow()
    }
}

#Preview {
    UnlockedView()
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
