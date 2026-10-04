import SwiftUI
import Combine

/// 🔤 "תַּפְזֹרֶת" — a letter grid with five themed words hidden in it. Drag a
/// finger along a word: a found word stays highlighted and is ticked off in the
/// list underneath. Hebrew reads right-to-left without niqqud; English
/// left-to-right in capitals. After 30 seconds without a find, the first letter
/// of a hidden word glows for a moment.
///
/// 🎚️ The grid, the diagonals and the backwards words all come from the child's
/// grade AND from which language the board is in (`WordSearchShape`): the
/// mother-tongue board climbs 6×6 → 9×9 with diagonals from ג׳ and backwards
/// words from ה׳, while a foreign-language board stays 6×6 → 7×7 and never runs
/// a word back-to-front. Rani, 2026-10-04: "תפזורת באנגלית זה בסדר גם לכיתה ו,
/// אבל בעברית זה קל מידי."
///
/// A world without a themed picture list hides its own one-word answers.
///
/// In a ⚡ surprise round it pays ⭐/💎 only; from a world's chooser every word
/// found earns screen time like a regular answer.
struct WordSearchView: View {
    var topic: Topic? = nil
    /// ⚡ Launched by the runner's surprise round: no intro, one board, ×2.
    var surprise: Bool = false
    var earn: MiniGameEarnSession? = nil
    var onClose: () -> Void

    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.horizontalSizeClass) private var hsc

    /// Colours a found word is painted in, one per word.
    private static let palette: [Color] = [Color(hex: "06D6A0"), Color(hex: "48BFE3"), Color(hex: "FF6B9D"),
                                           Color(hex: "FFB84D"), Color(hex: "9B5DE5")]
    private static let hintAfter: TimeInterval = 30

    @State private var started = false
    @State private var done = false
    @State private var board: WordSearchBoard?
    @State private var found: [String] = []
    @State private var dragStart: GridCell?
    @State private var dragCells: [GridCell] = []
    @State private var lastFindAt = Date()
    @State private var hintCell: GridCell?
    @State private var hintPulse = false
    @State private var shownAt = Date()
    @State private var burst = 0
    @State private var confetti = 0
    @State private var grant: MiniGameReward.Grant?
    @State private var wordTopic: Topic = .english

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isCompact: Bool { hsc == .compact }
    private var grade: Int { max(1, profiles.active?.effectiveGrade ?? 2) }
    /// A regular-width screen with the height to show a big grid.
    private var roomy: Bool { !isCompact && !display.isShort }
    /// The script the next board will be in — the grid's size depends on it.
    private var plannedScript: SpellScript {
        if let topic, !WordSets.hasThemedList(topic, grade: grade),
           let first = GameContent.words(topic: topic, grade: grade, maxLetters: 8).first {
            return first.script
        }
        return WordSets.script(for: topic, grade: grade)
    }
    private func gridSize(_ script: SpellScript) -> Int {
        WordSearchShape.size(grade: grade, script: script, roomy: roomy)
    }
    private var words: [HiddenWord] { board?.words ?? [] }

    var body: some View {
        ZStack {
            MiniGameBackdrop()

            VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
                MiniGameTopBar(onClose: onClose, earn: surprise ? nil : earn) {
                    MiniGameChipLabel(text: "🔤 \(found.count)/\(max(1, words.count))", surprise: surprise)
                }
                if !started {
                    Spacer()
                    MiniGameIntroCard(kind: .wordSearch) { deal() }
                    Spacer()
                } else if done {
                    Spacer()
                    MiniGameEndCard(
                        title: tr("כָּל הַכָּבוֹד! 🎉"),
                        detail: tr("מְצָאתֶם אֶת כָּל הַמִּלִּים!"),
                        grant: grant,
                        surprise: surprise,
                        againLabel: tr("עוֹד לוּחַ 🔁"),
                        onAgain: { deal() },
                        onDone: onClose)
                    Spacer()
                } else {
                    playing
                }
            }

            StarBurst(color: AppColor.successMint, trigger: burst)
            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { if (surprise || earn != nil) && !started { deal() } }
        .onReceive(ticker) { t in hintTick(t) }
    }

    // MARK: - Board

    private var playing: some View {
        VStack(spacing: display.isShort ? AppSpacing.sm : AppSpacing.md) {
            // An iPad: the board sits in the middle of the glass, not at the top.
            if !isCompact && !display.isShort { Spacer(minLength: 0) }
            Text(tr("גִּרְרוּ אֶצְבַּע עַל כָּל מִלָּה שֶׁמְּצָאתֶם"))
                .font(.system(size: isCompact ? 15 : 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .glassPane(radius: 18, shadow: false)

            letterGrid
                .padding(10)
                .glassPane(radius: 24)

            wordList
            Spacer(minLength: 0)
        }
        .frame(maxWidth: isCompact ? 620 : 700)
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.sm)
    }

    /// The grid is laid out left-to-right on purpose and mirrored by hand for
    /// Hebrew: the drag's coordinates then map to cells one way only.
    private var letterGrid: some View {
        GeometryReader { geo in
            let n = board?.size ?? gridSize(plannedScript)
            let side = min(geo.size.width, geo.size.height)
            let cell = side / CGFloat(n)
            ZStack(alignment: .topLeading) {
                if let board {
                    ForEach(0..<n, id: \.self) { r in
                        ForEach(0..<n, id: \.self) { c in
                            let gc = GridCell(r: r, c: c)
                            cellView(board.letters[r][c], state: state(of: gc), size: cell)
                                .position(x: CGFloat(visualColumn(c, n: n)) * cell + cell / 2,
                                          y: CGFloat(r) * cell + cell / 2)
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in dragChanged(v, cell: cell, n: n) }
                    .onEnded { _ in dragEnded() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: isCompact ? 400 : 620)
        .environment(\.layoutDirection, .leftToRight)
    }

    private enum CellState: Equatable { case plain, selecting, found(Int), hint }

    private func state(of cell: GridCell) -> CellState {
        if dragCells.contains(cell) { return .selecting }
        if let i = words.firstIndex(where: { found.contains($0.word) && $0.cells.contains(cell) }) { return .found(i) }
        if cell == hintCell { return .hint }
        return .plain
    }

    private func cellView(_ letter: Character, state: CellState, size: CGFloat) -> some View {
        let fill: Color = {
            switch state {
            case .plain:          return .white.opacity(0.10)
            case .selecting:      return AppColor.starGold.opacity(0.55)
            case .found(let i):   return Self.palette[i % Self.palette.count].opacity(0.62)
            case .hint:           return AppColor.starGold.opacity(hintPulse ? 0.7 : 0.2)
            }
        }()
        return Text(String(letter))
            .font(.system(size: size * 0.5, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size - 4, height: size - 4)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .strokeBorder(state == .selecting || state == .hint ? AppColor.starGold : .white.opacity(0.12),
                              lineWidth: state == .selecting || state == .hint ? 2 : 1))
            .scaleEffect(state == .selecting ? 1.08 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: state)
    }

    /// The words to find, ticked as they're found.
    private var wordList: some View {
        let cols = [GridItem(.adaptive(minimum: isCompact ? 96 : 130), spacing: 8)]
        return LazyVGrid(columns: cols, spacing: 8) {
            ForEach(Array(words.enumerated()), id: \.element.id) { i, w in
                let isFound = found.contains(w.word)
                HStack(spacing: 6) {
                    if w.emoji.count <= 2 { Text(w.emoji).font(.system(size: 18)) }
                    Text(w.word)
                        .font(.system(size: isCompact ? 16 : 19, weight: .heavy, design: .rounded))
                        .strikethrough(isFound, color: .white.opacity(0.8))
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .environment(\.layoutDirection, board?.script.direction ?? .leftToRight)
                    if isFound {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColor.successMint)
                    }
                }
                .foregroundStyle(.white.opacity(isFound ? 0.75 : 1))
                .padding(.horizontal, 10).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Capsule().fill(isFound ? Self.palette[i % Self.palette.count].opacity(0.35) : .white.opacity(0.14)))
                .overlay(Capsule().strokeBorder(.white.opacity(0.30), lineWidth: 1))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFound)
            }
        }
    }

    // MARK: - Geometry

    /// Logical column 0 is where a line STARTS: the right edge for Hebrew.
    private func visualColumn(_ c: Int, n: Int) -> Int {
        board?.script.direction == .rightToLeft ? n - 1 - c : c
    }

    private func cellAt(_ p: CGPoint, cell: CGFloat, n: Int) -> GridCell? {
        let vc = Int(p.x / cell), r = Int(p.y / cell)
        guard (0..<n).contains(vc), (0..<n).contains(r) else { return nil }
        return GridCell(r: r, c: board?.script.direction == .rightToLeft ? n - 1 - vc : vc)
    }

    private func dragChanged(_ v: DragGesture.Value, cell: CGFloat, n: Int) {
        guard started, !done else { return }
        if dragStart == nil {
            guard let s = cellAt(v.startLocation, cell: cell, n: n) else { return }
            dragStart = s
            Haptic.selection()
        }
        guard let s = dragStart else { return }
        // Clamp the finger to the grid, then snap to a straight line from the start.
        let p = CGPoint(x: min(max(v.location.x, 0), cell * CGFloat(n) - 1),
                        y: min(max(v.location.y, 0), cell * CGFloat(n) - 1))
        guard let e = cellAt(p, cell: cell, n: n) else { return }
        let line = snappedLine(from: s, to: e, n: n)
        if line != dragCells {
            if line.count > dragCells.count { Haptic.selection() }
            dragCells = line
        }
    }

    /// Across, down, or (from ד׳) diagonal — whichever is closest to the finger.
    private func snappedLine(from s: GridCell, to e: GridCell, n: Int) -> [GridCell] {
        let dr = e.r - s.r, dc = e.c - s.c
        let adr = abs(dr), adc = abs(dc)
        var stepR = 0, stepC = 0, len = 0
        if adr == 0 && adc == 0 { return [s] }
        let diagonalOK = board?.diagonals ?? false
        if diagonalOK && adr > 0 && adc > 0 && Double(min(adr, adc)) >= Double(max(adr, adc)) * 0.5 {
            stepR = dr.signum(); stepC = dc.signum(); len = max(adr, adc)
        } else if adc >= adr {
            stepC = dc.signum(); len = adc
        } else {
            stepR = dr.signum(); len = adr
        }
        var out: [GridCell] = []
        for i in 0...len {
            let r = s.r + stepR * i, c = s.c + stepC * i
            guard (0..<n).contains(r), (0..<n).contains(c) else { break }
            out.append(GridCell(r: r, c: c))
        }
        return out
    }

    // MARK: - Logic

    private func deal() {
        if let topic, !WordSets.hasThemedList(topic, grade: grade),
           case let probeSize = gridSize(plannedScript),
           case let bank = GameContent.words(topic: topic, grade: grade, maxLetters: probeSize),
           bank.count >= WordSearch.wordCount, let first = bank.first {
            // The world's own answers — no pictures, the words are the list.
            board = WordSearch.make(words: bank.map { SpellWord(emoji: "", word: $0.word) },
                                    script: first.script, grade: grade,
                                    size: gridSize(first.script))
            wordTopic = topic
        } else {
            let script = WordSets.script(for: topic, grade: grade)
            board = WordSearch.make(topic: topic, script: script, grade: grade, size: gridSize(script))
            wordTopic = script.topic
        }
        found = []; dragStart = nil; dragCells = []; hintCell = nil; grant = nil
        lastFindAt = Date(); shownAt = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { started = true; done = false }
    }

    private func dragEnded() {
        defer {
            dragStart = nil
            withAnimation(.easeOut(duration: 0.2)) { dragCells = [] }
        }
        guard dragCells.count >= 2 else { return }
        // Either direction counts — a word dragged end-to-start is still found.
        let hit = words.first { w in
            !found.contains(w.word) && (w.cells == dragCells || w.cells == Array(dragCells.reversed()))
        }
        guard let w = hit else {
            // Not a word: the selection simply fades — nothing recorded.
            Haptic.light()
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { found.append(w.word) }
        if hintCell.map({ w.cells.contains($0) }) == true { hintCell = nil }
        lastFindAt = Date()
        burst += 1
        SoundPlayer.shared.play(.correctBig)
        Haptic.success()
        // One answer per found word in the parent's reports.
        MiniGameLedger.record(correct: true, topic: wordTopic,
                              responseMs: Date().timeIntervalSince(shownAt) * 1000 / Double(max(1, words.count)),
                              streak: found.count, earn: earn, surprise: surprise)
        if found.count == words.count { finish() }
    }

    /// 30 seconds without a find → the first letter of a hidden word glows.
    private func hintTick(_ t: Date) {
        guard started, !done else { return }
        if hintCell != nil {
            withAnimation(.easeInOut(duration: 0.5)) { hintPulse.toggle() }
            return
        }
        guard t.timeIntervalSince(lastFindAt) >= Self.hintAfter,
              let w = words.filter({ !found.contains($0.word) }).randomElement(),
              let first = w.cells.first else { return }
        hintCell = first
        SoundPlayer.shared.play(.uiTap)
        // The glow fades after a few seconds; the next hint waits another 30.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeOut(duration: 0.3)) { hintCell = nil; hintPulse = false }
            lastFindAt = Date()
        }
    }

    private func finish() {
        grant = MiniGameReward.grant(game: "wordsearch", correct: found.count, starsPer: 2, diamondsPer: 2,
                                     cap: WordSearch.wordCount, surprise: surprise)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { done = true }
            SoundPlayer.shared.play(.chestOpen)
            Haptic.success()
            confetti += 1
        }
        AppAnalytics.log("word_search_done", ["script": board.map { "\($0.script)" } ?? "",
                                              "surprise": surprise ? "1" : "0"])
    }
}

#Preview {
    WordSearchView(topic: .animals, onClose: {})
}
