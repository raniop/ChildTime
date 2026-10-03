import SwiftUI

/// 🧩 "בְּנוּ אֶת הַמִּלָּה" — a picture, a row of empty slots, and the word's
/// letters shuffled underneath. Tap them in order to fill the slots (Hebrew
/// fills right-to-left, English left-to-right); a wrong letter just bounces
/// back. A finished word pops in mint and the next one comes. 5 words.
///
/// A world without a picture list spells its own one-word answers, with the
/// question as the clue (capitals, planets, animals — in the child's script).
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser every word
/// built without a bounce earns screen time like a regular answer.
struct BuildWordView: View {
    var topic: Topic? = nil
    /// ⚡ Launched by the runner's surprise round: no intro, one round, ×2.
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    private struct Tile: Identifiable { let id: Int; let letter: Character }

    @State private var started = false
    @State private var done = false
    @State private var script: SpellScript = .english
    @State private var words: [SpellWord] = []
    @State private var index = 0
    @State private var tiles: [Tile] = []
    @State private var usedTiles: Set<Int> = []
    @State private var filled: [Character] = []
    @State private var mistakesThisWord = 0
    @State private var cleanWords = 0
    @State private var wordDone = false
    @State private var wrongTile: Int?
    @State private var shake: CGFloat = 0
    @State private var pop = false
    @State private var burst = 0
    @State private var confetti = 0
    @State private var shownAt = Date()
    @State private var grant: MiniGameReward.Grant?
    /// The clue is the world's question, not a picture.
    @State private var textClues = false
    @State private var wordTopic: Topic = .english

