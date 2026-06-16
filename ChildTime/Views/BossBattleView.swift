import SwiftUI

/// "קְרַב בּוֹס" — the finale of a world. The world's emoji becomes a friendly
/// boss with a hearts bar; each correct (harder) answer lands a hit. The kid has
/// 3 hearts — a wrong answer costs one, but losing isn't failure: it's "almost,
/// let's try again" (keeping the safe, recoverable feel). Winning is a big,
/// celebrated reward moment.
struct BossBattleView: View {
    let world: World
    var onClose: () -> Void

    @ObservedObject private var progress = ProgressStore.shared

    private let bossMaxHP = 5
    private let startHearts = 3

    private enum Phase { case fighting, won, lost }

    @State private var phase: Phase = .fighting
    @State private var bossHP = 5
    @State private var hearts = 3
    @State private var question: Question?
    @State private var picked: Int? = nil
    @State private var locked = false
    @State private var bossHit = false
    @State private var shake = false

    var body: some View {
        ZStack {
            world.gradient.gradient.ignoresSafeArea()
            SparkleField(count: 20, size: 13)

            switch phase {
            case .fighting: fighting
            case .won:      result(win: true)
            case .lost:     result(win: false)
            }

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.18)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(20)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { if question == nil { newQuestion() } }
    }

    // MARK: - Fighting

    private var fighting: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 40)

            // Boss + HP
            VStack(spacing: 10) {
                Text(world.emoji)
                    .font(.system(size: 92))
                    .scaleEffect(bossHit ? 1.18 : 1)
                    .rotationEffect(.degrees(bossHit ? -8 : 0))
                    .shadow(color: world.glowColor.opacity(0.8), radius: 24)
                Text("הַבּוֹס שֶׁל \(world.name)")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                heartsRow(count: bossMaxHP, filled: bossHP, color: Color(hex: "EF476F"), symbol: "bolt.heart.fill")
            }

            Spacer()

            if let q = question {
                Text(q.prompt)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .modifier(Shake(animatableData: shake ? 1 : 0))

                VStack(spacing: 10) {
                    ForEach(Array(q.options.enumerated()), id: \.offset) { idx, opt in
                        answerButton(idx: idx, text: opt, correct: idx == q.correctIndex)
                    }
                }
                .padding(.horizontal, 18)
            }

            Spacer()

            // Player hearts
            HStack(spacing: 8) {
                Text("הַלְּבָבוֹת שֶׁלְּךָ:").font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                heartsRow(count: startHearts, filled: hearts, color: Color(hex: "FF5E78"), symbol: "heart.fill")
            }
            .padding(.bottom, 24)
        }
    }

    private func heartsRow(count: Int, filled: Int, color: Color, symbol: String) -> some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(i < filled ? color : Color.white.opacity(0.22))
            }
        }
    }

    private func answerButton(idx: Int, text: String, correct: Bool) -> some View {
        let show = picked != nil
        let isPicked = picked == idx
        let bg: Color = show && correct ? AppColor.successMint
            : (show && isPicked && !correct ? Color(hex: "EF476F") : Color.white.opacity(0.14))
        return Button { pick(idx) } label: {
            Text(text)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(bg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.juicy)
        .disabled(locked)
    }

    // MARK: - Result

    private func result(win: Bool) -> some View {
        VStack(spacing: 18) {
            CharacterView(character: Character3DCatalog.find("lion"))
                .frame(width: 130, height: 130)
            Text(win ? "נִצַּחְתָּ אֶת הַבּוֹס! 🏆" : "כִּמְעַט! בּוֹא נְנַסֶּה שׁוּב 💪")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).multilineTextAlignment(.center)
            if win {
                Text("פְּרָס עָנָק: +20 ⭐ וְ-30 💎")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            VStack(spacing: 12) {
                if !win {
                    Button { restart() } label: { ctaLabel("עוֹד נִסָּיוֹן 🔁", dark: true) }
                        .buttonStyle(.juicy)
                }
                Button(action: onClose) { ctaLabel(win ? "יֵשׁ! 🎉" : "חֲזָרָה", dark: win) }
                    .buttonStyle(.juicy)
            }
            .padding(.horizontal, 44).padding(.top, 6)
        }
        .padding(28)
    }

    private func ctaLabel(_ t: String, dark: Bool) -> some View {
        Text(t)
            .font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(dark ? AppColor.textOnLight : .white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(dark ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.16)), in: Capsule())
    }

    // MARK: - Logic

    private func newQuestion() {
        question = QuestionGenerator.generate(topic: world.topic, difficulty: .hard)
        picked = nil
        locked = false
    }

    private func pick(_ idx: Int) {
        guard !locked, let q = question else { return }
        locked = true
        picked = idx
        let correct = idx == q.correctIndex
        if correct {
            SoundPlayer.shared.play(.correctBig)
            Haptic.success()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { bossHit = true }
            bossHP = max(0, bossHP - 1)
        } else {
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            withAnimation(.default) { shake = true }
            hearts = max(0, hearts - 1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            bossHit = false; shake = false
            if bossHP == 0 { win() }
            else if hearts == 0 { phase = .lost }
            else { newQuestion() }
        }
    }

    private func win() {
        phase = .won
        progress.applyChestReward(ChestReward(stars: 20, diamonds: 30, minutes: 2))
        SoundPlayer.shared.play(.worldUnlock)
        Haptic.success()
        AppAnalytics.log("boss_battle_won", ["world": world.id])
    }

    private func restart() {
        bossHP = bossMaxHP; hearts = startHearts; phase = .fighting
        newQuestion()
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
