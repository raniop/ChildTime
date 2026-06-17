import SwiftUI
import Combine

/// "מֵרוֹץ נָכוֹן/לֹא-נָכוֹן" — a fast, juicy game mode that reuses the WHOLE
/// question bank without any new content: each round shows a question plus a
/// CANDIDATE answer (50% the real answer, 50% a distractor) and the kid taps
/// ✓ / ✗. A gentle per-question timer rewards speed but never punishes harshly.
///
/// Rewards (granted once at the end): ⭐ leaderboard, 💎 wallet, AND 🎮 play
/// minutes (through the daily-cap-aware bonus path) so it actually earns time.
struct TrueFalseRaceView: View {
    var onClose: () -> Void

    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var profiles = ProfileStore.shared

    private let total = 10
    private let limit: TimeInterval = 7
    private let fastBonusUnder: TimeInterval = 3

    private struct TFItem { let question: Question; let candidate: String; let isTrue: Bool }
    private enum Phase { case playing, done }

    @State private var phase: Phase = .playing
    @State private var item: TFItem?
    @State private var index = 0
    @State private var correctCount = 0
    @State private var score = 0
    @State private var combo = 0
    @State private var answered = false
    @State private var lastResult: Bool? = nil
    @State private var questionStart = Date()
    @State private var now = Date()

    // Juice
    @State private var burst = 0
    @State private var confetti = 0
    @State private var cardPop = false
    @State private var shake = false
    @State private var earnedMinutes = 0
    @State private var revealStep = 0          // staggered reward reveal on the win screen

    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private var elapsed: TimeInterval { now.timeIntervalSince(questionStart) }
    private var remaining: TimeInterval { max(0, limit - elapsed) }
    private var timeFrac: Double { remaining / limit }

