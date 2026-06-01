import SwiftUI
import Combine

struct QuestionRunnerView: View {
    /// How this session sources its topics — a single world, or the Smart Feed.
    let mode: SessionMode
    /// Why the child is here — earn screen time (capped, grants minutes) or
    /// free voluntary learning (uncapped, no minutes, in-game rewards only).
    let purpose: SessionPurpose

    /// Worlds are entered voluntarily → Free Learning by default.
    init(world: World, purpose: SessionPurpose = .freePlay) {
        self.mode = .world(world); self.purpose = purpose
    }
    init(mode: SessionMode, purpose: SessionPurpose = .earnTime) {
        self.mode = mode; self.purpose = purpose
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore
    @EnvironmentObject var profiles: ProfileStore

    private var isCompact: Bool { hsc == .compact }
    private var questionSize: CGFloat { isCompact ? 42 : 58 }
    private var topicEmojiSize: CGFloat { isCompact ? 30 : 36 }
    private var companionSize: CGFloat { isCompact ? 78 : 90 }
    private var portalEmojiSize: CGFloat { isCompact ? 130 : 180 }
    private var portalTitleSize: CGFloat { isCompact ? 36 : 56 }

    @State private var companion = CompanionController()
    @State private var didReportSessionEnd = false
    @State private var current: Question?
    @State private var questionIndex: Int = 0
    @State private var correctInSession: Int = 0
    @State private var selectedIndex: Int? = nil
    @State private var feedbackForIndex: [Int: OptionFeedback] = [:]
    @State private var showFeedback: Bool = false
    @State private var lastWasCorrect: Bool = false
    @State private var isSuperQuestion: Bool = false
    @State private var isInPortal: Bool = false
    @State private var showPortalIntro: Bool = false
    @State private var consecutiveWrong: Int = 0
    @State private var burstTrigger: Int = 0
    @State private var confettiTrigger: Int = 0
    @State private var rumbleTrigger: Int = 0
    @State private var goToReward: Bool = false
    @State private var earnedThisSession: Int = 0
    @State private var startedLevel: Int = 1
    @State private var lastEarnedMinutes: Int = 0
    @State private var showEarnedPopup: Bool = false
    // Per-question seconds feedback ("+24 שניות" / "−12 שניות · כמעט!").
    @State private var secondsFlashText: String? = nil
    @State private var secondsFlashPositive = true
    @State private var secondsFlashID = 0

    // Smart Feed / learning state
    @State private var currentTopic: Topic = .math
    @State private var topicHistory: [Topic] = []
    /// Questions the child got wrong this session — re-asked later (the only
    /// allowed repeat). Deduped by prompt.
    @State private var reAskQueue: [Question] = []
    @State private var questionShownAt: Date? = nil
    @State private var hadMistakeThisQuestion: Bool = false

    // Live-event / Parent Assist bookkeeping (one report per session each).
    @State private var reportedMilestone = false
    @State private var reportedWheel = false
    @State private var reportedDiscovery: Set<Topic> = []
    @State private var showParentAssist = false
    @State private var assistOfferedThisQuestion = false
    @State private var showReportConfirm = false
    @State private var capMessageShown = false

    /// Earn mode: the parent's session length, hard-capped at 30 ("no matter
    /// what"). Free mode: effectively unlimited — the child ends it with סיום.
    private var totalQuestions: Int {
        switch purpose {
        case .earnTime: return min(settings.questionsPerSession, 30)
        case .freePlay: return 100_000
        }
    }

    /// The world used to theme the current question (background, orbs, glow).
    /// Fixed for a world session; follows the question's topic in the feed.
    private var themeWorld: World {
        switch mode {
        case .world(let w): return w
        case .smartFeed:    return Worlds.forTopic(currentTopic)
        }
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: AppSpacing.md) {
                topBar
                if let q = current {
                    Spacer(minLength: 0)
                    questionHeader(q)
                    Spacer(minLength: 0)
                    answersBlock(q)
                    Spacer(minLength: AppSpacing.xxl)   // breathing room above the companion
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.md)

            // Companion in corner
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Bubble sits ABOVE the avatar (no overlap, always readable).
                    VStack(alignment: .leading, spacing: 6) {
                        if let bubble = companion.bubbleText {
                            BubbleSpeech(text: bubble)
                                .transition(.scale.combined(with: .opacity))
                        }
                        // The buddy is the child's own avatar (with cosmetics);
                        // falls back to the Tofy face if no profile is active.
                        if let profile = profiles.active {
                            ZStack {
                                Circle()
                                    .fill(AppColor.companionGlow.opacity(0.28))
                                    .frame(width: companionSize * 1.15, height: companionSize * 1.15)
                                    .blur(radius: 8)
                                ProfileAvatarView(profile: profile, size: companionSize)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 2))
                                    .shadow(color: .black.opacity(0.25), radius: 5, y: 3)
                            }
                        } else {
                            CompanionView(controller: companion, size: companionSize)
                        }
                    }
                    .padding(.leading, AppSpacing.md)
                    Spacer()
                }
            }
            .padding(.bottom, AppSpacing.lg)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: companion.bubbleText)

            // Effects overlays
            StarBurst(color: AppColor.starGold, trigger: burstTrigger)
            Confetti(trigger: confettiTrigger)

            // Earned-minutes popup (pops at center, then flies up to the timer)
            VStack {
                Spacer()
                EarnedMinutesPopup(minutes: lastEarnedMinutes, visible: showEarnedPopup)
                Spacer().frame(maxHeight: .infinity)
            }
            .allowsHitTesting(false)

            // Per-question seconds feedback — rises toward the timer and fades.
            if let text = secondsFlashText {
                Text(text)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill((secondsFlashPositive ? AppColor.successMint : AppColor.flameOrange).opacity(0.95)))
                    .glow(secondsFlashPositive ? AppColor.successMint : AppColor.flameOrange, radius: 10)
                    .id(secondsFlashID)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.5).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)))
                    .padding(.top, 140)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
            }

            // Portal overlay
            if showPortalIntro {
                portalIntro
            }
        }
        .rumble(trigger: rumbleTrigger)
        .sheet(isPresented: $showParentAssist) {
            ParentAssistView { }
                .environment(\.layoutDirection, .rightToLeft)
        }
        .confirmationDialog("דִּוּוּחַ עַל הַשְּׁאֵלָה",
                            isPresented: $showReportConfirm, titleVisibility: .visible) {
            Button("דַּוְּחוּ וְהַסִּירוּ אֶת הַשְּׁאֵלָה", role: .destructive) {
                if let q = current {
                    QuestionReporter.shared.report(q)
                    Haptic.success()
                    createQuestion(super: false)   // replace with a fresh question
                }
            }
            Button("בִּטּוּל", role: .cancel) {}
        } message: {
            Text("נָסִיר אֶת הַשְּׁאֵלָה הַזּוֹ וְלֹא נַצִּיג אוֹתָהּ שׁוּב, וְנִשְׁלַח עָלֶיהָ דִּוּוּחַ כְּדֵי שֶׁנְּשַׁפֵּר.")
        }
        .onAppear { startSession() }
        .onDisappear {
            // Tell the parent the child finished playing (once), with a brief
            // summary of how the session went.
            if !didReportSessionEnd {
                didReportSessionEnd = true
                let answered = max(questionIndex, correctInSession)
                let accuracy = answered > 0 ? Int(Double(correctInSession) / Double(answered) * 100) : 0
                LiveEventReporter.report(.sessionEnd, extra: [
                    "questions": answered,
                    "correct": correctInSession,
                    "accuracy": accuracy,
                    "minutes": progress.sessionMinutesEarned,
                    "stars": progress.sessionStarsEarned
                ])
            }
        }
        // Live presence: refresh this child device's "last seen" every 30s while
        // playing, so the parent dashboard shows "🟢 משחק עכשיו" in real time.
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            if settings.deviceRole == .child, let cid = profiles.activeID {
                Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
            }
        }
        .fullScreenCover(isPresented: $goToReward) {
            RewardScreenView(
                kind: RewardEngine.endOfSessionChestKind(correctInSession: correctInSession, total: chestDenominator),
                correctInSession: correctInSession,
                world: themeWorld,
                startedLevel: startedLevel
            ) {
                dismiss()
            }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        ZStack {
            (isInPortal ? AppGradient.portal : themeWorld.gradient.gradient)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.5), value: themeWorld.id)
            if !isInPortal {
                themedOrbs
                WorldDecorations(world: themeWorld).opacity(0.18)
            }
            SparkleField(count: 12, size: 12)
        }
    }

    @ViewBuilder
    private var themedOrbs: some View {
        switch themeWorld.id {
        case "math_kingdom":    FloatingOrbs.castle()
        case "english_land":    FloatingOrbs.englishWorld()
        case "logic_lab":       FloatingOrbs.logicWorld()
        case "science_lab":     FloatingOrbs.scienceWorld()
        case "history_museum":  FloatingOrbs.historyWorld()
        case "geo_journey":     FloatingOrbs.geographyWorld()
        default:                FloatingOrbs.home()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        // Slim progress row + a tidy row of the two things the child collects:
        // game-minutes and stars (the single currency).
        VStack(spacing: 8) {
            HStack(spacing: isCompact ? AppSpacing.sm : AppSpacing.md) {
                closeButton(size: isCompact ? 26 : 32)
                progressIndicator
                StreakMeter(streak: progress.currentStreak)
            }
            HStack(spacing: isCompact ? 6 : 10) {
                Spacer(minLength: 0)
                statChip("🎮", progress.pendingMinutes, AppColor.successMint)   // game minutes
                statChip("⭐", progress.stars, AppColor.starGold)               // stars
            }
            // Live earned-time bar — fills a little after every correct answer.
            if earnsTime { earnedTimeBar }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    /// Only Earn-to-Unlock sessions grow play-time.
    private var earnsTime: Bool { purpose.grantsScreenTime }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    /// The fractional-reward timer: the seconds earned toward the next bonus,
    /// a progress bar that fills per question, and a "question X / N" label.
    @ViewBuilder
    private var earnedTimeBar: some View {
        let target = progress.bonusTargetSeconds
        let secs = min(target, Int(progress.cycleSeconds.rounded()))
        let frac = target > 0 ? min(1, Double(secs) / Double(target)) : 0
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Text("🎮").font(.system(size: 14))
                Text("זְמַן שֶׁהִרְוַחְתָּ")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(timeString(secs))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(AppGradient.success)
                        .frame(width: max(6, geo.size.width * frac))
                        .glow(AppColor.successMint, radius: 4)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress.cycleSeconds)
                }
            }
            .frame(height: 8)
            HStack {
                Text("שְׁאֵלָה \(min(progress.cycleQuestionsDone, progress.cycleQuestionsTotal)) מִתּוֹךְ \(progress.cycleQuestionsTotal)")
                Spacer()
                Text("\(timeString(secs)) מִתּוֹךְ \(timeString(target))")
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .monospacedDigit()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColor.successMint.opacity(0.4), lineWidth: 1))
    }

    /// A small currency pill (emoji + value), animating its number on change.
    private func statChip(_ emoji: String, _ value: Int, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: isCompact ? 14 : 16))
            Text("\(value)")
                .font(.system(size: isCompact ? 14 : 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
        }
        .padding(.horizontal, isCompact ? 9 : 11)
        .padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.15)))
        .overlay(Capsule().stroke(tint.opacity(0.55), lineWidth: 1))
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: value)
    }

    /// Slim progress bar toward the end of the round + a small "done/total"
    /// label. Replaces the long row of dots — far calmer at the top.
    @ViewBuilder
    private var progressIndicator: some View {
        let total = max(1, totalQuestions)
        let done = min(questionIndex, total)
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.22))
                    Capsule()
                        .fill(AppGradient.gold)
                        .frame(width: max(6, geo.size.width * CGFloat(done) / CGFloat(total)))
                        .glow(AppColor.starGold, radius: 4)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: questionIndex)
                }
            }
            .frame(height: 8)
            Text("\(done)/\(total)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .monospacedDigit()
        }
    }

    /// The motivational HUD. In Earn mode it foregrounds screen-time (earned
    /// today / questions-to-prize); in Free mode it foregrounds progression
    /// (wheel / level) and hides screen-time, which isn't earned here.
    private func progressHUD(compact: Bool) -> some View {
        SessionProgressHUD(
            earnedToday: progress.minutesEarnedToday,
            questionsUntilReward: max(0, totalQuestions - questionIndex),
            questionsUntilWheel: progress.questionsUntilWheel,
            questionsUntilLevel: progress.questionsUntilNextLevel,
            wheelReady: progress.freeWheelAvailable,
            showsEarn: purpose == .earnTime,
            compact: compact
        )
    }

    private func endSession() {
        goToReward = true
    }

    /// Chest tier scales with accuracy over the questions actually answered.
    /// Earn mode uses the fixed cap; Free mode uses how many were attempted.
    private var chestDenominator: Int {
        purpose == .earnTime ? totalQuestions : max(1, questionIndex)
    }

    private func closeButton(size: CGFloat) -> some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: size))
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - Daily cap chip

    private var dailyCapChipVisible: Bool { settings.dailyCapEnabled }

    private var dailyCapChip: some View {
        let earned = progress.minutesEarnedToday
        let cap = settings.maxMinutesPerDay
        let atCap = earned >= cap
        let tint: Color = atCap ? AppColor.almostWarm : AppColor.successMint
        return HStack(spacing: 6) {
            Image(systemName: atCap ? "timer.circle.fill" : "timer")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            Text(atCap ? "הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי" : "\(earned)/\(cap) דַּק' הַיּוֹם")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.15)))
        .overlay(Capsule().stroke(tint.opacity(0.6), lineWidth: 1))
    }

    // MARK: - Question content

    /// Topic indicator + the prompt card (the upper block).
    @ViewBuilder
    private func questionHeader(_ q: Question) -> some View {
        VStack(spacing: AppSpacing.md) {
            // Topic / super indicator
            HStack(spacing: 8) {
                Text(q.topic.emoji)
                    .font(.system(size: topicEmojiSize))
                if isSuperQuestion {
                    Text("⭐ שְׁאֵלַת זָהָב!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                        .glow(AppColor.starGold, radius: 8)
                } else if isInPortal {
                    Text("🌀 בּוֹנוּס ×3 כּוֹכָבִים!")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .glow(AppColor.gemPurple, radius: 10)
                } else if mode.isFeed {
                    Text(q.topic.displayName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }

            Text(q.prompt)
                .font(.system(size: questionSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)   // never truncate the question
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .fill(.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                                .stroke(isSuperQuestion ? AppColor.starGold : .white.opacity(0.2),
                                        lineWidth: isSuperQuestion ? 3 : 1)
                        )
                )
                // Report a bad question — subtle flag in the card's top-left
                // corner (confirmed, so a child won't trigger it by accident).
                .overlay(alignment: .topTrailing) {
                    Button { showReportConfirm = true } label: {
                        Image(systemName: "flag")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                            .padding(7)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    .padding(8)
                }
                .glow(isSuperQuestion ? AppColor.starGold : .clear, radius: isSuperQuestion ? 16 : 0)
                .padding(.horizontal, AppSpacing.lg)
        }
    }

    /// The answers grid + the hint / magic-wand row (the lower block).
    @ViewBuilder
    private func answersBlock(_ q: Question) -> some View {
        VStack(spacing: AppSpacing.lg) {
            optionsGrid(for: q)

            // Hint shows whenever it's payable; wand only after 2 wrong picks.
            // Fixed height so the layout never jumps when these appear/disappear
            // (e.g. the hint hides the moment the answer is locked in).
            HStack(spacing: AppSpacing.md) {
                if !showFeedback {
                    hintButton(for: q)
                }
                if consecutiveWrong >= 2 && !showFeedback {
                    magicWandButton
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: consecutiveWrong)
        }
    }

    // Cost of one hint, in pending-minutes (the kid's banked play time).
    private let hintCostMinutes = 1

    /// The equipped character is the "smart helper". Higher tiers help more:
    /// rare/epic add a topic nudge, legendary/mythic add a method explanation
    /// AND make the hint free. This is the payoff for a pricier character.
    private var helperLevel: Character3D.HelpLevel {
        (profiles.active?.character ?? Character3DCatalog.find(nil)).helpLevel
    }

    /// Legendary/mythic helpers give their hint for free.
    private var hintCost: Int { helperLevel == .explain ? 0 : hintCostMinutes }

    private func canUseHint(_ q: Question) -> Bool {
        guard !showFeedback else { return false }
        guard progress.pendingMinutes >= hintCost else { return false }
        // Need at least one wrong option still un-eliminated.
        return q.options.indices.contains(where: { idx in
            idx != q.correctIndex && (feedbackForIndex[idx] ?? .normal) == .normal
        })
    }

    @ViewBuilder
    private func hintButton(for q: Question) -> some View {
        let enabled = canUseHint(q)
        Button {
            useHint(q: q)
        } label: {
            HStack(spacing: 8) {
                Text("💡")
                Text("רֶמֶז")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(hintCost == 0 ? "(חִינָּם)" : "(\(hintCost) דַּק')")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .background(
                LinearGradient(
                    colors: [AppColor.starGold, Color(hex: "FFB84D")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .glow(AppColor.starGold, radius: enabled ? 10 : 0)
            .opacity(enabled ? 1.0 : 0.4)
        }
        .buttonStyle(.juicy)
        .disabled(!enabled)
    }

    private func optionsGrid(for q: Question) -> some View {
        let columns = [GridItem(.flexible(), spacing: AppSpacing.md), GridItem(.flexible(), spacing: AppSpacing.md)]
        return LazyVGrid(columns: columns, spacing: AppSpacing.md) {
            ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                OptionCard(
                    text: opt,
                    feedback: feedbackForIndex[idx] ?? .normal,
                    index: idx
                ) {
                    pickOption(idx, q: q)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
    }

    private var magicWandButton: some View {
        Button {
            companion.cheer("בּוֹא נְנַסֶּה אַחֶרֶת")
            withAnimation(.spring()) {
                regenerateQuestion()
            }
        } label: {
            HStack {
                Text("🪄")
                Text("הַחְלֵף שְׁאֵלָה")
            }
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .background(.white.opacity(0.2), in: Capsule())
        }
        .buttonStyle(.juicy)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Portal intro animation

    private var portalIntro: some View {
        ZStack {
            // A full, rich backdrop so the question fully recedes — no more
            // see-through clutter behind the announcement.
            AppGradient.purpleDream.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.gemPurple, AppColor.starGold, AppColor.dreamyTeal],
                count: 6, maxSize: 260, opacity: 0.5
            )
            SparkleField(count: 26, size: 14)

            VStack(spacing: AppSpacing.lg) {
                Text("🌀")
                    .font(.system(size: portalEmojiSize))
                    .rotationEffect(.degrees(showPortalIntro ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: showPortalIntro)
                    .glow(AppColor.gemPurple, radius: 30)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 6)

                Text("שְׁאֵלַת בּוֹנוּס!")
                    .font(.system(size: portalTitleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .glow(AppColor.starGold, radius: 16)

                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Text("⭐️").font(.system(size: isCompact ? 28 : 36))
                    }
                }

                Text("עֲנוּ נָכוֹן וְקַבְּלוּ פִּי 3 כּוֹכָבִים!")
                    .font(.system(size: isCompact ? 18 : 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .transition(.opacity)
    }

    // MARK: - Session

    private func startSession() {
        startedLevel = progress.companionLevel
        progress.registerSessionToday()
        progress.resetSessionScore()
        LearningHistoryStore.shared.recordSessionStart(purpose: purpose)
        LiveEventReporter.report(.sessionStart)
        reportedMilestone = false
        reportedWheel = false
        reportedDiscovery = []
        capMessageShown = false
        questionIndex = 0
        correctInSession = 0
        earnedThisSession = 0
        consecutiveWrong = 0
        topicHistory = []
        reAskQueue = []
        QuestionMemory.shared.beginSession()   // no repeats within this session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            companion.cheer(mode.isFeed ? "הַרְפַּתְקָה חֲכָמָה — קָדִימָה! 🧠" : "מוּכָן? קָדִימָה!")
        }
        nextQuestion()
    }

    private func nextQuestion() {
        guard questionIndex < totalQuestions else {
            // session done
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                goToReward = true
            }
            return
        }

        // Decide special events
        let mystery = EventEngine.shouldFireMysteryPortal(questionIndex: questionIndex, totalQuestions: totalQuestions)
        let superQ = !mystery && EventEngine.shouldFireSuperQuestion(questionIndex: questionIndex, totalQuestions: totalQuestions)

        if mystery {
            isInPortal = true
            showPortalIntro = true
            SoundPlayer.shared.play(.portalAppear)
            companion.wow("וָואוּ! פּוֹרְטַל!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showPortalIntro = false }
                createQuestion(super: false)
            }
        } else {
            isInPortal = false
            createQuestion(super: superQ)
        }
    }

    /// Chooses the topic for the question about to be created, per session mode.
    private func pickTopic() -> Topic {
        switch mode {
        case .world(let w):
            return w.topic
        case .smartFeed:
            let profile = LearningProfile(store: progress, settings: settings)
            let engine = LearningFeedEngine(profile: profile)
            return engine.nextTopic(history: topicHistory, index: questionIndex)
        }
    }

    private func createQuestion(super isSuper: Bool) {
        isSuperQuestion = isSuper
        selectedIndex = nil
        feedbackForIndex = [:]
        showFeedback = false
        hadMistakeThisQuestion = false
        assistOfferedThisQuestion = false

        // Re-ask a previously-wrong question every few questions (spaced out) —
        // the only repeat we allow.
        if !isSuper, questionIndex > 0, questionIndex % 3 == 0, !reAskQueue.isEmpty {
            let requeued = reAskQueue.removeFirst()
            currentTopic = requeued.topic
            current = requeued
            questionShownAt = Date()
            return
        }

        let topic = pickTopic()
        currentTopic = topic
        topicHistory.append(topic)

        // DDA: pick difficulty from rolling accuracy for this topic.
        let baseDiff = settings.difficulty(for: topic)
        let acc = progress.accuracy(for: topic)
        let effective = QuestionGenerator.adaptiveDifficulty(base: baseDiff, accuracy: acc)
        var q = QuestionGenerator.generate(topic: topic, difficulty: effective)
        // Bank questions already avoid session repeats (QuestionMemory). Math is
        // generated, so re-roll if we happen to produce one seen this round.
        if topic == .math {
            var tries = 0
            while QuestionMemory.shared.wasServedThisSession(sessionKey(q)), tries < 8 {
                q = QuestionGenerator.generate(topic: topic, difficulty: effective)
                tries += 1
            }
        }
        // Skip questions a parent reported/removed.
        var hideTries = 0
        while QuestionReporter.shared.isHidden(q.prompt), hideTries < 12 {
            q = QuestionGenerator.generate(topic: topic, difficulty: effective)
            hideTries += 1
        }
        QuestionMemory.shared.markServedThisSession(sessionKey(q))
        current = q
        questionShownAt = Date()
    }

    /// Dedup key matching QuestionMemory's (prompt + correct answer).
    private func sessionKey(_ q: Question) -> String {
        let correct = q.correctIndex < q.options.count ? q.options[q.correctIndex] : ""
        return "\(q.prompt)|\(correct)"
    }

    private func regenerateQuestion() {
        // Replacing a question is an abandonment signal for its topic.
        progress.recordAbandon(topic: currentTopic)
        // Drop the just-served topic from history so the replacement re-picks.
        if !topicHistory.isEmpty { topicHistory.removeLast() }
        createQuestion(super: isSuperQuestion)
        consecutiveWrong = 0
    }

    // MARK: - Picking

    private func pickOption(_ idx: Int, q: Question) {
        // showFeedback only locks the grid AFTER the correct answer is found.
        // Wrong picks just dim that single option and let the kid keep trying
        // — this is essential for learning ("don't move on, change the choices").
        guard !showFeedback else { return }
        // Defensive: this option is already eliminated (wrong / hinted).
        if let existing = feedbackForIndex[idx], existing != .normal { return }

        selectedIndex = idx
        let correct = (idx == q.correctIndex)
        lastWasCorrect = correct

        if correct {
            // Final correct answer: lock the grid, reveal everything,
            // play the success flow, then advance.
            var map = feedbackForIndex
            for i in 0..<q.options.count {
                if i == idx {
                    map[i] = .correct
                } else if (map[i] ?? .normal) == .normal {
                    map[i] = .dimmed
                }
                // else keep whatever it was (already dimmed from prior wrong pick)
            }
            feedbackForIndex = map
            showFeedback = true
            handleCorrect(q: q)
            // If the child stumbled on this one, queue it to re-ask later — the
            // only question that's allowed to repeat in a session.
            if hadMistakeThisQuestion, !reAskQueue.contains(where: { $0.prompt == q.prompt }) {
                reAskQueue.append(q)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                questionIndex += 1
                nextQuestion()
            }
        } else {
            // Wrong: flash that option red briefly, then dim it (eliminated).
            // Do NOT reveal the correct answer. Do NOT advance.
            feedbackForIndex[idx] = .wrong
            handleWrong(q: q)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                // After the brief red flash, settle into the dimmed state so
                // the kid can't pick it again. Other options stay tappable.
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    feedbackForIndex[idx] = .dimmed
                }
            }
        }
    }

    // MARK: - Hint

    private func useHint(q: Question) {
        guard canUseHint(q) else { return }
        // Spend the minutes (0 for a free legendary/mythic helper → always true).
        guard progress.spendPendingMinutes(hintCost) else { return }

        // Pick a random wrong option that hasn't been eliminated yet.
        let candidates = q.options.indices.filter { idx in
            idx != q.correctIndex && (feedbackForIndex[idx] ?? .normal) == .normal
        }
        guard let toEliminate = candidates.randomElement() else { return }

        // Use the dedicated `.eliminated` state — it renders with a 💡
        // badge + strikethrough so the kid can see at a glance which
        // option the hint just removed, separate from wrong picks.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
            feedbackForIndex[toEliminate] = .eliminated
        }
        SoundPlayer.shared.play(.streakUp)
        Haptic.medium()
        burstTrigger += 1

        // The character speaks — the smarter (pricier) it is, the more it helps.
        switch helperLevel {
        case .encourage:
            companion.cheer("הֵסַרְתִּי לְךָ אוֹפְּצְיָה! אַתָּה יָכוֹל 💪")
        case .hint:
            companion.cheer("הֵסַרְתִּי אוֹפְּצְיָה. \(HintContent.hint(q.topic))")
        case .explain:
            companion.cheer(HintContent.explain(q.topic))
        }
    }

    private func handleCorrect(q: Question) {
        SoundPlayer.shared.play(isSuperQuestion ? .correctBig : .correctSmall)
        Haptic.success()
        burstTrigger += 1
        correctInSession += 1
        consecutiveWrong = 0

        let responseMs = questionShownAt.map { Date().timeIntervalSince($0) * 1000 } ?? 0
        let ctx = ProgressStore.AnswerContext(
            topic: q.topic,
            combo: progress.currentStreak,
            isSuperQuestion: isSuperQuestion,
            isMysteryPortal: isInPortal
        )
        // Was the child already at their daily maximum *before* this answer?
        // If so, they keep playing & learning but earn no more minutes.
        let earnsTime = purpose.grantsScreenTime
        let cappedBefore = earnsTime && progress.atDailyCap

        // Minutes are granted in batches (every 10 correct → 4 min), so measure
        // what was ACTUALLY added this answer rather than assuming a per-answer
        // rate — most answers add 0, and the 10th adds the batch.
        let minutesBefore = progress.pendingMinutes
        let earned = progress.recordCorrect(
            ctx,
            minutesPerCorrect: settings.minutesPerCorrectAnswer,
            responseMs: responseMs,
            hadMistakeThisQuestion: hadMistakeThisQuestion,
            grantsScreenTime: earnsTime
        )
        earnedThisSession += earned
        let minutesGranted = max(0, progress.pendingMinutes - minutesBefore)

        LearningHistoryStore.shared.recordAnswer(
            topic: q.topic, correct: true, responseMs: responseMs,
            earnedMinutes: minutesGranted,
            streak: progress.currentStreak,
            voluntary: cappedBefore   // learning past the max = voluntary
        )
        reportLiveEvents(for: q)

        // Immediate per-question reward: "+24 שניות" rising into the timer.
        if earnsTime, !cappedBefore {
            flashSeconds("+\(progress.secondsPerCorrect) שְׁנִיּוֹת", positive: true)
        }
        // "+X דקות" popup — only when a full bonus was banked this answer.
        if minutesGranted > 0 {
            showEarnedMinutesPopup(minutes: minutesGranted)
        }

        // Crossed the daily maximum just now? Celebrate once and make it clear
        // that play continues for fun/learning without more minutes.
        if earnsTime, !cappedBefore, progress.atDailyCap, !capMessageShown {
            capMessageShown = true
            companion.wow("\(Gendered.g("הִגַּעְתָּ", "הִגַּעְתְּ")) לַמַּקְסִימוּם הַיּוֹמִי! 🎉 מִכָּאן מַמְשִׁיכִים לִלְמֹד בְּלִי דַּקּוֹת נוֹסָפוֹת")
            confettiTrigger += 1
            return
        }
        // Already past the max — gentle, occasional reminder (no minutes now).
        if cappedBefore {
            companion.cheer(["יָפֶה! לוֹמְדִים בִּשְׁבִיל הַכֵּיף 🌟", "כֹּל הַכָּבוֹד! עוֹד נְקֻדּוֹת וְכוֹכָבִים", "\(Gendered.g("אַלּוּף", "אַלּוּפָה"))! מַמְשִׁיכִים לְהִתְקַדֵּם"].randomElement()!)
            return
        }

        // Risk & Recovery payoff — celebrate winning time back.
        if progress.lastRecoveredMinutes > 0 {
            let back = progress.lastRecoveredMinutes
            progress.lastRecoveredMinutes = 0
            companion.wow("\(Gendered.g("הֶחְזַרְתָּ", "הֶחְזַרְתְּ")) \(back) דַּק'! ⭐")
            confettiTrigger += 1
            return
        }

        // Personal-best streak — the headline celebration, takes priority.
        if progress.newStreakRecord {
            progress.newStreakRecord = false
            companion.wow("שִׂיא חָדָשׁ! 🏆 \(progress.currentStreak) בָּרֶצֶף!")
            confettiTrigger += 1
            rumbleTrigger += 1
            SoundPlayer.shared.play(.levelUp)
            return
        }

        // Companion reaction
        if isSuperQuestion {
            companion.wow("שְׁאֵלַת זָהָב! ⭐")
            confettiTrigger += 1
        } else if isInPortal {
            companion.wow("שְׁאֵלַת בּוֹנוּס — פִּי 3 כּוֹכָבִים! 🌀")
            confettiTrigger += 1
        } else if EventEngine.shouldFireComboEvent(streak: progress.currentStreak) {
            companion.hype("🔥 \(progress.currentStreak) בָּרֶצֶף!")
            confettiTrigger += 1
            rumbleTrigger += 1
        } else {
            companion.cheer(["יֵשׁ!", "טוֹב!", "כֵּן!", "וָואוּ!", "\(Gendered.g("אַלּוּף", "אַלּוּפָה"))!"].randomElement()!)
        }
    }

    /// In-session milestones used to push notifications mid-game (streak,
    /// 8/15, wheel, discovery) — they flooded the parent. We now notify ONLY on
    /// session start + finish (and explicit help requests), so this is a no-op.
    private func reportLiveEvents(for q: Question) { }

    /// Flash a small "+24 שניות" / "−12 שניות" near the timer.
    private func flashSeconds(_ text: String, positive: Bool) {
        secondsFlashPositive = positive
        secondsFlashID += 1
        let id = secondsFlashID
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            secondsFlashText = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            if secondsFlashID == id {
                withAnimation(.easeOut(duration: 0.4)) { secondsFlashText = nil }
            }
        }
    }

    private func showEarnedMinutesPopup(minutes: Int) {
        lastEarnedMinutes = minutes
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            showEarnedPopup = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.4)) {
                showEarnedPopup = false
            }
        }
    }

    private func handleWrong(q: Question) {
        SoundPlayer.shared.play(.wrongSoft)
        Haptic.warning()
        consecutiveWrong += 1
        hadMistakeThisQuestion = true
        // Stuck? Gently offer to bring a parent in (once per question).
        if consecutiveWrong == 2, !assistOfferedThisQuestion {
            assistOfferedThisQuestion = true
            showParentAssist = true
        }
        let lostSeconds = progress.recordWrong(
            topic: q.topic,
            minutesPerCorrect: settings.minutesPerCorrectAnswer,
            grantsScreenTime: purpose.grantsScreenTime
        )
        LearningHistoryStore.shared.recordAnswer(
            topic: q.topic, correct: false, responseMs: 0,
            earnedMinutes: 0, streak: 0
        )
        if lostSeconds > 0 {
            // Gentle: small seconds dip + a "you can win it right back" message.
            flashSeconds("−\(lostSeconds) שְׁנִיּוֹת · כִּמְעַט!", positive: false)
            // Safe negative experience: never accusatory, always a way back.
            companion.console([
                "💡 כִּמְעַט! תְּשׁוּבָה נְכוֹנָה תַּחֲזִיר אֶת הַזְּמַן",
                "✨ קָרוֹב! אֶפְשָׁר לְהַחֲזִיר מִיָּד בַּשְּׁאֵלָה הַבָּאָה",
                "⭐ עוֹד תְּשׁוּבָה נְכוֹנָה וְחוֹזְרִים לְהִתְקַדֵּם"
            ].randomElement()!)
        } else {
            companion.console([
                "כִּמְעַט!",
                "מַמָּשׁ קָרוֹב",
                "בּוֹא נְנַסֶּה שׁוּב",
                "נְנַסֶּה אֶת הַבָּאָה"
            ].randomElement()!)
        }
    }
}

#Preview {
    QuestionRunnerView(mode: .smartFeed)
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
