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

    /// Big by default, but shrinks when the prompt contains a LONG word (or is a
    /// long sentence) — so a word never gets broken mid-way across two lines.
    private func questionFontSize(for prompt: String) -> CGFloat {
        let longestWord = prompt.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(\.count).max() ?? 0
        var size = questionSize
        if longestWord >= 13      { size = isCompact ? 26 : 34 }
        else if longestWord >= 10 { size = isCompact ? 32 : 42 }
        else if longestWord >= 8  { size = isCompact ? 37 : 50 }
        if prompt.count >= 75 { size = min(size, isCompact ? 30 : 40) }
        return size
    }
    private var topicEmojiSize: CGFloat { isCompact ? 30 : 36 }
    private var companionSize: CGFloat { isCompact ? 78 : 90 }
    /// 📐 A short screen (the foldable held open, an iPhone SE): the card and
    /// the answer tiles tighten, a question that still doesn't fit scrolls, and
    /// the buddy moves INTO the tool row (InlineBuddy) — floating over the
    /// screen it stood on answer 4, because a short screen has no free strip
    /// under the answers for it.
    @ObservedObject private var display = DisplayGeometry.shared
    private var portalEmojiSize: CGFloat { isCompact ? 130 : 180 }
    private var portalTitleSize: CGFloat { isCompact ? 36 : 56 }

    @StateObject private var companion = CompanionController()
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
    /// 💫 The rare REALLY-hard question worth real minutes (bonus pool).
    @State private var isBonusQuestion: Bool = false
    @State private var showBonusIntro: Bool = false
    /// Index of the last bonus event (super question / mystery portal). Enforces a
    /// cooldown so bonuses never cluster several-in-a-row — they stay special.
    @State private var lastBonusIndex: Int = -100
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

    /// 📐 Where the answers actually END, and how tall the screen actually is —
    /// both in `runnerSpace`. Measured, because every guess we made here was
    /// wrong on some device.
    @State private var answersBottom: CGFloat = 0
    /// 📖 How tall the reading passage actually is, so its card can hug it.
    @State private var passageHeight: CGFloat = 0
    @State private var runnerHeight: CGFloat = 0
    private static let runnerSpace = "runner"

    /// Do the answers TAKE the leftover height, or hug their own text?
    ///
    /// They take it wherever there is leftover height to take: the foldable, whose
    /// rail gave back a 56pt tool row, and any regular-width screen — an iPad has
    /// room to spare and hugging there leaves a third of the glass empty. A compact
    /// phone has no slack, so nothing changes for it.
    ///
    /// Both the block's height and WHICH grid draws it must follow this one answer:
    /// an expanded block drawn with the content-sized `LazyVGrid` just moves the
    /// empty space into the middle of the screen instead of the bottom.
    private func answersFill(_ q: Question) -> Bool {
        (display.hasRail && q.passage == nil) || !isCompact
    }

    /// Is there a real strip under the answers for the floating buddy to stand in?
    ///
    /// This used to be `!display.isShort`, and a short screen is simply not the
    /// only screen that runs out of room: an iPad holding a reading passage fills
    /// to the bottom too, and the buddy parked squarely on answer 4 there (Rani
    /// photographed it on Yoav's iPad). Now the strip is measured, and the buddy
    /// moves into the tool row wherever it isn't there — the same move a short
    /// screen already made, for the same reason.
    ///
    /// On the foldable it never floats at all: the rail holds טופי already, and
    /// two of him on one screen is worse than either place.
    private var buddyHasFreeStrip: Bool {
        guard !display.hasRail else { return false }
        guard runnerHeight > 0, answersBottom > 0 else { return !display.isShort }
        return runnerHeight - answersBottom >= companionSize + 24
    }

    // Smart Feed / learning state
    @State private var currentTopic: Topic = .math
    @State private var topicHistory: [Topic] = []
    /// Questions the child got wrong this session — re-asked later (the only
    /// allowed repeat). Deduped by prompt.
    ///
    /// `readyAt` is the earliest question index an item may come back at. Without
    /// it the question the child had just missed could be popped as the very next
    /// one: the screen swapped a question for the same question, and from the
    /// child's side a wrong answer simply didn't move on (Rani).
    @State private var reAskQueue: [(question: Question, readyAt: Int)] = []
    /// How many questions must pass before a missed one may return.
    private let reAskSpacing = 3
    /// 📖 Remaining questions of the current reading passage — served
    /// back-to-back so the child reads once and answers everything about it.
    @State private var readingQueue: [Question] = []
    @State private var questionShownAt: Date? = nil
    @State private var hadMistakeThisQuestion: Bool = false
    /// Whether the child leaned on a hint for the current question — fed to the
    /// adaptive engine (a hinted win shouldn't push difficulty up like a clean one).
    @State private var usedHintThisQuestion: Bool = false
    /// Last difficulty BAND (rounded adaptive level) served per topic, so we can
    /// celebrate stepping up / soften stepping down — only on a real band change,
    /// never on the per-question 70/20/10 sampling noise.
    @State private var lastBandByTopic: [Topic: Int] = [:]

    // Live-event / Parent Assist bookkeeping (one report per session each).
    @State private var reportedMilestone = false
    @State private var reportedWheel = false
    @State private var reportedDiscovery: Set<Topic> = []
    @State private var showParentAssist = false
    @ObservedObject private var parentHelp = ParentHelpManager.shared
    /// True once a parent's help removed an option on this question (for "success
    /// after help" analytics).
    @State private var receivedHelpThisQuestion = false
    @State private var showReportConfirm = false
    @State private var capMessageShown = false
    /// ⚡ The surprise round: the plan on screen (presents the cover), how many
    /// ran this session, and the question index the next one is due at.
    @State private var surprisePlan: SurprisePlan?
    @State private var surprisesThisSession = 0
    @State private var nextSurpriseAt = SurpriseRound.nextGap()

    /// Earn mode: the parent's session length, hard-capped at 30 ("no matter
    /// what"). Free mode: effectively unlimited — the child ends it with סיום.
    private var totalQuestions: Int {
        switch purpose {
        case .earnTime: return min(settings.questionsPerSession, 30)
        case .freePlay: return 100_000
        }
    }

    /// Mockup order, top-down: chips · timer · question card · answers · hint —
    /// no centring gap between the timer and the card.
    @ViewBuilder
    private func questionColumn(_ q: Question) -> some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            Spacer().frame(height: 6)
            // .id(q.id): each question gets a FRESH subtree, so a new
            // prompt can never render above the previous question's
            // option cards (the reused position-keyed views used to
            // linger mid-transition — and a tap on a stale card was
            // judged against the NEW question. Reported on-device in
            // the bonus arena; must never happen).
            questionHeader(q)
                .id("question-\(q.id)")
            Spacer().frame(height: 10)
            answersBlock(q)
                .id("answers-\(q.id)")
                // The answers take whatever the card gave back. Hugging the passage
                // freed ~140pt on an iPad and it all pooled at the bottom as one
                // empty third — the same wasted glass Rani objected to, moved down
                // the screen rather than removed. A compact screen is untouched:
                // there is no slack there to take.
                .frame(maxHeight: answersFill(q) ? .infinity : nil)
                .onGeometryChange(for: CGFloat.self) {
                    $0.frame(in: .named(Self.runnerSpace)).maxY
                } action: { answersBottom = $0 }
            // Room above the floating companion — none is needed where the
            // buddy lives in the rail and the answers already fill the screen.
            if !(display.hasRail && q.passage == nil) {
                // …and this reserves exactly the strip the floating buddy stands in.
                // Without it the filling answers would push him into the tool row on
                // the very device with the most room for him.
                Spacer(minLength: display.isShort ? AppSpacing.sm
                                  : (isCompact ? AppSpacing.xxl : companionSize + 24))
            }
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

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                // Beside the foldable's clock: the top rows stop short of it, and
                // the question starts BELOW the clock (Rani: "תוריד קצת את
                // השאלות למטה") — full width, never under the Wi-Fi.
                topBar.clearOfBar()
                    .fillsTopBand(above: DisplayProbeView.minimumTopMargin, alignment: .top)
                if let q = current {
                    // 📐 Laid out plainly when it fits; when it doesn't (a reading
                    // passage with long answers — in English they run to four lines),
                    // it scrolls instead of overflowing off the screen.
                    //
                    // This was gated on `display.isShort`, which left a tall screen
                    // with no protection at all: on Yoav's iPad the passage pushed the
                    // whole tool row under the bottom of the glass and "רמז" was cut
                    // in half at the edge. A screen that fits is unaffected either way.
                    ViewThatFits(in: .vertical) {
                        questionColumn(q)
                        ScrollView { questionColumn(q) }
                            .scrollIndicators(.hidden)
                    }
                } else {
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.md)

            // Companion in corner
            VStack {
                Spacer()
            }
            .padding(.bottom, AppSpacing.sm)

            // The buddy wanders and can be dragged, exactly like on the home
            // (Rani, 2026-09-07) — kept to the strip under the answers so it never
            // parks on a choice or on the 🔊 button. `topInset` is now where the
            // answers REALLY end rather than a fixed 150pt from the bottom, which
            // was only ever right on the screens it was guessed on.
            if buddyHasFreeStrip {
                GeometryReader { geo in
                    FloatingCompanion(
                        controller: companion,
                        profile: profiles.active,
                        size: companionSize,
                        topInset: min(max(120, answersBottom + 8),
                                      max(120, geo.size.height - companionSize - 28)),
                        bottomInset: 28,
                        horizontalInset: AppSpacing.md
                    )
                }
                .allowsHitTesting(true)
            }

            // 💬 What the rail's buddy says — pinned low, clear of the answers.
            if display.hasRail {
                VStack {
                    Spacer()
                    InlineBuddyBubble(controller: companion, clearance: 0)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.sm)
                }
            }

            // Effects overlays
            StarBurst(color: AppColor.starGold, trigger: burstTrigger)
            FancyConfetti(trigger: confettiTrigger)

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
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill((secondsFlashPositive ? AppColor.successMint : AppColor.flameOrange).opacity(0.95)))
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
            if showBonusIntro {
                bonusIntro
            }
            if showPortalIntro {
                portalIntro
            }
        }
        .coordinateSpace(name: Self.runnerSpace)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { runnerHeight = $0 }
        .rumble(trigger: rumbleTrigger)
        .sheet(isPresented: $showParentAssist) {
            if let q = current {
                ParentAssistView(question: q, topic: currentTopic) { }
                    .environment(\.layoutDirection, .app)
            }
        }
        // The parent answered from their notification → remove the wrong option.
        .onChangeCompat(of: parentHelp.lastReply?.kept) { _, kept in
            if kept != nil { applyParentHelp() }
        }
        .confirmationDialog(tr("דִּוּוּחַ עַל הַשְּׁאֵלָה"),
                            isPresented: $showReportConfirm, titleVisibility: .visible) {
            Button(tr("דַּוְּחוּ וְהַסִּירוּ אֶת הַשְּׁאֵלָה"), role: .destructive) {
                if let q = current {
                    QuestionReporter.shared.report(q)
                    Haptic.success()
                    createQuestion(super: false)   // replace with a fresh question
                }
            }
            Button(tr("בִּטּוּל"), role: .cancel) {}
        } message: {
            Text(tr("נָסִיר אֶת הַשְּׁאֵלָה הַזּוֹ וְלֹא נַצִּיג אוֹתָהּ שׁוּב, וְנִשְׁלַח עָלֶיהָ דִּוּוּחַ כְּדֵי שֶׁנְּשַׁפֵּר."))
        }
        // 🎚 The foldable's bar strip is this screen's tool row: ✕, then the
        // four controls that sat under the answers, then טופי himself. The row
        // they came from is gone, so the answers get its 56pt — and the buddy
        // stops standing on answer 4.
        .sideRail {
            SideRailButton(systemImage: "xmark", label: Gendered.g(tr("סְגֹר"), tr("סִגְרִי"))) { dismiss() }
            SideRailDivider()
            SideRailButton(systemImage: "flag", label: tr("דִּוּוּחַ עַל הַשְּׁאֵלָה")) { showReportConfirm = true }
            SideRailButton(systemImage: "speaker.wave.2.fill", label: tr("הַקְרָאָה")) {
                guard let q = current else { return }
                let spokenPrompt = (q.passage.map { $0 + ". " } ?? "") + q.readAloudText
                SpeechReader.shared.readQuestion(prompt: spokenPrompt, options: q.options)
            }
            if let q = current {
                if !isPreReader {
                    SideRailButton(systemImage: parentHelp.hasActiveRequest && parentHelp.activeQuestion == q.prompt
                                   ? "hourglass" : "hand.raised.fill",
                                   label: tr("בַּקָּשַׁת עֶזְרָה מֵהוֹרֶה")) {
                        guard !showFeedback, !receivedHelpThisQuestion else { return }
                        Haptic.light()
                        showParentAssist = true
                    }
                }
                if !showFeedback {
                    SideRailButton(emoji: "💡", label: tr("רֶמֶז")) { useHint(q: q) }
                        .opacity(canUseHint(q) ? 1 : 0.45)
                        .disabled(!canUseHint(q))
                    SideRailLabel(text: hintCost == 0 ? tr("(חִנָּם)") : tr("(\(hintCost) שְׁנִיּוֹת)"))
                }
            }
            SideRailDivider()
            InlineBuddy(controller: companion, profile: profiles.active, width: 50)
        }
        .onAppear { startSession() }
        // NOTE: the "child finished playing" report is NOT sent here — leaving an
        // adventure isn't leaving the app (they often start another). It's sent
        // once when the app backgrounds (see ChildTimeApp scenePhase handling).
        // Live presence: refresh this child device's "last seen" every 15s while
        // playing, so the parent dashboard shows "🟢 משחק עכשיו" in real time.
        .onReceive(Timer.publish(every: 15, on: .main, in: .common).autoconnect()) { _ in
            if settings.deviceRole == .child, let cid = profiles.activeID {
                Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
            }
        }
        // ⚡ סִבּוּב הַפְתָּעָה — the interstitial and its game; afterwards the
        // session simply carries on with the next question.
        .fullScreenCover(item: $surprisePlan, onDismiss: {
            MiniGameLedger.surpriseEarnsTime = false
            nextQuestion()
        }) { plan in
            SurpriseRoundFlow(plan: plan) { surprisePlan = nil }
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
        // The approved glass quiz: the same brand backdrop as the home, every
        // element a pane of glass on it. (World gradients + decorations retired.)
        ZStack {
            GlassBackdrop()
            SparkleField(count: 10, size: 11)
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
        case "story_forest":    FloatingOrbs.readingWorld()
        case "bonus_arena":     FloatingOrbs.bonusWorld()
        default:                FloatingOrbs.home()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        // Mockup `.q-top`: ✕ · ⭐ stars · "🧮 שאלה 4/10" as glass chips, then the
        // glass timer row.
        let total = max(1, totalQuestions)
        let done = min(questionIndex + 1, total)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                // ✕ heads the rail on the foldable — see `.sideRail` on the body.
                if !display.hasRail {
                    Button { dismiss() } label: {
                        quizChip { Image(systemName: "xmark").font(.system(size: 13, weight: .heavy)) }
                    }
                    .buttonStyle(.plain)
                }
                // With ✕ gone the three chips are the whole row, so they sit in
                // the middle of it rather than pushed to one end (Rani).
                Spacer(minLength: 0)
                quizChip {
                    Text("💎 \(progress.diamonds.currencyShort)")
                        .foregroundStyle(AppColor.diamondBlue)
                        .numericTextTransition(Double(progress.diamonds))
                }
                quizChip {
                    Text("⭐ \(progress.stars.currencyShort)")
                        .foregroundStyle(AppColor.starGold)
                        .numericTextTransition(Double(progress.stars))
                }
                quizChip {
                    Text(tr("\(current?.topic.emoji ?? themeWorld.emoji) שְׁאֵלָה \(done)/\(total)"))
                }
                if display.hasRail { Spacer(minLength: 0) }
            }
            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .monospacedDigit()
            if earnsTime { earnedTimeBar }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    private func quizChip<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.30), lineWidth: 1))
    }

    /// Only Earn-to-Unlock sessions grow play-time.
    private var earnsTime: Bool { purpose.grantsScreenTime }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", max(0, seconds) / 60, max(0, seconds) % 60)
    }

    /// The earned balance, to the second — each right answer's "+24 שניות"
    /// lands straight in it (see `ProgressStore.payEarned`).
    private var earnedTimeBar: some View {
        EarnedBalanceRow(size: 14)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassPane(radius: 16, shadow: false)
    }

    /// A small currency pill (emoji + value), animating its number on change.
    private func statChip(_ emoji: String, _ value: Int, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(emoji).font(.system(size: isCompact ? 14 : 16))
            Text(value.currencyShort)
                .font(.system(size: isCompact ? 14 : 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .numericTextTransition(Double(value))
        }
        .padding(.horizontal, isCompact ? 9 : 11)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.55), lineWidth: 1))
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

    // Use the ACTIVE child's resolved cap (per-child overrides the device global)
    // so the chip always matches what's actually enforced.
    private var dailyCapChipVisible: Bool { progress.dailyCap.enabled }

    private var dailyCapChip: some View {
        let earned = progress.minutesEarnedToday
        let cap = progress.dailyCap.max
        let atCap = earned >= cap
        let tint: Color = atCap ? AppColor.almostWarm : AppColor.successMint
        return HStack(spacing: 6) {
            Image(systemName: atCap ? "timer.circle.fill" : "timer")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            Text(atCap ? Gendered.g(tr("הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי"), tr("הִגַּעַתְּ לַמַּקְסִימוּם הַיּוֹמִי")) : tr("\(earned)/\(cap) דַּק' הַיּוֹם"))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.6), lineWidth: 1))
    }

    // MARK: - Question content

    /// 📖 The passage itself — one definition, used both as the content-sized
    /// candidate and as the scrolling one, so they can never drift apart.
    private func passageText(_ passage: String) -> some View {
        Text(passage)
            .font(.system(size: isCompact ? 17 : 21, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.md)
    }

    /// Topic indicator + the prompt card (the upper block).
    @ViewBuilder
    private func questionHeader(_ q: Question) -> some View {
        // Mockup `.qcard`: ONE glass card — topic line (with the two small
        // controls at its ends), the passage / prompt, "בחרו תשובה אחת".
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Spacer(minLength: 4)
                HStack(spacing: 8) {
                    Text(q.topic.emoji).font(.system(size: topicEmojiSize))
                    if isBonusQuestion {
                        Text(tr("💫 שְׁאֵלַת עֲנָק! +\(RewardEngine.bonusQuestionMinutes) דַּקּוֹת"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColor.starGold).glow(AppColor.starGold, radius: 10)
                    } else if isBonusArena {
                        Text(tr("💫 \(q.topic.emoji) דַּקּוֹת כְּפוּלוֹת!"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColor.starGold).glow(AppColor.starGold, radius: 10)
                    } else if isSuperQuestion {
                        Text(tr("⭐ שְׁאֵלַת זָהָב!"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColor.starGold).glow(AppColor.starGold, radius: 8)
                    } else if isInPortal {
                        Text(tr("🌀 בּוֹנוּס ×3 כּוֹכָבִים!"))
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white).glow(AppColor.gemPurple, radius: 10)
                    } else {
                        Text(q.topic.displayName + (q.skill.map { " · \(SkillCatalog.name($0))" } ?? ""))
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(GlassInk.secondary)
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
            }

            // 📖 The passage card — the child reads here, then answers below.
            // Scrolls inside its own frame so a long passage can never squeeze
            // the answers off-screen.
            if let passage = q.passage {
                // A ceiling, and NO floor. The floor was protecting against the
                // opposite problem — the big question text squeezing a ז׳–ח׳ passage
                // down to a slot — but it fired unconditionally, so on an iPad, where
                // the passage wraps wide into two lines, it held 200pt open under four
                // words. Rani photographed the dead glass on Yoav's iPad.
                //
                // Fit the text when it fits; scroll inside the ceiling when it doesn't.
                // That is what the floor was actually for, without the empty rectangle.
                // Measured, not proposed: `.frame(maxHeight:)` in SwiftUI is EXPANSIVE —
                // it takes everything offered up to the bound — so bounding the card
                // that way just rebuilt the same empty rectangle one ceiling lower.
                // An exact height, read from the text itself, is the only thing that
                // hugs short content and still caps a long passage.
                let ceiling: CGFloat = isCompact ? (display.isShort ? 150 : 210) : 280
                ScrollView {
                    passageText(passage)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            passageHeight = $0
                        }
                }
                .frame(height: min(passageHeight > 0 ? passageHeight : ceiling, ceiling))
                .layoutPriority(1)
                .glassInset(radius: 16)
                .environment(\.layoutDirection, .app)   // the passage reads in the language's direction
            }

            // Early-reader visual questions carry the instruction in `spoken` (the
            // prompt itself is pictures). Show it as a written line ABOVE the
            // pictures too — e.g. "כַּמָּה כּוֹכָבִים?" over the ⭐⭐ — not only read aloud.
            if let instruction = q.spoken, !instruction.isEmpty {
                Text(instruction)
                    .font(.system(size: isCompact ? 26 : 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppSpacing.lg)
            }

            Text(Question.displayPrompt(q.prompt, rightToLeft: LanguageStore.shared.current.isRightToLeft))
                // Under a passage the text is the star — the question steps down a size.
                .font(.system(size: min(questionFontSize(for: q.prompt), q.passage != nil ? (isCompact ? 22 : 28) : (isCompact ? (display.isShort ? 25 : 30) : 38)) * (display.isShort ? 0.86 : 1), weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .fixedSize(horizontal: false, vertical: true)   // never truncate the question
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.sm)

            Text(tr("בַּחֲרוּ תְּשׁוּבָה אַחַת"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 16)
        .glassPane(radius: 16)
        .overlay {
            if isSuperQuestion || isBonusQuestion || isBonusArena {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppColor.starGold.opacity(0.9), lineWidth: 2)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
    }

    /// A consistent round icon button for the question's control row (read-aloud,
    /// report) — both the same size so the row reads tidy.
    private func cardIconButton(system: String, fg: Color, bg: Color,
                                glow: Color = .clear,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(fg)
                .frame(width: 36, height: 36)
                .background(bg, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                .glow(glow, radius: 5)
        }
        .buttonStyle(.plain)
    }

    /// The answers grid + the hint / magic-wand row (the lower block).
    @ViewBuilder
    private func answersBlock(_ q: Question) -> some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            if answersFill(q) {
                fillingOptions(for: q)
            } else {
                optionsGrid(for: q)
            }

            // Mockup `.streak`: "🔥 3 ברצף · עוד 2 ובונוס!" in gold under the answers.
            if progress.currentStreak >= 2 {
                Text(tr("🔥 \(progress.currentStreak) בְּרֶצֶף") + "!")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
                    .contentTransition(.numericText())
            }
            // Mockup `.hint`: what a right answer is worth, as a glass line.
            // Not on a short screen: the timer bar at the top already shows the
            // seconds, and this line pushed a three-line question off the screen.
            if earnsTime && !display.isShort {
                Text(tr("💡 כָּל תְּשׁוּבָה נְכוֹנָה = \(progress.secondsPerCorrect) שְׁנִיּוֹת שֶׁל מִשְׂחָק"))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9).padding(.horizontal, 12)
                    .glassInset(radius: 16)
                    .padding(.horizontal, AppSpacing.md)
            }

            // 🎚 On the foldable every one of these lives in the rail, and this
            // 56pt row disappears — real height back to the answers on a 644pt
            // screen, and the buddy stops standing on answer 4.
            if !display.hasRail {
                // Hint shows whenever it's payable; wand only after 2 wrong picks.
                // Fixed height so the layout never jumps when these appear/disappear
                // (e.g. the hint hides the moment the answer is locked in).
                // RTL row: hint in the middle, 🚩 🔊 🙋 together on the right; the
                // left end stays empty for the buddy.
                HStack(spacing: AppSpacing.sm) {
                    cardIconButton(system: "flag", fg: .white.opacity(0.7), bg: .white.opacity(0.14)) {
                        showReportConfirm = true
                    }
                    cardIconButton(system: "speaker.wave.2.fill", fg: .white, bg: .white.opacity(0.22)) {
                        Haptic.light()
                        // For a passage question, read the passage first — one
                        // utterance, so the two don't cut each other off.
                        let spokenPrompt = (q.passage.map { $0 + ". " } ?? "") + q.readAloudText
                        SpeechReader.shared.readQuestion(prompt: spokenPrompt, options: q.options)
                    }
                    if !isPreReader {
                        askParentButton(for: q)
                    }
                    Spacer(minLength: 0)
                    if !showFeedback {
                        hintButton(for: q)
                    }
                    if consecutiveWrong >= 2 && !showFeedback {
                        magicWandButton
                    }
                    Spacer(minLength: 0)
                    if !buddyHasFreeStrip {
                        // 📐 Nowhere under the answers to stand: the buddy lives IN
                        // this slot instead. A short screen was never the only case.
                        InlineBuddy(controller: companion, profile: profiles.active, width: 44)
                    } else {
                        Color.clear.frame(width: companionSize * 0.7, height: 1)   // room for the buddy
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .overlay(alignment: .trailing) {
                    if !buddyHasFreeStrip {
                        InlineBuddyBubble(controller: companion, clearance: AppSpacing.md + 44 + 6)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: consecutiveWrong)
            }
        }
    }

    /// 🙋 Ask a parent — available on every question, not only after mistakes
    /// (Rani: once a wrong answer started moving on, a child had no way left to
    /// ask). Pulses after two misses in a row; one request per question and a
    /// two-minute gap between requests, so a parent's phone isn't flooded.
    @ViewBuilder
    private func askParentButton(for q: Question) -> some View {
        let waiting = parentHelp.hasActiveRequest && parentHelp.activeQuestion == q.prompt
        let stuck = consecutiveWrong >= 2 && !receivedHelpThisQuestion && !waiting && !showFeedback
        cardIconButton(system: waiting ? "hourglass" : "hand.raised.fill",
                       fg: .white,
                       bg: waiting ? AppColor.starGold.opacity(0.55) : .white.opacity(stuck ? 0.34 : 0.22),
                       glow: stuck ? AppColor.starGold : .clear) {
            let girl = profiles.active?.gender == .girl
            if waiting {
                companion.console(tr("💌 הַבַּקָּשָׁה בַּדֶּרֶךְ — אֶפְשָׁר לְהַמְשִׁיךְ לַחְשֹׁב בֵּינְתַיִם"))
                return
            }
            guard !showFeedback else { return }
            // One request per question — backing out of the sheet doesn't count.
            if receivedHelpThisQuestion {
                companion.console(tr("כְּבָר קִבַּלְנוּ עֶזְרָה בַּשְּׁאֵלָה הַזֹּאת 💛"))
                return
            }
            let childID = profiles.activeID?.uuidString ?? ""
            if parentHelp.cooldownRemaining(childID: childID) > 0 {
                companion.console(girl ? tr("⏳ עוֹד רֶגַע תּוּכְלִי לְבַקֵּשׁ שׁוּב — נַסִּי לְבַד בֵּינְתַיִם")
                                        : tr("⏳ עוֹד רֶגַע תּוּכַל לְבַקֵּשׁ שׁוּב — נַסֵּה לְבַד בֵּינְתַיִם"))
                return
            }
            Haptic.light()
            showParentAssist = true
        }
        .scaleEffect(stuck ? 1.08 : 1)
        .animation(stuck ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: stuck)
        .accessibilityLabel(tr("בַּקָּשַׁת עֶזְרָה מֵהוֹרֶה"))
    }

    /// The equipped character is the "smart helper". Higher tiers help more:
    /// rare/epic add a topic nudge, legendary/mythic add a method explanation
    /// AND a free hint. This is the payoff for a pricier character.
    private var helperLevel: Character3D.HelpLevel {
        (profiles.active?.character ?? Character3DCatalog.find(nil)).helpLevel
    }

    /// A hint costs exactly what a mistake costs: half a step off the cycle
    /// progress — 12 seconds with the default settings — and never a minute the
    /// child already banked. It used to take 2 banked minutes, which is five
    /// right answers for removing ONE wrong option out of four.
    private var hintCost: Int { helperLevel == .explain ? 0 : progress.hintCostSeconds }

    private func canUseHint(_ q: Question) -> Bool {
        guard !showFeedback else { return false }
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
            // ONE Text, not an HStack of three: the row also holds 🚩 🔊 🙋 and the
            // buddy, so a longer label (Russian "Подсказка (2 мин.)") has to shrink
            // to fit. Three separate Texts let SwiftUI squeeze one of them until it
            // truncated to "Под…" while the others stayed full size; concatenated,
            // minimumScaleFactor scales the whole label evenly instead.
            (Text("💡 ")
             + Text(tr("רֶמֶז"))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
             + Text("  " + (hintCost == 0 ? tr("(חִנָּם)") : tr("(\(hintCost) שְׁנִיּוֹת)")))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.75)))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppColor.starGold.opacity(enabled ? 0.7 : 0.3), lineWidth: 1))
            .opacity(enabled ? 1.0 : 0.45)
        }
        .buttonStyle(.juicy)
        .disabled(!enabled)
    }

    /// 📐 The four answers, filling the height the tool row used to take.
    ///
    /// `LazyVGrid` sizes its rows to their content, so with the row gone the
    /// answers bunched at the top of the screen and left a dead band under them
    /// (Rani: "זה לא נראה טוב התשובות"). Two explicit rows of two share the
    /// space instead, and every card is the same size — which is also how a
    /// quiz answer should read: four equal choices, not four different ones.
    private func fillingOptions(for q: Question) -> some View {
        let opts = Array(q.options.enumerated())
        let rows = stride(from: 0, to: opts.count, by: 2).map { Array(opts[$0..<min($0 + 2, opts.count)]) }
        return VStack(spacing: AppSpacing.md) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: AppSpacing.md) {
                    ForEach(row, id: \.offset) { idx, opt in
                        OptionCard(
                            text: opt,
                            feedback: feedbackForIndex[idx] ?? .normal,
                            index: idx
                        ) {
                            pickOption(idx, q: q)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, AppSpacing.md)
        // Answers always number right-to-left — 1 top-right, 2 top-left, 3, 4.
        .environment(\.layoutDirection, .app)
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
        // Answers always number right-to-left — 1 top-right, 2 top-left, 3, 4 —
        // no matter how the screen was presented (a fullScreenCover can arrive
        // LTR, and on Rani's phone 1 landed top-left).
        .environment(\.layoutDirection, .app)
    }

    private var magicWandButton: some View {
        Button {
            companion.cheer(Gendered.g(tr("בּוֹא נְנַסֶּה אַחֶרֶת"), tr("בּוֹאִי נְנַסֶּה אַחֶרֶת")))
            withAnimation(.spring()) {
                regenerateQuestion()
            }
        } label: {
            // ONE Text, scaled as a whole — the same rule the hint pill already
            // follows. This button only appears after two wrong answers in a row,
            // and it joins a row that already holds 🚩 🔊 🙋, the hint and the
            // buddy: on a 402pt iPhone the two pills squeezed each other until
            // the wand read "הַ" and the hint read "רְמָ…".
            (Text("🪄 ") + Text(Gendered.g(tr("הַחְלֵף שְׁאֵלָה"), tr("הַחְלִיפִי שְׁאֵלָה"))))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.30), lineWidth: 1))
        }
        .buttonStyle(.juicy)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Bonus-question intro animation

    /// 💫 Full-screen announcement before the rare really-hard bonus question —
    /// same theatrical beat as the portal, but the promise here is MINUTES.
    private var bonusIntro: some View {
        ZStack {
            AppGradient.gold.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.flameOrange, .white],
                count: 6, maxSize: 260, opacity: 0.4
            )
            SparkleField(count: 30, size: 15)

            VStack(spacing: AppSpacing.lg) {
                Text("💫")
                    .font(.system(size: portalEmojiSize))
                    .scaleEffect(showBonusIntro ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: showBonusIntro)
                    .glow(AppColor.starGold, radius: 30)
                    .shadow(color: .black.opacity(0.3), radius: 10, y: 6)

                Text(tr("שְׁאֵלַת עֲנָק!"))
                    .font(.system(size: portalTitleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .glow(AppColor.flameOrange, radius: 16)

                Text(tr("🎮 +\(RewardEngine.bonusQuestionMinutes) דַּקּוֹת"))
                    .font(.system(size: isCompact ? 34 : 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black.opacity(0.25)))

                Text(tr("שְׁאֵלָה קָשָׁה בִּמְיוּחָד — עֲנוּ נָכוֹן וְקַבְּלוּ אֶת כָּל הַדַּקּוֹת!"))
                    .font(.system(size: isCompact ? 18 : 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .transition(.opacity)
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

                Text(tr("שְׁאֵלַת בּוֹנוּס!"))
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

                Text(tr("עֲנוּ נָכוֹן וְקַבְּלוּ פִּי 3 כּוֹכָבִים!"))
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
        // 🏆 Straight-to-questions worlds skip the chooser — still a first visit.
        if case .world(let w) = mode, !w.isBonusWorld { progress.markVisited(w.id) }
        LearningHistoryStore.shared.recordSessionStart(purpose: purpose)
        // Notify the parent ONCE per app-sitting (the first adventure), not on each
        // adventure — and the matching "finished" report fires on app background.
        progress.beginSitting()
        // Mark this child "playing now" IMMEDIATELY (don't wait for the 15s tick),
        // so the parent dashboard floats them to the top the moment they start.
        if settings.deviceRole == .child, let cid = profiles.activeID {
            Task { await HouseholdManager.shared.registerDevice(forChildID: cid) }
        }
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
        surprisesThisSession = 0
        nextSurpriseAt = SurpriseRound.nextGap()
        QuestionMemory.shared.beginSession()   // no repeats within this session
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            companion.cheer(mode.isFeed ? tr("טוֹפִי טַיים — קָדִימָה! 🧠") : Gendered.g(tr("מוּכָן? קָדִימָה!"), tr("מוּכָנָה? קָדִימָה!")))
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

        // ⚡ A surprise round is due — show it; the next question follows when
        // it's over (the cover's onDismiss calls back in here).
        if surpriseRoundDue {
            nextSurpriseAt = questionIndex + SurpriseRound.nextGap()
            if let plan = SurpriseRound.plan(grade: profiles.active?.effectiveGrade ?? 1,
                                             profile: profiles.active, context: mode.fixedTopic) {
                surprisesThisSession += 1
                SpeechReader.shared.stop()
                MiniGameLedger.surpriseEarnsTime = earnsTime
                surprisePlan = plan
                return
            }
        }

        // Decide special events. A cooldown keeps at least 3 normal questions
        // between bonuses so they never fire several-in-a-row (which read as a bug
        // and made the bonus feel cheap).
        // No random special events inside the bonus arena — every question there
        // is already the hard pool with doubled minutes.
        let bonusCooldownOK = !isBonusArena && (questionIndex - lastBonusIndex) >= 3
        // 💫 Bonus question first — it's the rarest and pays real minutes, so it
        // must not be crowded out by the cheaper events. Minutes only exist in
        // earn mode, and the pool is text-based → not for pre-readers.
        let bonusQ = bonusCooldownOK && purpose.grantsScreenTime && !isPreReader
            && !progress.atDailyCap   // never promise minutes the cap won't allow today
            && !progress.bonusQuestionServedToday   // a jackpot: once a day, not every other session
            && EventEngine.shouldFireBonusQuestion(questionIndex: questionIndex, totalQuestions: totalQuestions)
        let mystery = bonusCooldownOK && !bonusQ && EventEngine.shouldFireMysteryPortal(questionIndex: questionIndex, totalQuestions: totalQuestions)
        let superQ = bonusCooldownOK && !bonusQ && !mystery && EventEngine.shouldFireSuperQuestion(questionIndex: questionIndex, totalQuestions: totalQuestions)
        if bonusQ || mystery || superQ { lastBonusIndex = questionIndex }

        if bonusQ {
            progress.markBonusQuestionServed()
            isInPortal = false
            showBonusIntro = true
            SoundPlayer.shared.play(.portalAppear)
            companion.wow(tr("שְׁאֵלַת עֲנָק! 💫 שָׁוָה \(RewardEngine.bonusQuestionMinutes) דַּקּוֹת"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { showBonusIntro = false }
                createQuestion(super: false, bonus: true)
            }
        } else if mystery {
            isInPortal = true
            showPortalIntro = true
            SoundPlayer.shared.play(.portalAppear)
            companion.wow(tr("שְׁאֵלַת בּוֹנוּס! 🌟 פִּי 3 כּוֹכָבִים"))
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
            if w.isBonusWorld {
                // 💫 The arena mixes ALL the child's enabled topics.
                let pool = Array(profiles.active?.playableTopics ?? Set(Topic.core))
                return pool.randomElement() ?? .logic
            }
            return w.topic
        case .smartFeed:
            let profile = LearningProfile(store: progress, settings: settings)
            let engine = LearningFeedEngine(profile: profile)
            return engine.nextTopic(history: topicHistory, index: questionIndex)
        }
    }

    private func createQuestion(super isSuper: Bool, bonus: Bool = false) {
        SpeechReader.shared.stop()
        isSuperQuestion = isSuper
        isBonusQuestion = bonus
        selectedIndex = nil
        feedbackForIndex = [:]
        showFeedback = false
        hadMistakeThisQuestion = false
        usedHintThisQuestion = false
        receivedHelpThisQuestion = false
        // A request still open for the previous question is closed so the
        // parent's banner doesn't offer help on a question that's gone.
        parentHelp.expireActiveRequest()

        // Re-ask a previously-wrong question every few questions (spaced out) —
        // the only repeat we allow.
        if !isSuper, !bonus, questionIndex > 0, questionIndex % 3 == 0,
           let slot = reAskQueue.firstIndex(where: { $0.readyAt <= questionIndex && $0.question.id != current?.id }) {
            let requeued = reAskQueue.remove(at: slot).question
            currentTopic = requeued.topic
            current = requeued
            questionShownAt = Date()
            if isPreReader { SpeechReader.shared.speak(requeued.readAloudText) }
            return
        }

        // 📖 Finish the CURRENT reading passage before choosing a new topic —
        // otherwise the anti-repeat topic picker diverts the passage's later
        // questions and the kid has to re-read it.
        if !isSuper, !bonus, !isPreReader, !readingQueue.isEmpty {
            let rq = readingQueue.removeFirst()
            currentTopic = .reading
            topicHistory.append(.reading)
            QuestionMemory.shared.markServedThisSession(sessionKey(rq))
            current = rq
            questionShownAt = Date()
            return
        }

        let topic = pickTopic()
        currentTopic = topic
        topicHistory.append(topic)

        // Adaptive difficulty: the base is this child's parent-set per-topic level
        // (anchor). The engine maintains a continuous level that drifts around it
        // from the child's recent performance; we then sample a tier for THIS
        // question (mostly at-level, with a few harder/easier mixed in).
        let baseDiff = profiles.active?.difficulty(for: topic) ?? .easy
        let level = progress.adaptiveLevel(for: topic, base: baseDiff)
        let effective = AdaptiveDifficultyEngine.sampledDifficulty(forLevel: level, base: baseDiff)
        // Celebrate / soften only when the underlying level BAND actually shifts
        // (positive framing — never "it got hard" or "we lowered you").
        let band = Int(level.rounded())
        if let prev = lastBandByTopic[topic], prev != band {
            if band > prev {
                companion.hype(Gendered.g(tr("מִתְקַדֵּם שָׁלָב! 🚀"), tr("מִתְקַדֶּמֶת שָׁלָב! 🚀")))
            } else {
                companion.cheer(Gendered.g(tr("בּוֹא נַעֲשֶׂה חִימּוּם קָטָן 🌟"), tr("בּוֹאִי נַעֲשֶׂה חִימּוּם קָטָן 🌟")))
            }
        }
        lastBandByTopic[topic] = band
        // Early readers (age 4) get picture-based questions instead of text ones.
        let preReader = isPreReader
        // 📖 Reading: the unit is a PASSAGE — pop the next question about the
        // current passage; fetch a fresh passage when the group is done. Falls
        // through to the generic path (single passage question) only if the
        // whole pool was filtered out.
        if topic == .reading, !preReader, !bonus, !isBonusArena {
            if readingQueue.isEmpty {
                readingQueue = ReadingContent.nextGroup(target: effective, grade: profiles.active?.effectiveGrade)
                    .filter { !QuestionReporter.shared.isHidden($0.prompt) }
            }
            if !readingQueue.isEmpty {
                let rq = readingQueue.removeFirst()
                QuestionMemory.shared.markServedThisSession(sessionKey(rq))
                current = rq
                questionShownAt = Date()
                return
            }
        }
        // 🏆 A world's silver/gold tier asks one/two grades up (pre-readers stay put).
        var childGrade = profiles.active?.effectiveGrade
        if case .world(let w) = mode, let g = childGrade, g >= 1 {
            childGrade = min(CurriculumMath.topGrade, g + progress.tierGradeOffset(in: w.id))
        }
        func makeQuestion() -> Question {
            if bonus || isBonusArena { return QuestionGenerator.generateBonus(topic: topic, grade: childGrade) }
            return preReader
                ? PreReaderContent.generate(topic: topic)
                : QuestionGenerator.generate(topic: topic, difficulty: effective, grade: childGrade)
        }
        var q = makeQuestion()
        // Generated questions (math + every pre-reader visual) can repeat — re-roll
        // a few times to avoid serving the same one twice this round. (Bank
        // questions already avoid session repeats via QuestionMemory.)
        if preReader || topic == .math {
            var tries = 0
            while QuestionMemory.shared.wasServedThisSession(sessionKey(q)), tries < 8 {
                q = makeQuestion()
                tries += 1
            }
        }
        // Skip questions a parent reported/removed.
        var hideTries = 0
        while QuestionReporter.shared.isHidden(q.prompt), hideTries < 12 {
            q = makeQuestion()
            hideTries += 1
        }
        QuestionMemory.shared.markServedThisSession(sessionKey(q))
        current = q
        questionShownAt = Date()
        // Read the instruction aloud automatically for early readers.
        if preReader { SpeechReader.shared.speak(q.readAloudText) }
        #if DEBUG
        // 📏 DEMO_AUTOTAP: answer each question correctly after 2.5s, to time the tap path.
        if ProcessInfo.processInfo.environment["DEMO_AUTOTAP"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { pickOption(q.correctIndex, q: q) }
        }
        #endif
    }

    /// ⚡ After 12–15 questions (twice a session at most) — never in the bonus
    /// arena, never for a pre-reader, never in the middle of a reading passage
    /// or right after a 💫 bonus question. (The boss battle is its own screen.)
    private var surpriseRoundDue: Bool {
        questionIndex >= nextSurpriseAt
            && surprisesThisSession < SurpriseRound.maxPerSession
            && !isBonusArena && !isPreReader
            && readingQueue.isEmpty && current?.passage == nil
            && !isBonusQuestion
            && MiniGameKind.availableForActiveChild
    }

    /// The active child is in the pre-reader (גן) picture mode — driven by the
    /// effective grade (auto-advancing), so a גן חובה kid graduates to real
    /// questions the September they start כיתה א׳.
    private var isPreReader: Bool {
        guard let p = profiles.active else { return false }
        return p.effectiveGrade < 1
    }

    /// 💫 This session is the bonus arena: every question comes from the
    /// extra-hard pool, minutes pay double, no random special events.
    private var isBonusArena: Bool {
        if case .world(let w) = mode { return w.isBonusWorld }
        return false
    }

    /// Dedup key matching QuestionMemory's (prompt + correct answer).
    private func sessionKey(_ q: Question) -> String {
        let correct = q.correctIndex < q.options.count ? q.options[q.correctIndex] : ""
        return "\(q.prompt)|\(correct)"
    }

    /// A parent answered the help notification. Remove the WRONG option of the
    /// two they were shown (never the correct answer — safety), and celebrate.
    private func applyParentHelp() {
        guard let reply = parentHelp.lastReply else { return }
        // The parent answered after the kid already moved on (or already
        // answered this one): say so warmly instead of silently dropping it.
        guard let q = current, !showFeedback, parentHelp.activeQuestion == nil || parentHelp.activeQuestion == q.prompt else {
            parentHelp.lastReply = nil
            parentHelp.stopListening()
            companion.wow(tr("💌 הָעֶזְרָה הִגִּיעָה — אֲבָל כְּבָר הִתְקַדַּמְנוּ הָלְאָה!"))
            return
        }
        let correct = q.correctIndex < q.options.count ? q.options[q.correctIndex] : ""
        // The wrong one of the two shown to the parent (= whichever isn't correct).
        guard let toRemove = [reply.kept, reply.removed].first(where: { $0 != correct }),
              let idx = q.options.firstIndex(of: toRemove),
              (feedbackForIndex[idx] ?? .normal) == .normal else {
            parentHelp.lastReply = nil
            parentHelp.stopListening()
            companion.wow(tr("💌 הָעֶזְרָה הִגִּיעָה! הַתְּשׁוּבָה הַזֹּאת כְּבָר יְרוּקָה 😉"))
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
            feedbackForIndex[idx] = .eliminated
        }
        SoundPlayer.shared.play(.streakUp)
        Haptic.success()
        burstTrigger += 1
        companion.wow(Gendered.g(tr("✨ קִבַּלְתָּ רֶמֶז מֵהוֹרֶה!"), tr("✨ קִבַּלְתְּ רֶמֶז מֵהוֹרֶה!")))
        receivedHelpThisQuestion = true
        parentHelp.lastReply = nil
        parentHelp.stopListening()
        AppAnalytics.log("parent_help_applied", ["topic": q.topic.rawValue])
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

    /// 👆 The tap's answer first, the bookkeeping right after. Recording an
    /// answer (progress, learning history, the parent's live feed, the wallet)
    /// took ~60ms on the main thread on an M-series simulator — several times
    /// that on a child's older iPad — and the green / red tile could not draw
    /// until it finished (Rani: "יש סוג של דיליי כזה" on Dan's iPad). So the
    /// tile's new state is set synchronously and this runs a moment later.
    /// A timer, not `main.async`: the frame is committed only when the run
    /// loop is about to sleep, and queued main-queue work keeps it awake — a
    /// timer guarantees it sleeps (and draws) first. 30ms is two frames.
    private func afterThisFrame(_ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: work)
    }

    private func pickOption(_ idx: Int, q: Question) {
        SpeechReader.shared.stop()   // the child answered — don't keep reading a question that's gone
        // A tap must belong to the question ON SCREEN. If a stale option view
        // (mid-removal during the question swap) fires its captured closure,
        // ignore it — never judge one question's tap against another.
        guard q.id == current?.id else { return }
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
            afterThisFrame { handleCorrect(q: q) }
            // If the child stumbled on this one, queue it to re-ask later — the
            // only question that's allowed to repeat in a session.
            if hadMistakeThisQuestion, !reAskQueue.contains(where: { $0.question.prompt == q.prompt }) {
                reAskQueue.append((q, questionIndex + reAskSpacing))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                questionIndex += 1
                nextQuestion()
            }
        } else if isBonusQuestion {
            // 💫 Bonus: the rare event is its own challenge — flash the pick red,
            // dim it, and let the kid keep trying on THIS question (old behavior).
            feedbackForIndex[idx] = .wrong
            afterThisFrame { handleWrong(q: q) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    feedbackForIndex[idx] = .dimmed
                }
            }
        } else {
            // Wrong: flash red briefly, then MOVE ON to a different question —
            // the missed one returns fresh a few questions later (the existing
            // spaced re-ask queue). Grinding one stuck question was frustrating;
            // coming back to it after a breather teaches better (Rani).
            // Do NOT reveal the correct answer.
            feedbackForIndex[idx] = .wrong
            afterThisFrame { handleWrong(q: q) }
            if !reAskQueue.contains(where: { $0.question.prompt == q.prompt }) {
                reAskQueue.append((q, questionIndex + reAskSpacing))
            }
            companion.cheer(tr("נַחְזֹר לָזוֹ עוֹד מְעַט 💪"))
            showFeedback = true   // lock the grid during the short transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard q.id == current?.id else { return }   // already moved on
                questionIndex += 1
                nextQuestion()
            }
        }
    }

    // MARK: - Hint

    private func useHint(q: Question) {
        guard q.id == current?.id else { return }   // stale view — see pickOption
        guard canUseHint(q) else { return }
        // Spend the minutes (0 for a free legendary/mythic helper → always true).
        // The cost comes off the cycle progress, exactly like a mistake — so a
        // hint can never leave a child with fewer minutes than they had.
        progress.chargeHint()
        usedHintThisQuestion = true   // adaptive engine: a hinted win counts as "shaky"

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
            companion.cheer(Gendered.g(tr("הֵסַרְתִּי לְךָ אוֹפְּצְיָה! אַתָּה יָכוֹל 💪"), tr("הֵסַרְתִּי לָךְ אוֹפְּצְיָה! אַתְּ יְכוֹלָה 💪")))
        case .hint:
            companion.cheer(tr("הֵסַרְתִּי אוֹפְּצְיָה. \(HintContent.hint(q.topic))"))
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
            isMysteryPortal: isInPortal,
            isBonusQuestion: isBonusQuestion
        )
        // Was the child already at their daily maximum *before* this answer?
        // If so, they keep playing & learning but earn no more minutes.
        let earnsTime = purpose.grantsScreenTime
        let cappedBefore = earnsTime && progress.atDailyCap

        // Whole minutes this answer moved the wallet across (for the parent's
        // reports); the seconds themselves land with every right answer.
        let minutesBefore = progress.pendingMinutes
        let earned = progress.recordCorrect(
            ctx,
            minutesPerCorrect: settings.minutesPerCorrectAnswer,
            responseMs: responseMs,
            hadMistakeThisQuestion: hadMistakeThisQuestion,
            hintUsed: usedHintThisQuestion,
            grantsScreenTime: earnsTime,
            cycleMultiplier: isBonusArena ? 2 : 1,   // 💫 arena: double minutes
            affectsAdaptive: !isBonusArena && !isBonusQuestion
        )
        earnedThisSession += earned
        // 🌈 Topic balance — celebrate the variety bonus, or nudge (positively)
        // toward other worlds when one topic hit its daily soft cap. One-shot
        // flags set synchronously by recordCorrect just above.
        // The big "+N דקות" popup is for real bonuses only — the per-answer
        // seconds already rise into the timer.
        var bonusPopupMinutes = progress.varietyBonusJustEarned
        if progress.varietyBonusJustEarned > 0 {
            companion.hype(tr("קֶסֶם הַגִּוּוּן! 🌈 +\(progress.varietyBonusJustEarned) דַּקּוֹת בּוֹנוּס!"))
            progress.varietyBonusJustEarned = 0
        } else if progress.topicBalanceNudgeTopic != nil {
            companion.cheer(Gendered.g(tr("אַלּוּף בָּזֶה! 🌟 בּוֹא נְגַלֶּה גַּם עוֹלָם אַחֵר — יֵשׁ בּוֹנוּס גִּוּוּן 🌈"),
                                       tr("אַלּוּפָה בָּזֶה! 🌟 בּוֹאִי נְגַלֶּה גַּם עוֹלָם אַחֵר — יֵשׁ בּוֹנוּס גִּוּוּן 🌈")))
            progress.topicBalanceNudgeTopic = nil
        }
        if receivedHelpThisQuestion {
            AppAnalytics.log("parent_help_success", ["topic": q.topic.rawValue])
        }
        // 💫 Bonus question pays its minutes on top of the regular cycle —
        // BEFORE the delta below, so the "+X דקות" popup shows the full prize.
        // grantBonusMinutes fills today up to the cap and banks any overflow.
        if isBonusQuestion, earnsTime {
            bonusPopupMinutes += progress.grantBonusMinutes(RewardEngine.bonusQuestionMinutes).addedToday
        }
        let minutesGranted = max(0, progress.pendingMinutes - minutesBefore)

        LearningHistoryStore.shared.recordAnswer(
            topic: q.topic, correct: true, responseMs: responseMs,
            earnedMinutes: minutesGranted,
            streak: progress.currentStreak,
            voluntary: cappedBefore,   // learning past the max = voluntary
            skill: q.skill
        )
        reportLiveEvents(for: q)

        // Immediate per-question reward: "+24 שניות" rising into the timer
        // (doubled in the bonus arena).
        // What ACTUALLY reached the wallet: less while a miss is being paid
        // back, nothing past the cap.
        if earnsTime, !cappedBefore, progress.lastPaidSeconds > 0 {
            flashSeconds(tr("+\(progress.lastPaidSeconds) שְׁנִיּוֹת"), positive: true)
        }
        // "+X דקות" popup — only for a real bonus (💫 question, 🌈 variety).
        if bonusPopupMinutes > 0 {
            showEarnedMinutesPopup(minutes: bonusPopupMinutes)
        }

        // Crossed the daily maximum just now? Celebrate once and make it clear
        // that play continues for fun/learning without more minutes.
        if earnsTime, !cappedBefore, progress.atDailyCap, !capMessageShown {
            capMessageShown = true
            companion.wow(Gendered.g(tr("הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! 🎉 מִכָּאן מַמְשִׁיכִים לִלְמוֹד בְּלִי דַּקּוֹת נוֹסָפוֹת"), tr("הִגַּעַתְּ לַמַּקְסִימוּם הַיּוֹמִי! 🎉 מִכָּאן מַמְשִׁיכִים לִלְמוֹד בְּלִי דַּקּוֹת נוֹסָפוֹת")))
            confettiTrigger += 1
            return
        }
        // Already past the max — gentle, occasional reminder (no minutes now).
        if cappedBefore {
            if isBonusQuestion {
                // The promised bonus minutes were banked — say so, never silence a prize.
                companion.wow(tr("אַלּוּפִים! 💫 הַדַּקּוֹת נִשְׁמְרוּ לְמָחָר 🏦"))
                confettiTrigger += 1
            } else {
                companion.cheer([tr("יָפֶה! לוֹמְדִים בִּשְׁבִיל הַכֵּיף 🌟"), tr("כָּל הַכָּבוֹד! עוֹד נְקוּדּוֹת וְכוֹכָבִים"), Gendered.g(tr("אַלּוּף! מַמְשִׁיכִים לְהִתְקַדֵּם"), tr("אַלּוּפָה! מַמְשִׁיכִים לְהִתְקַדֵּם"))].randomElement()!)
            }
            return
        }

        // Risk & Recovery payoff — celebrate winning time back.
        if progress.lastRecoveredMinutes > 0 {
            let back = progress.lastRecoveredMinutes
            progress.lastRecoveredMinutes = 0
            companion.wow(Gendered.g(tr("הֶחְזַרְתָּ \(back) דַּק'! ⭐"), tr("הֶחְזַרְתְּ \(back) דַּק'! ⭐")))
            confettiTrigger += 1
            return
        }

        // Personal-best streak — the headline celebration, takes priority.
        if progress.newStreakRecord {
            progress.newStreakRecord = false
            companion.wow(tr("שִׂיא חָדָשׁ! 🏆 \(progress.currentStreak) בָּרֶצֶף!"))
            confettiTrigger += 1
            rumbleTrigger += 1
            SoundPlayer.shared.play(.levelUp)
            return
        }

        // Companion reaction
        if isBonusQuestion {
            companion.wow(tr("עֲנָקִים! 💫 +\(RewardEngine.bonusQuestionMinutes) דַּקּוֹת!"))
            confettiTrigger += 1
            rumbleTrigger += 1
            SoundPlayer.shared.play(.levelUp)
        } else if isSuperQuestion {
            companion.wow(tr("שְׁאֵלַת זָהָב! ⭐"))
            confettiTrigger += 1
        } else if isInPortal {
            companion.wow(tr("שְׁאֵלַת בּוֹנוּס — פִּי 3 כּוֹכָבִים! 🌀"))
            confettiTrigger += 1
        } else if EventEngine.shouldFireComboEvent(streak: progress.currentStreak) {
            companion.hype(tr("🔥 \(progress.currentStreak) בָּרֶצֶף!"))
            confettiTrigger += 1
            rumbleTrigger += 1
        } else {
            companion.cheer([tr("יֵשׁ!"), tr("טוֹב!"), tr("כֵּן!"), tr("וָואוּ!"), Gendered.g(tr("אַלּוּף!"), tr("אַלּוּפָה!"))].randomElement()!)
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
        // No automatic help sheet any more: a wrong answer moves on after a
        // second, so a sheet opened here landed on the NEXT question. The 🙋
        // button pulses instead (see `askParentButton`).
        let lostSeconds = progress.recordWrong(
            topic: q.topic,
            minutesPerCorrect: settings.minutesPerCorrectAnswer,
            hintUsed: usedHintThisQuestion,
            grantsScreenTime: purpose.grantsScreenTime,
            // Neither the arena NOR a 💫 bonus question (deliberately extra-hard)
            // may lower the adaptive level — a hard-by-design miss isn't a signal
            // the kid is over-leveled.
            affectsAdaptive: !isBonusArena && !isBonusQuestion
        )
        LearningHistoryStore.shared.recordAnswer(
            topic: q.topic, correct: false, responseMs: 0,
            earnedMinutes: 0, streak: 0, skill: q.skill
        )
        // No "−12 שניות" (Rani, 2026-10-06): the balance never drops on a miss —
        // the next right answer just pays a little less — so only the
        // encouraging line. Safe negative experience: never accusatory.
        _ = lostSeconds
        companion.console([
            tr("כִּמְעַט!"),
            tr("מַמָּשׁ קָרוֹב"),
            Gendered.g(tr("בּוֹא נְנַסֶּה שׁוּב"), tr("בּוֹאִי נְנַסֶּה שׁוּב")),
            tr("נְנַסֶּה אֶת הַבָּאָה"),
            tr("⭐ עוֹד תְּשׁוּבָה נְכוֹנָה וְחוֹזְרִים לְהִתְקַדֵּם")
        ].randomElement()!)
    }
}

#Preview {
    QuestionRunnerView(mode: .smartFeed)
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .app)
}