    var body: some View {
        ZStack {
            // Lively animated backdrop.
            LinearGradient(colors: [Color(hex: "5B6CFF"), Color(hex: "9B5DE5"), Color(hex: "EF476F")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            FloatingOrbs.home().opacity(0.5)
            SparkleField(count: 22, size: 12)

            switch phase {
            case .playing: playing
            case .done:    summary
            }

            StarBurst(count: 12, color: AppColor.starGold, trigger: burst)
            Confetti(trigger: confetti)

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.2)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(20)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { if item == nil { loadNext() } }
        .onReceive(ticker) { t in
            guard phase == .playing else { return }
            now = t
            if remaining <= 0, !answered { handleTimeout() }
        }
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: 20) {
            header
            Spacer()
            if let item {
                VStack(spacing: 16) {
                    Text(item.question.prompt)
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        .padding(.horizontal, 16)
                        .modifier(Shake(animatableData: shake ? 1 : 0))

                    VStack(spacing: 4) {
                        Text("הַתְּשׁוּבָה הִיא…")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(item.candidate)
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.textOnLight)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28).padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                            )
                            .overlay(feedbackRing)
                            .scaleEffect(cardPop ? 1.06 : 1)
                    }
                    .float(amplitude: 5)
                }
                .padding(.horizontal, 18)
            }
            Spacer()
            HStack(spacing: 14) {
                verdictButton(text: "לֹא נָכוֹן", icon: "xmark", color: Color(hex: "EF476F"), said: false)
                verdictButton(text: "נָכוֹן", icon: "checkmark", color: AppColor.successMint, said: true)
            }
            .padding(.horizontal, 18).padding(.bottom, 28)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Label("\(min(index + 1, total))/\(total)", systemImage: "list.number")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                if combo >= 2 {
                    Text("🔥 קוֹמְבּוֹ ×\(combo)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(AppColor.flameOrange))
                        .scaleEffect(cardPop ? 1.15 : 1)
                }
                Spacer()
                Text("⚡️ \(score)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule()
                        .fill(timeFrac > 0.3 ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.red))
                        .frame(width: geo.size.width * timeFrac)
                        .glow(timeFrac > 0.3 ? AppColor.starGold : .red, radius: 6)
                }
            }
            .frame(height: 10)
            .animation(.linear(duration: 0.05), value: timeFrac)
        }
        .padding(.horizontal, 22).padding(.top, 64)
    }

    private func verdictButton(text: String, icon: String, color: Color, said: Bool) -> some View {
        Button { answer(said) } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 34, weight: .heavy))
                Text(text).font(.system(size: 21, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 24)
            .background(LinearGradient(colors: [color, color.opacity(0.78)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.5), lineWidth: 1.5))
            .glow(color, radius: 10)
        }
        .buttonStyle(.juicy)
        .disabled(answered)
    }

    @ViewBuilder private var feedbackRing: some View {
        if let lastResult {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(lastResult ? AppColor.successMint : Color(hex: "EF476F"), lineWidth: 6)
                .glow(lastResult ? AppColor.successMint : Color(hex: "EF476F"), radius: 8)
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 18) {
            CharacterView(character: Character3DCatalog.find("lion"))
                .frame(width: 140, height: 140)
                .float(amplitude: 10)
            Text(correctCount >= total - 2 ? "וָואו, מְצֻיָּן! 🏆" : "כָּל הַכָּבוֹד! 🎉")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text("עָנִיתָ נָכוֹן עַל \(correctCount) מִתּוֹךְ \(total)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 14) {
                rewardPill("⭐", correctCount, AppColor.starGold, step: 1)
                rewardPill("💎", score, AppColor.gemPurple, step: 2)
                rewardPill("🎮", earnedMinutes, AppColor.successMint, step: 3, suffix: " דק'")
            }
            .padding(.top, 4)

            VStack(spacing: 12) {
                Button { restart() } label: { cta("עוֹד סִבּוּב 🔁", dark: true) }.buttonStyle(.juicy)
                Button(action: onClose) { cta("סִיּוּם", dark: false) }.buttonStyle(.juicy)
            }
            .padding(.horizontal, 40).padding(.top, 8)
        }
        .padding(28)
    }

    private func rewardPill(_ emoji: String, _ value: Int, _ color: Color, step: Int, suffix: String = "") -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 26))
            Text("+\(value)\(suffix)").font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(minWidth: 76)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color, lineWidth: 1.5))
        .glow(color, radius: revealStep >= step ? 10 : 0)
        .scaleEffect(revealStep >= step ? 1 : 0.3)
        .opacity(revealStep >= step ? 1 : 0)
    }

    private func cta(_ t: String, dark: Bool) -> some View {
        Text(t).font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(dark ? AppColor.textOnLight : .white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(dark ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.18)), in: Capsule())
    }

    // MARK: - Logic

    private func loadNext() {
        item = makeItem(); answered = false; lastResult = nil
        questionStart = Date(); now = Date()
    }

    private func makeItem() -> TFItem {
        let topics = Array(profiles.active?.enabledTopics ?? Set(Topic.allCases))
        // Skip set-dependent questions: a "מי לא שיך?" / odd-one-out prompt only
        // makes sense when the whole group is visible, but the True/False race
        // shows a single candidate — so the prompt alone is unanswerable. Retry
        // until we get a self-contained question (bounded so we never spin).
        var q = generateOne(topics)
        var tries = 0
        while !q.isSelfContainedPrompt && tries < 12 { q = generateOne(topics); tries += 1 }
        if Bool.random() { return TFItem(question: q, candidate: q.correctAnswer, isTrue: true) }
        let wrongIdx = q.options.indices.filter { $0 != q.correctIndex }.randomElement()
        let wrong = wrongIdx.map { q.options[$0] } ?? q.correctAnswer
        return TFItem(question: q, candidate: wrong, isTrue: wrong == q.correctAnswer)
    }

    private func generateOne(_ topics: [Topic]) -> Question {
        let topic = topics.randomElement() ?? .math
        let base = profiles.active?.difficulty(for: topic) ?? .easy
        let level = progress.adaptiveLevel(for: topic, base: base)
        let diff = AdaptiveDifficultyEngine.sampledDifficulty(forLevel: level, base: base)
        return QuestionGenerator.generate(topic: topic, difficulty: diff)
    }


    private func answer(_ saidTrue: Bool) {
        guard !answered, let item else { return }
        answered = true
        let correct = (saidTrue == item.isTrue)
        lastResult = correct
        if correct {
            correctCount += 1
            combo += 1
            let bonus = (elapsed < fastBonusUnder ? 1 : 0) + (combo >= 3 ? 1 : 0)
            score += 1 + bonus
            burst += 1
            SoundPlayer.shared.play(bonus > 0 ? .correctBig : .correctSmall)
            Haptic.success()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { cardPop = true }
        } else {
            combo = 0
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            withAnimation(.default) { shake = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            cardPop = false; shake = false
            advance()
        }
    }

    private func handleTimeout() {
        guard !answered else { return }
        answered = true; lastResult = false; combo = 0
        SoundPlayer.shared.play(.wrongSoft)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { advance() }
    }

    private func advance() {
        index += 1
        if index >= total { finish() } else { loadNext() }
    }

    private func finish() {
        phase = .done
        // Max 2 play-minutes per round (2 for a strong round, else 1).
        earnedMinutes = correctCount >= (total * 3) / 4 ? 2 : 1
        progress.applyChestReward(ChestReward(stars: correctCount, diamonds: score, minutes: earnedMinutes))
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        confetti += 1
        AppAnalytics.log("truefalse_race_done", ["correct": "\(correctCount)", "score": "\(score)"])
        // Stagger the reward pills popping in.
        for s in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(s)) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { revealStep = s }
                SoundPlayer.shared.play(.correctSmall)
            }
        }
    }

    private func restart() {
        index = 0; correctCount = 0; score = 0; combo = 0; revealStep = 0; phase = .playing
        loadNext()
    }
}

/// Small horizontal shake for a wrong answer.
private struct Shake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        let dx = sin(animatableData * .pi * 4) * 9
        return ProjectionTransform(CGAffineTransform(translationX: dx, y: 0))
    }
}
