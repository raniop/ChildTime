import SwiftUI

struct QuestionRunnerView: View {
    let world: World

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hsc
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore

    private var isCompact: Bool { hsc == .compact }
    private var questionSize: CGFloat { isCompact ? 42 : 58 }
    private var topicEmojiSize: CGFloat { isCompact ? 30 : 36 }
    private var companionSize: CGFloat { isCompact ? 78 : 90 }
    private var portalEmojiSize: CGFloat { isCompact ? 130 : 180 }
    private var portalTitleSize: CGFloat { isCompact ? 36 : 56 }

    @State private var companion = CompanionController()
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

    private var totalQuestions: Int { settings.questionsPerSession }

    var body: some View {
        ZStack {
            background

            VStack(spacing: AppSpacing.lg) {
                topBar
                Spacer(minLength: 0)
                if let q = current {
                    questionContent(q)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.md)

            // Companion in corner
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    ZStack(alignment: .top) {
                        if let bubble = companion.bubbleText {
                            BubbleSpeech(text: bubble)
                                .offset(x: 70, y: -10)
                                .transition(.scale.combined(with: .opacity))
                        }
                        CompanionView(controller: companion, size: companionSize)
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

            // Earned-minutes popup (center-screen, brief)
            VStack {
                Spacer()
                EarnedMinutesPopup(minutes: lastEarnedMinutes, visible: showEarnedPopup)
                Spacer().frame(maxHeight: .infinity)
            }
            .allowsHitTesting(false)

            // Portal overlay
            if showPortalIntro {
                portalIntro
            }
        }
        .rumble(trigger: rumbleTrigger)
        .onAppear { startSession() }
        .fullScreenCover(isPresented: $goToReward) {
            RewardScreenView(
                kind: RewardEngine.endOfSessionChestKind(correctInSession: correctInSession, total: totalQuestions),
                correctInSession: correctInSession,
                world: world,
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
            (isInPortal ? AppGradient.portal : world.gradient.gradient)
                .ignoresSafeArea()
            if !isInPortal {
                themedOrbs
                WorldDecorations(world: world).opacity(0.18)
            }
            SparkleField(count: 12, size: 12)
        }
    }

    @ViewBuilder
    private var themedOrbs: some View {
        switch world.id {
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
        HStack(spacing: AppSpacing.md) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 6) {
                ForEach(0..<totalQuestions, id: \.self) { i in
                    Circle()
                        .fill(i < questionIndex ? AppColor.successMint : .white.opacity(0.3))
                        .frame(width: 14, height: 14)
                        .scaleEffect(i == questionIndex - 1 ? 1.3 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: questionIndex)
                }
            }

            Spacer()

            StreakMeter(streak: progress.currentStreak)
            MinutesBadge(minutes: progress.pendingMinutes, compact: true)
            StarCounter(value: progress.stars)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
    }

    // MARK: - Question content

    @ViewBuilder
    private func questionContent(_ q: Question) -> some View {
        VStack(spacing: AppSpacing.xl) {
            // Topic / super indicator
            HStack(spacing: 8) {
                Text(q.topic.emoji)
                    .font(.system(size: topicEmojiSize))
                if isSuperQuestion {
                    Text("⭐ שאלת זהב!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                        .glow(AppColor.starGold, radius: 8)
                } else if isInPortal {
                    Text("🌀 מסתורין!")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .glow(AppColor.gemPurple, radius: 10)
                }
            }

            Text(q.prompt)
                .font(.system(size: questionSize, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
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
                .glow(isSuperQuestion ? AppColor.starGold : .clear, radius: isSuperQuestion ? 16 : 0)
                .padding(.horizontal, AppSpacing.lg)

            optionsGrid(for: q)

            if consecutiveWrong >= 2 && !showFeedback {
                magicWandButton
            }
        }
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
            companion.cheer("בוא ננסה אחרת")
            withAnimation(.spring()) {
                regenerateQuestion()
            }
        } label: {
            HStack {
                Text("🪄")
                Text("החלף שאלה")
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
            Color.black.opacity(0.7).ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                Text("🌀")
                    .font(.system(size: portalEmojiSize))
                    .rotationEffect(.degrees(showPortalIntro ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: showPortalIntro)
                    .glow(AppColor.gemPurple, radius: 30)
                Text("פורטל מסתורין!")
                    .font(.system(size: portalTitleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .glow(AppColor.gemPurple, radius: 14)
                Text("×3 כוכבים")
                    .font(AppFont.subtitle())
                    .foregroundStyle(AppColor.starGold)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Session

    private func startSession() {
        startedLevel = progress.companionLevel
        progress.registerSessionToday()
        questionIndex = 0
        correctInSession = 0
        earnedThisSession = 0
        consecutiveWrong = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            companion.cheer("מוכן? קדימה!")
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
            companion.wow("וואו! פורטל!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showPortalIntro = false }
                createQuestion(super: false)
            }
        } else {
            isInPortal = false
            createQuestion(super: superQ)
        }
    }

    private func createQuestion(super isSuper: Bool) {
        isSuperQuestion = isSuper
        selectedIndex = nil
        feedbackForIndex = [:]
        showFeedback = false

        // DDA: pick difficulty
        let baseDiff = settings.difficulty(for: world.topic)
        let acc = progress.accuracy(for: world.topic)
        let effective = QuestionGenerator.adaptiveDifficulty(base: baseDiff, accuracy: acc)
        current = QuestionGenerator.generate(topic: world.topic, difficulty: effective)
    }

    private func regenerateQuestion() {
        createQuestion(super: isSuperQuestion)
        consecutiveWrong = 0
    }

    // MARK: - Picking

    private func pickOption(_ idx: Int, q: Question) {
        guard !showFeedback else { return }
        selectedIndex = idx
        let correct = (idx == q.correctIndex)
        lastWasCorrect = correct

        // Set feedback per option
        var map: [Int: OptionFeedback] = [:]
        for i in 0..<q.options.count {
            if i == idx {
                map[i] = correct ? .correct : .wrong
            } else if i == q.correctIndex && !correct {
                map[i] = .revealed
            } else {
                map[i] = .dimmed
            }
        }
        feedbackForIndex = map
        showFeedback = true

        if correct {
            handleCorrect(q: q)
        } else {
            handleWrong(q: q)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            questionIndex += 1
            nextQuestion()
        }
    }

    private func handleCorrect(q: Question) {
        SoundPlayer.shared.play(isSuperQuestion ? .correctBig : .correctSmall)
        Haptic.success()
        burstTrigger += 1
        correctInSession += 1
        consecutiveWrong = 0

        let ctx = ProgressStore.AnswerContext(
            topic: q.topic,
            combo: progress.currentStreak,
            isSuperQuestion: isSuperQuestion,
            isMysteryPortal: isInPortal
        )
        let earned = progress.recordCorrect(ctx, minutesPerCorrect: settings.minutesPerCorrectAnswer)
        earnedThisSession += earned

        // Show "+X דקות" popup
        let minuteMultiplier = isInPortal ? 3 : (isSuperQuestion ? 5 : 1)
        let minutesGained = settings.minutesPerCorrectAnswer * minuteMultiplier
        showEarnedMinutesPopup(minutes: minutesGained)

        // Companion reaction
        if isSuperQuestion {
            companion.wow("שאלת זהב! ⭐")
            confettiTrigger += 1
        } else if isInPortal {
            companion.wow("פתחת מסתורין! 🌀")
            confettiTrigger += 1
        } else if EventEngine.shouldFireComboEvent(streak: progress.currentStreak) {
            companion.hype("🔥 \(progress.currentStreak) ברצף!")
            confettiTrigger += 1
            rumbleTrigger += 1
        } else {
            companion.cheer(["יש!", "טוב!", "כן!", "וואו!", "אלוף!"].randomElement()!)
        }
    }

    private func showEarnedMinutesPopup(minutes: Int) {
        lastEarnedMinutes = minutes
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
            showEarnedPopup = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.4)) {
                showEarnedPopup = false
            }
        }
    }

    private func handleWrong(q: Question) {
        SoundPlayer.shared.play(.wrongSoft)
        Haptic.warning()
        consecutiveWrong += 1
        progress.recordWrong(topic: q.topic)
        companion.console([
            "כמעט!",
            "ממש קרוב",
            "טעות מתוקה — הנה הנכון!",
            "ננסה את הבאה"
        ].randomElement()!)
    }
}

#Preview {
    QuestionRunnerView(world: Worlds.all[0])
        .environmentObject(ParentSettings.shared)
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
