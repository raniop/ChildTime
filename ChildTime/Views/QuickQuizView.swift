import SwiftUI
import Combine

/// "חִידוֹן בָּזָק" — a rapid 4-answer quiz race. Same juicy feel as the True/False
/// race but with full multiple-choice questions straight from the bank (adaptive
/// difficulty). Builds a 🔥 combo, rewards speed, and grants ⭐ / 💎 / 🎮 minutes.
struct QuickQuizView: View {
    var onClose: () -> Void

    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var profiles = ProfileStore.shared

    private let total = 10
    private let limit: TimeInterval = 9
    private let fastBonusUnder: TimeInterval = 4

    private enum Phase { case playing, done }

    @State private var phase: Phase = .playing
    @State private var question: Question?
    @State private var index = 0
    @State private var correctCount = 0
    @State private var score = 0
    @State private var combo = 0
    @State private var picked: Int? = nil
    @State private var locked = false
    @State private var questionStart = Date()
    @State private var now = Date()

    // Juice
    @State private var burst = 0
    @State private var confetti = 0
    @State private var shake = false
    @State private var earnedMinutes = 0
    @State private var revealStep = 0

    private let ticker = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private var elapsed: TimeInterval { now.timeIntervalSince(questionStart) }
    private var remaining: TimeInterval { max(0, limit - elapsed) }
    private var timeFrac: Double { remaining / limit }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "118AB2"), Color(hex: "5B6CFF"), Color(hex: "9B5DE5")],
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
        .onAppear { if question == nil { loadNext() } }
        .onReceive(ticker) { t in
            guard phase == .playing else { return }
            now = t
            if remaining <= 0, !locked { handleTimeout() }
        }
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: 18) {
            header
            Spacer()
            if let q = question {
                Text(q.prompt)
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .padding(.horizontal, 18)
                    .modifier(QQShake(animatableData: shake ? 1 : 0))

                let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                        answerButton(idx: idx, text: opt, correct: idx == q.correctIndex)
                    }
                }
                .padding(.horizontal, 18)
            }
            Spacer()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Label("\(min(index + 1, total))/\(total)", systemImage: "list.number")
                    .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Spacer()
                if combo >= 2 {
                    Text("🔥 קוֹמְבּוֹ ×\(combo)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(AppColor.flameOrange))
                }
                Spacer()
                Text("⚡️ \(score)").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(timeFrac > 0.3 ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.red))
                        .frame(width: geo.size.width * timeFrac)
                        .glow(timeFrac > 0.3 ? AppColor.starGold : .red, radius: 6)
                }
            }
            .frame(height: 10).animation(.linear(duration: 0.05), value: timeFrac)
        }
        .padding(.horizontal, 22).padding(.top, 64)
    }

    private func answerButton(idx: Int, text: String, correct: Bool) -> some View {
        let show = picked != nil
        let isPicked = picked == idx
        let bg: AnyShapeStyle = show && correct ? AnyShapeStyle(AppColor.successMint)
            : (show && isPicked && !correct ? AnyShapeStyle(Color(hex: "EF476F")) : AnyShapeStyle(Color.white.opacity(0.16)))
        return Button { pick(idx) } label: {
            Text(text)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3).minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: 64)
                .padding(.horizontal, 8).padding(.vertical, 10)
                .background(bg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.3), lineWidth: 1.5))
        }
        .buttonStyle(.juicy)
        .disabled(locked)
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 18) {
            CharacterView(character: Character3DCatalog.find("lion"))
                .frame(width: 140, height: 140).float(amplitude: 10)
            Text(correctCount >= total - 2 ? "וָואו, מְצֻיָּן! 🏆" : "כָּל הַכָּבוֹד! 🎉")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text("עָנִיתָ נָכוֹן עַל \(correctCount) מִתּוֹךְ \(total)")
                .font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 14) {
                pill("⭐", correctCount, AppColor.starGold, step: 1)
                pill("💎", score, AppColor.gemPurple, step: 2)
                pill("🎮", earnedMinutes, AppColor.successMint, step: 3, suffix: " דק'")
            }
            VStack(spacing: 12) {
                Button { restart() } label: { cta("עוֹד סִבּוּב 🔁", dark: true) }.buttonStyle(.juicy)
                Button(action: onClose) { cta("סִיּוּם", dark: false) }.buttonStyle(.juicy)
            }
            .padding(.horizontal, 40).padding(.top, 8)
        }
        .padding(28)
    }

    private func pill(_ emoji: String, _ value: Int, _ color: Color, step: Int, suffix: String = "") -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 26))
            Text("+\(value)\(suffix)").font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
        .frame(minWidth: 76).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(color.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color, lineWidth: 1.5))
        .glow(color, radius: revealStep >= step ? 10 : 0)
        .scaleEffect(revealStep >= step ? 1 : 0.3).opacity(revealStep >= step ? 1 : 0)
    }

    private func cta(_ t: String, dark: Bool) -> some View {
        Text(t).font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(dark ? AppColor.textOnLight : .white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(dark ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.18)), in: Capsule())
    }

    // MARK: - Logic

    private func loadNext() {
        // Reading passages don't fit the quick one-liner format — skip them here.
        let topics = Array(profiles.active?.enabledTopics ?? Set(Topic.allCases)).filter { $0 != .reading }
        let topic = topics.randomElement() ?? .math
        let base = profiles.active?.difficulty(for: topic) ?? .easy
        let level = progress.adaptiveLevel(for: topic, base: base)
        let diff = AdaptiveDifficultyEngine.sampledDifficulty(forLevel: level, base: base)
        question = QuestionGenerator.generate(topic: topic, difficulty: diff,
                                              grade: profiles.active?.effectiveGrade)
        picked = nil; locked = false; questionStart = Date(); now = Date()
    }

    private func pick(_ idx: Int) {
        guard !locked, let q = question else { return }
        locked = true; picked = idx
        let correct = idx == q.correctIndex
        if correct {
            correctCount += 1; combo += 1
            let bonus = (elapsed < fastBonusUnder ? 1 : 0) + (combo >= 3 ? 1 : 0)
            score += 1 + bonus
            burst += 1
            SoundPlayer.shared.play(bonus > 0 ? .correctBig : .correctSmall)
            Haptic.success()
        } else {
            combo = 0
            SoundPlayer.shared.play(.wrongSoft); Haptic.light()
            withAnimation(.default) { shake = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { shake = false; advance() }
    }

    private func handleTimeout() {
        guard !locked else { return }
        locked = true; combo = 0
        SoundPlayer.shared.play(.wrongSoft)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { advance() }
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
        SoundPlayer.shared.play(.chestOpen); Haptic.success(); confetti += 1
        AppAnalytics.log("quick_quiz_done", ["correct": "\(correctCount)", "score": "\(score)"])
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

private struct QQShake: GeometryEffect {
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: sin(animatableData * .pi * 4) * 9, y: 0))
    }
}
