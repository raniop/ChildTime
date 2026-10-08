import SwiftUI
import Combine

/// ⚡ "נָכוֹן אוֹ לֹא נָכוֹן?" — a 60-second race against the clock: one
/// statement at a time ("7 × 8 = 54", "מָה בִּירַת צָרְפַת? · פָּרִיז") and two
/// big glass buttons. The answer shows at once — mint for right; a miss only
/// glows soft warm, shows the right button and moves on. A streak 🔥 counts
/// along. Math is computed; everything else is a short bank question with its
/// real answer or one of its distractors.
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser every card
/// is an answer that earns (or gently costs) like a regular question.
struct LightningTrueFalseView: View {
    var topic: Topic? = nil
    /// ⚡ Launched by the runner's surprise round: no intro, one round, ×2.
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc
    /// 🖼 A miniature on a What's-New story card: show the real screen,
    /// but do not play it — no round is scored and no clock runs.
    @Environment(\.isInertPreview) private var inertPreview

    private enum Phase { case intro, playing, done }

    @State private var phase: Phase = .intro
    @State private var statement: LightningStatement?
    @State private var seen: Set<String> = []
    @State private var picked: Bool?
    @State private var startedAt = Date()
    @State private var now = Date()
    @State private var shownAt = Date()
    @State private var answered = 0
    @State private var correct = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var shake: CGFloat = 0
    @State private var cardID = 0
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var isCompact: Bool { hsc == .compact }
    /// Math cards follow the child's adaptive level in math.
    private var grade: Int { topic == .math ? MiniGameLevel.grade(for: .math) : max(1, profiles.active?.effectiveGrade ?? 2) }
    private var roundSeconds: TimeInterval { TimeInterval(MiniGameKind.lightning.seconds(surprise: surprise)) }
    private var remaining: TimeInterval { max(0, roundSeconds - now.timeIntervalSince(startedAt)) }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "✓ \(correct)", surprise: surprise)
                }
                switch phase {
                case .intro:
                    Spacer()
                    MiniGameIntroCard(kind: .lightning) { start() }
                    Spacer()
                case .playing:
                    playing
                case .done:
                    Spacer()
                    MiniGameEndCard(
                        title: correct >= 15 ? tr("וָואוּ, מְצֻיָּן! 🏆") : tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: summaryLine,
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד סִבּוּב 🔁"),
                        onAgain: { start() },
                        onDone: onClose)
                    Spacer()
                }
            }

            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if (surprise || earn != nil || inertPreview) && phase == .intro { start() } }
        .onReceive(ticker) { t in
            guard !inertPreview else { return }
            guard phase == .playing else { return }
            now = t
            if remaining <= 0 { finish() }
        }
    }

    private var summaryLine: String {
        let first: String
        switch correct {
        case 0:  first = surprise ? tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") : tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
        case 1:  first = tr("תְּשׁוּבָה נְכוֹנָה אַחַת")
        default: first = tr("\(correct) תְּשׁוּבוֹת נְכוֹנוֹת")
        }
        guard bestStreak >= 2 else { return first }
        return first + "\n" + tr("הָרֶצֶף הֲכִי אָרֹךְ: \(bestStreak) 🔥")
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            MiniGameTimerBar(remaining: remaining, total: roundSeconds)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .glassPane(radius: 16, shadow: false)

            Text(streak >= 2 ? tr("🔥 \(streak) בְּרֶצֶף") : " ")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: streak)

            Spacer(minLength: 0)
            statementCard
            Spacer(minLength: 0)

            HStack(spacing: AppSpacing.md) {
                answerButton(true)
                answerButton(false)
            }
            .environment(\.layoutDirection, .app)
        }
        .frame(maxWidth: isCompact ? 640 : 780)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    /// The runner's question card: the question line, then the claim big.
    private var statementCard: some View {
        VStack(spacing: 12) {
            Text(tr("נָכוֹן אוֹ לֹא נָכוֹן?"))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
            if let p = statement?.prompt {
                Text(MiniGameText.show(p))
                    .font(.system(size: isCompact ? 20 : 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .mathLTR(MiniGameText.isMath(p))
            }
            Text(MiniGameText.show(statement?.claim ?? ""))
                .font(.system(size: claimSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.5)
                .mathLTR(MiniGameText.isMath(statement?.claim ?? ""))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .miniGameTile(claimState, tint: AppColor.starGold, radius: 20)
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .glassPane(radius: 16)
        .modifier(MiniGameShake(animatableData: shake))
        .id(cardID)
        .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
    }

    private var claimSize: CGFloat {
        let base: CGFloat = statement?.prompt == nil ? (isCompact ? 44 : 58) : (isCompact ? 32 : 42)
        return display.isShort ? base * 0.85 : base
    }

    private var claimState: MiniGameTileState {
        guard let picked, let s = statement else { return .normal }
        return picked == s.isTrue ? .correct : .normal
    }

    private func answerButton(_ value: Bool) -> some View {
        let state: MiniGameTileState = {
            guard let picked, let s = statement else { return .normal }
            if value == s.isTrue { return .correct }        // the right one always lights up
            return picked == value ? .wrong : .normal
        }()
        return Button { answer(value) } label: {
            VStack(spacing: 4) {
                Text(value ? "✓" : "✗")
                    .font(.system(size: isCompact ? 38 : 48, weight: .black, design: .rounded))
                Text(value ? tr("נָכוֹן") : tr("לֹא נָכוֹן"))
                    .font(.system(size: isCompact ? 21 : 26, weight: .heavy, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: display.isShort ? 104 : (isCompact ? 124 : 150))
            .miniGameTile(state, tint: value ? AppColor.successMint : Color(hex: "B7ABFF"), radius: 26)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: state)
        }
        .buttonStyle(.juicy)
        .disabled(picked != nil)
        .accessibilityLabel(value ? tr("נָכוֹן") : tr("לֹא נָכוֹן"))
    }

    // MARK: - Logic

    private func start() {
        seen = []
        answered = 0; correct = 0; streak = 0; bestStreak = 0; grant = nil
        startedAt = Date(); now = Date()
        nextStatement()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { phase = .playing }
    }

    private func nextStatement() {
        let s = LightningStatements.make(topic: topic, grade: grade, profile: profiles.active, seen: &seen)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            statement = s
            picked = nil
            cardID += 1
        }
        shownAt = Date()
    }

    private func answer(_ value: Bool) {
        guard phase == .playing, picked == nil, let s = statement else { return }
        picked = value
        answered += 1
        let right = value == s.isTrue
        if right {
            correct += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            burst += 1
            SoundPlayer.shared.play(streak % 5 == 0 ? .streakUp : .correctSmall)
            Haptic.success()
        } else {
            streak = 0
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
        }
        // Every card is an answer in the parent's reports.
        MiniGameLedger.record(correct: right, topic: s.topic,
                              responseMs: Date().timeIntervalSince(shownAt) * 1000,
                              streak: streak, earn: earn, surprise: surprise)
        DispatchQueue.main.asyncAfter(deadline: .now() + (right ? 0.5 : 1.0)) {
            guard phase == .playing else { return }
            nextStatement()
        }
    }

    private func finish() {
        guard phase == .playing else { return }
        grant = MiniGameReward.grant(game: "lightning", correct: correct, starsPer: 1, diamondsPer: 1,
                                     cap: surprise ? 12 : 15, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .done }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        if correct > 0 { confetti += 1 }
        AppAnalytics.log("lightning_game_done", ["answered": "\(answered)", "correct": "\(correct)",
                                                 "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    LightningTrueFalseView(topic: .flags, onClose: {})
}
