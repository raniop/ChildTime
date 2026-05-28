import SwiftUI

struct QuestionRunnerView: View {
    let world: World

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var progress: ProgressStore

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
                        CompanionView(controller: companion, size: 90)
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

    private var background: some View {
        ZStack {
            (isInPortal ? AppGradient.portal : world.gradient.gradient)
                .ignoresSafeArea()
            SparkleField(count: 10, size: 12)
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
                    .font(.system(size: 36))
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
                .font(.system(size: 58, weight: .heavy, design: .rounded))
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
                    .font(.system(size: 180))
                    .rotationEffect(.degrees(showPortalIntro ? 360 : 0))
                    .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: showPortalIntro)
                    .glow(AppColor.gemPurple, radius: 30)
                Text("פורטל מסתורין!")
                    .font(AppFont.title())
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
