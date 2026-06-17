import SwiftUI

/// "הַתְאָמַת זוּגוֹת" — a calm but juicy tap-to-match mini-game (no drag, so it's
/// robust everywhere). Two columns: questions on one side, answers on the other,
/// both shuffled. Tap one of each; a correct pair locks in green with a star
/// burst, a wrong pick bounces back gently. Match them all → confetti + reward
/// (⭐ + 💎 + 🎮 play minutes).
struct MatchPairsView: View {
    var onClose: () -> Void

    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var profiles = ProfileStore.shared

    private let pairCount = 5
    private struct Card: Identifiable { let id = UUID(); let pair: Int; let text: String }

    @State private var lefts: [Card] = []
    @State private var rights: [Card] = []
    @State private var matched: Set<Int> = []
    @State private var pickedLeft: UUID? = nil
    @State private var pickedRight: UUID? = nil
    @State private var wrongFlash = false
    @State private var won = false
    @State private var mistakes = 0

    // Juice
    @State private var burst = 0
    @State private var confetti = 0
    @State private var earnedMinutes = 0
    @State private var revealStep = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "06D6A0"), Color(hex: "5B6CFF"), Color(hex: "9B5DE5")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            FloatingOrbs.home().opacity(0.45)
            SparkleField(count: 18, size: 12)

            if won { summary } else { board }

            StarBurst(count: 12, color: AppColor.successMint, trigger: burst)
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
        .onAppear { if lefts.isEmpty { deal() } }
    }

    // MARK: - Board

    private var board: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("הַתְאִימוּ אֶת הַשְּׁאֵלָה לַתְּשׁוּבָה 🧩")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                Text("\(matched.count)/\(pairCount) זוּגוֹת")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, 60)

            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    column(cards: lefts, picked: pickedLeft, side: .left)
                    column(cards: rights, picked: pickedRight, side: .right)
                }
                .padding(.horizontal, 16).padding(.bottom, 20)
            }
        }
    }

    private enum Side { case left, right }

    private func column(cards: [Card], picked: UUID?, side: Side) -> some View {
        VStack(spacing: 10) {
            ForEach(cards) { card in
                let isMatched = matched.contains(card.pair)
                let isPicked = picked == card.id
                Button { tap(card, side: side) } label: {
                    Text(card.text)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(4).minimumScaleFactor(0.65)
                        .foregroundStyle(isMatched ? .white : AppColor.textOnLight)
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .padding(.horizontal, 8).padding(.vertical, 8)
                        .background(cardBackground(isMatched: isMatched, isPicked: isPicked))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isPicked ? AppColor.starGold : .white.opacity(0.35),
                                    lineWidth: isPicked ? 3 : 1))
                        .glow(isMatched ? AppColor.successMint : (isPicked ? AppColor.starGold : .clear),
                              radius: (isMatched || isPicked) ? 8 : 0)
                        .scaleEffect(isPicked ? 1.04 : 1)
                        .opacity(isMatched ? 0.6 : 1)
                }
                .buttonStyle(.juicy)
                .disabled(isMatched)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cardBackground(isMatched: Bool, isPicked: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(isMatched ? AnyShapeStyle(AppColor.successMint)
                  : (isPicked && wrongFlash ? AnyShapeStyle(Color(hex: "EF476F"))
                     : AnyShapeStyle(Color.white)))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 18) {
            CharacterView(character: Character3DCatalog.find("lion"))
                .frame(width: 140, height: 140).float(amplitude: 10)
            Text(mistakes == 0 ? "מֻשְׁלָם! 🌟" : "כָּל הַכָּבוֹד! 🎉")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text("הִתְאַמְתָּ אֶת כָּל הַזּוּגוֹת!")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 14) {
                rewardPill("⭐", pairCount, AppColor.starGold, step: 1)
                rewardPill("💎", max(8, 20 - mistakes * 2), AppColor.gemPurple, step: 2)
                rewardPill("🎮", earnedMinutes, AppColor.successMint, step: 3, suffix: " דק'")
            }
            VStack(spacing: 12) {
                Button { deal(); won = false } label: { cta("עוֹד לוּחַ 🔁", dark: true) }.buttonStyle(.juicy)
                Button(action: onClose) { cta("סִיּוּם", dark: false) }.buttonStyle(.juicy)
            }
            .padding(.horizontal, 44).padding(.top, 6)
        }
        .padding(28)
    }

    private func rewardPill(_ emoji: String, _ value: Int, _ color: Color, step: Int, suffix: String = "") -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 26))
            Text("+\(value)\(suffix)").font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(minWidth: 76).padding(.vertical, 12)
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

    private func deal() {
        matched = []; pickedLeft = nil; pickedRight = nil; mistakes = 0; wrongFlash = false; revealStep = 0
        let topics = Array(profiles.active?.enabledTopics ?? Set(Topic.allCases))
        var pairs: [(prompt: String, answer: String)] = []
        var seenAnswers = Set<String>()
        var tries = 0
        while pairs.count < pairCount, tries < 60 {
            tries += 1
            let topic = topics.randomElement() ?? .math
            let base = profiles.active?.difficulty(for: topic) ?? .easy
            let q = QuestionGenerator.generate(topic: topic, difficulty: base)
            let ans = q.correctAnswer
            guard ans.count <= 24, q.prompt.count <= 60, !seenAnswers.contains(ans) else { continue }
            seenAnswers.insert(ans)
            pairs.append((q.prompt, ans))
        }
        lefts = pairs.enumerated().map { Card(pair: $0.offset, text: $0.element.prompt) }.shuffled()
        rights = pairs.enumerated().map { Card(pair: $0.offset, text: $0.element.answer) }.shuffled()
    }

    private func tap(_ card: Card, side: Side) {
        guard !won else { return }
        if side == .left { pickedLeft = (pickedLeft == card.id) ? nil : card.id }
        else { pickedRight = (pickedRight == card.id) ? nil : card.id }
        checkPair()
    }

    private func checkPair() {
        guard let l = pickedLeft, let r = pickedRight,
              let lc = lefts.first(where: { $0.id == l }),
              let rc = rights.first(where: { $0.id == r }) else { return }
        if lc.pair == rc.pair {
            SoundPlayer.shared.play(.correctSmall)
            Haptic.success()
            burst += 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { matched.insert(lc.pair) }
            pickedLeft = nil; pickedRight = nil
            if matched.count == lefts.count { win() }
        } else {
            mistakes += 1
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            withAnimation(.easeInOut(duration: 0.15)) { wrongFlash = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation { wrongFlash = false }
                pickedLeft = nil; pickedRight = nil
            }
        }
    }

    private func win() {
        won = true
        // Max 2 play-minutes per round (2 for a clean round, else 1).
        earnedMinutes = mistakes <= 2 ? 2 : 1
        progress.applyChestReward(ChestReward(stars: pairCount, diamonds: max(8, 20 - mistakes * 2), minutes: earnedMinutes))
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        confetti += 1
        AppAnalytics.log("match_pairs_done", ["mistakes": "\(mistakes)"])
        for s in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(s)) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { revealStep = s }
                SoundPlayer.shared.play(.correctSmall)
            }
        }
    }
}
