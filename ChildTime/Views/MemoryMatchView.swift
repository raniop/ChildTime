import SwiftUI

/// "מִשְׂחַק הַזִּכָּרוֹן" — a flip-card memory game that's also English practice:
/// each pair is an emoji and its English word (🐶 ↔ dog). Flip two cards; an
/// emoji + its matching word lock in. Clear the board → confetti + reward.
struct MemoryMatchView: View {
    var onClose: () -> Void

    @ObservedObject private var progress = ProgressStore.shared

    private let pairCount = 8

    /// Kid-friendly emoji → English word vocabulary.
    private static let vocab: [(emoji: String, word: String)] = [
        ("🐶", "dog"), ("🐱", "cat"), ("☀️", "sun"), ("🍎", "apple"),
        ("🚗", "car"), ("🌳", "tree"), ("🏠", "house"), ("⭐", "star"),
        ("🐟", "fish"), ("🌙", "moon"), ("🌸", "flower"), ("🎈", "balloon"),
        ("🦋", "butterfly"), ("🐢", "turtle"), ("🍌", "banana"), ("🌈", "rainbow"),
    ]

    private struct MemCard: Identifiable { let id = UUID(); let key: String; let face: String }

    @State private var cards: [MemCard] = []
    @State private var flipped: [UUID] = []
    @State private var matched: Set<String> = []
    @State private var busy = false
    @State private var mistakes = 0
    @State private var won = false

    @State private var burst = 0
    @State private var confetti = 0
    @State private var earnedMinutes = 0
    @State private var revealStep = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "9B5DE5"), Color(hex: "5B6CFF"), Color(hex: "06D6A0")],
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
        .onAppear { if cards.isEmpty { deal() } }
    }

    private var board: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("מִשְׂחַק הַזִּכָּרוֹן 🧠")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                Text("מָצְאוּ אֶת הָאֶמוֹגִ'י וְהַמִּלָּה הַתּוֹאֶמֶת בְּאַנְגְּלִית")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            }
            .padding(.top, 60)

            Spacer(minLength: 0)
            let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(cards) { card in cardView(card) }
            }
            .padding(.horizontal, 14)
            Spacer(minLength: 0)
        }
    }

    private func cardView(_ card: MemCard) -> some View {
        let isMatched = matched.contains(card.key)
        let isUp = isMatched || flipped.contains(card.id)
        return Button { tap(card) } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isUp ? AnyShapeStyle(Color.white) : AnyShapeStyle(LinearGradient(
                        colors: [Color(hex: "5B6CFF"), Color(hex: "9B5DE5")], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                if isUp {
                    Text(card.face)
                        .font(.system(size: card.face.count <= 2 ? 40 : 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .minimumScaleFactor(0.5).lineLimit(1).padding(4)
                } else {
                    Text("?").font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                }
            }
            .frame(height: 84)
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isMatched ? AppColor.successMint : .white.opacity(0.3), lineWidth: isMatched ? 3 : 1))
            .glow(isMatched ? AppColor.successMint : .clear, radius: isMatched ? 8 : 0)
            .opacity(isMatched ? 0.65 : 1)
            .rotation3DEffect(.degrees(isUp ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .buttonStyle(.juicy)
        .disabled(isMatched || busy)
    }

    // MARK: - Summary

    private var summary: some View {
        VStack(spacing: 18) {
            CharacterView(character: Character3DCatalog.find("lion"))
                .frame(width: 140, height: 140).float(amplitude: 10)
            Text(mistakes <= 2 ? "זִכָּרוֹן מְצֻיָּן! 🌟" : "כָּל הַכָּבוֹד! 🎉")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text("מָצָאתָ אֶת כָּל הַזּוּגוֹת!")
                .font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            HStack(spacing: 14) {
                pill("⭐", pairCount, AppColor.starGold, step: 1)
                pill("💎", max(8, 20 - mistakes * 2), AppColor.gemPurple, step: 2)
                pill("🎮", earnedMinutes, AppColor.successMint, step: 3, suffix: " דק'")
            }
            VStack(spacing: 12) {
                Button { deal(); won = false } label: { cta("עוֹד לוּחַ 🔁", dark: true) }.buttonStyle(.juicy)
                Button(action: onClose) { cta("סִיּוּם", dark: false) }.buttonStyle(.juicy)
            }
            .padding(.horizontal, 44).padding(.top, 6)
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

    private func deal() {
        matched = []; flipped = []; busy = false; mistakes = 0; revealStep = 0
        let chosen = Self.vocab.shuffled().prefix(pairCount)
        var deck: [MemCard] = []
        for v in chosen {
            deck.append(MemCard(key: v.word, face: v.emoji))
            deck.append(MemCard(key: v.word, face: v.word))
        }
        cards = deck.shuffled()
    }

    private func tap(_ card: MemCard) {
        guard !busy, !won, !matched.contains(card.key), !flipped.contains(card.id) else { return }
        SoundPlayer.shared.play(.uiTap)
        flipped.append(card.id)
        guard flipped.count == 2 else { return }
        let a = cards.first { $0.id == flipped[0] }
        let b = cards.first { $0.id == flipped[1] }
        if let a, let b, a.key == b.key {
            SoundPlayer.shared.play(.correctSmall); Haptic.success(); burst += 1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { matched.insert(a.key) }
            flipped = []
            if matched.count == pairCount { win() }
        } else {
            mistakes += 1
            SoundPlayer.shared.play(.wrongSoft); Haptic.light()
            busy = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { flipped = [] }
                busy = false
            }
        }
    }

    private func win() {
        won = true
        // Max 2 play-minutes per round (2 for a clean round, else 1).
        earnedMinutes = mistakes <= 2 ? 2 : 1
        progress.applyChestReward(ChestReward(stars: pairCount, diamonds: max(8, 20 - mistakes * 2), minutes: earnedMinutes))
        SoundPlayer.shared.play(.chestOpen); Haptic.success(); confetti += 1
        AppAnalytics.log("memory_match_done", ["mistakes": "\(mistakes)"])
        for s in 1...3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25 * Double(s)) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { revealStep = s }
                SoundPlayer.shared.play(.correctSmall)
            }
        }
    }
}