    private var isCompact: Bool { hsc == .compact }
    private var grade: Int { max(1, profiles.active?.effectiveGrade ?? 2) }
    private var current: SpellWord? { index < words.count ? words[index] : nil }
    private var letters: [Character] { current.map { Array(script.display($0.word)) } ?? [] }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "🧩 \(min(index + 1, max(1, words.count)))/\(max(1, words.count))", surprise: surprise)
                }
                if !started {
                    Spacer()
                    MiniGameIntroCard(kind: .word) { begin() }
                    Spacer()
                } else if done {
                    Spacer()
                    MiniGameEndCard(
                        title: cleanWords == words.count ? tr("מֻשְׁלָם! 🌟") : tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: tr("בְּנִיתֶם \(words.count) מִלִּים!"),
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד סִבּוּב 🔁"),
                        onAgain: { begin() },
                        onDone: onClose)
                    Spacer()
                } else {
                    board
                }
            }

            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if (surprise || earn != nil) && !started { begin() } }
    }

    // MARK: - Board

    private var board: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.lg) {
            Spacer(minLength: 0)
            // The picture, in the runner's question card.
            VStack(spacing: 8) {
                Text(tr("בְּנוּ אֶת הַמִּלָּה"))
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                if textClues {
                    Text(current?.emoji ?? "")
                        .font(.system(size: isCompact ? 22 : 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                        .scaleEffect(pop ? 1.06 : 1)
                        .padding(.vertical, 6)
                } else {
                    Text(current?.emoji ?? "")
                        .font(.system(size: display.isShort ? 72 : (isCompact ? 96 : 130)))
                        .scaleEffect(pop ? 1.15 : 1)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 5)
                }
                slots
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14).padding(.vertical, 14)
            .glassPane(radius: 22)
            .padding(.horizontal, AppSpacing.sm)

            tileGrid
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 600 : 720)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
        .id(index)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private var slotSize: CGSize {
        let n = max(1, letters.count)
        let w: CGFloat = isCompact ? min(52, 300 / CGFloat(n)) : min(76, 560 / CGFloat(n))
        return CGSize(width: w, height: w * 1.18)
    }

    private var slots: some View {
        HStack(spacing: 6) {
            ForEach(Array(letters.enumerated()), id: \.offset) { i, _ in
                let ch: Character? = i < filled.count ? filled[i] : nil
                Text(ch.map(String.init) ?? " ")
                    .font(.system(size: slotSize.width * 0.58, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: slotSize.width, height: slotSize.height)
                    .miniGameTile(wordDone ? .correct : (i == filled.count ? .picked : .normal),
                                  tint: .white.opacity(0.2), radius: 12)
            }
        }
        // Hebrew fills from the right, English from the left — whatever the
        // app's own language.
        .environment(\.layoutDirection, script.direction)
    }

    private var tileGrid: some View {
        let cols = [GridItem(.adaptive(minimum: isCompact ? 58 : 72, maximum: isCompact ? 72 : 90), spacing: 10)]
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(tiles) { t in
                let used = usedTiles.contains(t.id)
                Button { tap(t) } label: {
                    Text(String(t.letter))
                        .font(.system(size: isCompact ? 30 : 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isCompact ? 62 : 76)
                        .miniGameTile(wrongTile == t.id ? .wrong : .normal,
                                      tint: OptionCard.tints[t.id % OptionCard.tints.count], radius: 16)
                        .modifier(MiniGameShake(animatableData: wrongTile == t.id ? shake : 0))
                }
                .buttonStyle(.juicy)
                .opacity(used ? 0 : 1)
                .disabled(used || wordDone)
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .environment(\.layoutDirection, script.direction)
    }

    // MARK: - Logic

    private func begin() {
        // The world's own one-word answers where it has no picture list.
        if let topic, !WordSets.hasThemedList(topic, grade: grade),
           case let bank = GameContent.words(topic: topic, grade: grade), bank.count >= WordSets.wordCount,
           let first = bank.first {
            script = first.script
            words = bank.prefix(WordSets.wordCount).map { SpellWord(emoji: $0.clue, word: $0.word) }
            textClues = true
            wordTopic = topic
        } else {
            script = WordSets.script(for: topic, grade: grade)
            words = WordSets.words(for: topic, script: script, grade: grade)
            textClues = false
            wordTopic = script.topic
        }
        index = 0; cleanWords = 0; grant = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { started = true; done = false }
        loadWord()
    }

    private func loadWord() {
        filled = []; usedTiles = []; mistakesThisWord = 0; wordDone = false; wrongTile = nil
        var pool = letters
        // From ג׳ one extra letter keeps it from being pure ordering.
        if grade >= 3 {
            if let x = script.alphabet.filter({ !pool.contains($0) }).randomElement() { pool.append(x) }
        }
        tiles = pool.shuffled().enumerated().map { Tile(id: $0.offset, letter: $0.element) }
        shownAt = Date()
    }

    private func tap(_ t: Tile) {
        guard !wordDone, !usedTiles.contains(t.id), filled.count < letters.count else { return }
        if t.letter == letters[filled.count] {
            Haptic.light()
            SoundPlayer.shared.play(.uiTap)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                usedTiles.insert(t.id)
                filled.append(t.letter)
            }
            if filled.count == letters.count { wordFinished() }
        } else {
            // A gentle bounce — the letter stays where it is.
            mistakesThisWord += 1
            SoundPlayer.shared.play(.wrongSoft)
            Haptic.light()
            wrongTile = t.id
            withAnimation(.linear(duration: 0.35)) { shake += 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.easeOut(duration: 0.2)) { if wrongTile == t.id { wrongTile = nil } }
            }
        }
    }

    private func wordFinished() {
        let clean = mistakesThisWord == 0
        if clean { cleanWords += 1 }
        // One answer per word in the parent's reports — right the first time,
        // or a miss if a letter bounced.
        MiniGameLedger.record(correct: clean, topic: wordTopic,
                              responseMs: Date().timeIntervalSince(shownAt) * 1000,
                              earn: earn, surprise: surprise)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { wordDone = true; pop = true }
        burst += 1
        SoundPlayer.shared.play(.correctBig)
        Haptic.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pop = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard started, !done else { return }
            if index + 1 < words.count {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { index += 1 }
                loadWord()
            } else {
                finish()
            }
        }
    }

    private func finish() {
        grant = MiniGameReward.grant(game: "word", correct: words.count, starsPer: 2, diamondsPer: 2,
                                     cap: WordSets.wordCount, surprise: surprise)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { done = true }
        SoundPlayer.shared.play(.chestOpen)
        Haptic.success()
        confetti += 1
        AppAnalytics.log("build_word_done", ["script": "\(script)", "clean": "\(cleanWords)",
                                             "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    BuildWordView(topic: .english, onClose: {})
}
