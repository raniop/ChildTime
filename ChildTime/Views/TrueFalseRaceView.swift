import SwiftUI
import Combine

/// "מֵרוֹץ נָכוֹן/לֹא-נָכוֹן" — a fast, exciting game mode that reuses the WHOLE
/// question bank without any new content: each round shows a question plus a
/// CANDIDATE answer (50% the real answer, 50% a distractor) and the kid taps
/// ✓ / ✗. A gentle per-question timer rewards speed but never punishes harshly
/// (running out just moves on — keeping with the "safe, recoverable" feel).
///
/// Decoupled from the adaptive engine: timed taps don't pollute per-topic
/// stats. The reward is granted once at the end (⭐ for the leaderboard + 💎).
struct TrueFalseRaceView: View {
    var onClose: () -> Void

    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var profiles = ProfileStore.shared

    private let total = 10
    private let limit: TimeInterval = 7          // seconds per question
    private let fastBonusUnder: TimeInterval = 3 // answer this fast → +1 bonus

    private struct TFItem {
        let question: Question
        let candidate: String
        let isTrue: Bool
    }

    private enum Phase { case playing, done }

    @State private var phase: Phase = .playing
    @State private var item: TFItem?
    @State private var index = 0
    @State private var correctCount = 0
    @State private var score = 0
    @State private var answered = false
    @State private var lastResult: Bool? = nil   // nil = awaiting, true/false = flash
    @State private var questionStart = Date()
    @State private var now = Date()

    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var elapsed: TimeInterval { now.timeIntervalSince(questionStart) }
    private var remaining: TimeInterval { max(0, limit - elapsed) }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 18, size: 12)

            switch phase {
            case .playing: playing
            case .done:    summary
            }

            // Close (X) — top-leading so it clears the RTL content.
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.white.opacity(0.18)))
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
        VStack(spacing: 22) {
            // Header: progress + score + countdown bar.
            VStack(spacing: 10) {
                HStack {
                    Text("שְׁאֵלָה \(min(index + 1, total))/\(total)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Spacer()
                    Text("⚡️ \(score)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.15))
                        Capsule()
                            .fill(remaining > limit * 0.3 ? AnyShapeStyle(AppGradient.gold)
                                                          : AnyShapeStyle(Color.red.opacity(0.9)))
                            .frame(width: geo.size.width * CGFloat(remaining / limit))
                    }
                }
                .frame(height: 9)
                .animation(.linear(duration: 0.05), value: remaining)
            }
            .padding(.horizontal, 22)
            .padding(.top, 64)

            Spacer()

            if let item {
                VStack(spacing: 18) {
                    Text(item.question.prompt)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)

                    Text("הַתְּשׁוּבָה: \(item.candidate)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .padding(.horizontal, 26).padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white))
                        .overlay(feedbackTint)
                }
                .padding(.horizontal, 18)
            }

            Spacer()

            // Two big verdict buttons.
            HStack(spacing: 14) {
                verdictButton(text: "לֹא נָכוֹן", icon: "xmark", color: Color(hex: "EF476F"), said: false)
                verdictButton(text: "נָכוֹן", icon: "checkmark", color: AppColor.successMint, said: true)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
    }

    private func verdictButton(text: String, icon: String, color: Color, said: Bool) -> some View {
        Button {
            answer(said)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 30, weight: .heavy))
                Text(text).font(.system(size: 20, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(LinearGradient(colors: [color, color.opacity(0.82)], startPoint: .top, endPoint: .bottom),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: color.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.juicy)
        .disabled(answered)
    }

    @ViewBuilder private var feedbackTint: some View {
        if let lastResult {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(lastResult ? AppColor.successMint : Color(hex: "EF476F"), lineWidth: 5)
        }
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 20) {
            CharacterView(character: Character3DCatalog.find("lion"))
                .frame(width: 130, height: 130)
            Text(correctCount >= total - 2 ? "מְצֻיָּן! 🏆" : "כָּל הַכָּבוֹד! 🎉")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("עָנִיתָ נָכוֹן עַל \(correctCount) מִתּוֹךְ \(total)")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 18) {
                rewardPill("⭐", correctCount)
                rewardPill("💎", score)
            }
            .padding(.top, 4)

            VStack(spacing: 12) {
                Button { restart() } label: {
                    Text("עוֹד סִבּוּב 🔁")
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(AppGradient.gold, in: Capsule())
                }
                .buttonStyle(.juicy)
                Button(action: onClose) {
                    Text("סִיּוּם")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Capsule().fill(.white.opacity(0.16)))
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
        .padding(28)
    }

    private func rewardPill(_ emoji: String, _ value: Int) -> some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 22))
            Text("+\(value)").font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 10)
        .background(Capsule().fill(.white.opacity(0.14)))
    }

    // MARK: - Game logic

    private func loadNext() {
        item = makeItem()
        answered = false
        lastResult = nil
        questionStart = Date()
        now = Date()
    }

    private func makeItem() -> TFItem {
        let topics = Array(profiles.active?.enabledTopics ?? Set(Topic.allCases))
        let topic = topics.randomElement() ?? .math
        let base = profiles.active?.difficulty(for: topic) ?? .easy
        let level = progress.adaptiveLevel(for: topic, base: base)
        let diff = AdaptiveDifficultyEngine.sampledDifficulty(forLevel: level, base: base)
        let q = QuestionGenerator.generate(topic: topic, difficulty: diff)
        if Bool.random() {
            return TFItem(question: q, candidate: q.correctAnswer, isTrue: true)
        }
        let wrongIdx = q.options.indices.filter { $0 != q.correctIndex }.randomElement()
        let wrong = wrongIdx.map { q.options[$0] } ?? q.correctAnswer
        return TFItem(question: q, candidate: wrong, isTrue: wrong == q.correctAnswer)
    }

    private func answer(_ saidTrue: Bool) {
        guard !answered, let item else { return }
        answered = true
        let correct = (saidTrue == item.isTrue)
        lastResult = correct
        if correct {
            correctCount += 1
            let bonus = elapsed < fastBonusUnder ? 1 : 0
            score += 1 + bonus
            SoundPlayer.shared.play(bonus > 0 ? .correctBig : .correctSmall)
            Haptic.success()
        } else {
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { advance() }
    }

    private func handleTimeout() {
        guard !answered else { return }
        answered = true
        lastResult = false
        SoundPlayer.shared.play(.wrongSoft)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { advance() }
    }

    private func advance() {
        index += 1
        if index >= total { finish() } else { loadNext() }
    }

    private func finish() {
        phase = .done
        // One reward at the end: ⭐ climb the leaderboard, 💎 fill the wallet.
        progress.applyChestReward(ChestReward(stars: correctCount, diamonds: score, minutes: 0))
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        AppAnalytics.log("truefalse_race_done", ["correct": "\(correctCount)", "score": "\(score)"])
    }

    private func restart() {
        index = 0; correctCount = 0; score = 0; phase = .playing
        loadNext()
    }
}
