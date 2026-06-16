import SwiftUI

/// "הַתְאָמַת זוּגוֹת" — a calm tap-to-match mini-game (no drag plumbing, so it's
/// robust on every device). Two columns: questions on one side, answers on the
/// other, both shuffled. Tap one of each; a correct pair locks in green, a wrong
/// pick just bounces back gently (no penalty). Match them all → reward.
///
/// Pairs are derived from ANY bank/generated question (prompt ↔ correct answer),
/// so it needs no new content and works across topics.
struct MatchPairsView: View {
    var onClose: () -> Void

    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var profiles = ProfileStore.shared

    private let pairCount = 5

    private struct Card: Identifiable { let id = UUID(); let pair: Int; let text: String }

    @State private var lefts: [Card] = []
    @State private var rights: [Card] = []
    @State private var matched: Set<Int> = []     // matched pair indices
    @State private var pickedLeft: UUID? = nil
    @State private var pickedRight: UUID? = nil
    @State private var wrongFlash = false
    @State private var won = false
    @State private var mistakes = 0

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            if won { summary } else { board }

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
        .onAppear { if lefts.isEmpty { deal() } }
    }

    // MARK: - Board

    private var board: some View {
        VStack(spacing: 16) {
            Text("הַתְאִימוּ אֶת הַשְּׁאֵלָה לַתְּשׁוּבָה 🧩")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.top, 60)

            ScrollView(showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    column(cards: lefts, picked: pickedLeft, side: .left)
                    column(cards: rights, picked: pickedRight, side: .right)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
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
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .lineLimit(4).minimumScaleFactor(0.7)
                        .foregroundStyle(isMatched ? .white : AppColor.textOnLight)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .padding(.horizontal, 8).padding(.vertical, 8)
                        .background(cardColor(isMatched: isMatched, isPicked: isPicked),
                                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isPicked ? AppColor.gemPurple : .white.opacity(0.3),
                                    lineWidth: isPicked ? 3 : 1))
                        .opacity(isMatched ? 0.55 : 1)
                }
                .buttonStyle(.juicy)
                .disabled(isMatched)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cardColor(isMatched: Bool, isPicked: Bool) -> Color {
        if isMatched { return AppColor.successMint }
        if isPicked && wrongFlash { return Color(hex: "EF476F").opacity(0.85) }
        return .white
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 18) {
            CharacterView(character: Character3DCatalog.find("lion"))
                .frame(width: 130, height: 130)
            Text(mistakes == 0 ? "מֻשְׁלָם! 🌟" : "כָּל הַכָּבוֹד! 🎉")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("הִתְאַמְתָּ אֶת כָּל הַזּוּגוֹת!")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            VStack(spacing: 12) {
                Button { deal(); won = false } label: { cta("עוֹד לוּחַ 🔁", dark: true) }.buttonStyle(.juicy)
                Button(action: onClose) { cta("סִיּוּם", dark: false) }.buttonStyle(.juicy)
            }
            .padding(.horizontal, 44).padding(.top, 6)
        }
        .padding(28)
    }

    private func cta(_ t: String, dark: Bool) -> some View {
        Text(t).font(.system(size: 19, weight: .heavy, design: .rounded))
            .foregroundStyle(dark ? AppColor.textOnLight : .white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(dark ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.16)), in: Capsule())
    }

    // MARK: - Logic

    private func deal() {
        matched = []; pickedLeft = nil; pickedRight = nil; mistakes = 0; wrongFlash = false
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
            // Keep prompts short enough to read in a card, and answers distinct.
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
            matched.insert(lc.pair)
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
        // Fewer mistakes → a little more 💎.
        let diamonds = max(8, 20 - mistakes * 2)
        progress.applyChestReward(ChestReward(stars: pairCount, diamonds: diamonds, minutes: 0))
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        AppAnalytics.log("match_pairs_done", ["mistakes": "\(mistakes)"])
    }
}
