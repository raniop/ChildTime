import SwiftUI

/// A still miniature of each game's own screen, drawn with the same glass
/// tiles and colours, for its card in a world's chooser — the child sees what
/// the game looks like before choosing it.
///
/// 👶 For a גן child the miniature has to be text-free too, or the one place
/// that promises "no words" would be the place that breaks it: the five
/// pre-reader games draw pictures, colours and shapes here instead of words
/// and numerals (see `PreReaderGames`).
struct MiniGamePreview: View {
    let kind: MiniGameKind
    /// The world's topic, so the miniature shows the world's kind of content.
    var topic: Topic?
    /// 👶 Draw the pre-reader's board. Defaults to the active child.
    var preReader: Bool = PreReaderGames.activeChildIsPreReader

    private static let blue = Color(hex: "48BFE3"), purple = Color(hex: "9B5DE5"), pink = Color(hex: "FF6B9D"),
                        orange = Color(hex: "FFB84D"), mint = Color(hex: "06D6A0")
    private var wordy: Bool { topic == .english || topic == .hebrew || topic == .reading }
    /// Word games show the letters the child actually plays with: Hebrew in
    /// every world but English for a Hebrew-speaking child.
    private var hebrewLetters: Bool { topic == .hebrew || (topic != .english && LanguageStore.shared.current == .he) }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height * 1.6)
            content(s)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(\.layoutDirection, .leftToRight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func content(_ s: CGFloat) -> some View {
        if preReader, kind.hasPreReaderForm {
            preReaderContent(s)
        } else {
            readerContent(s)
        }
    }

    // MARK: - 👶 The five גן boards, with nothing to read

    @ViewBuilder
    private func preReaderContent(_ s: CGFloat) -> some View {
        switch kind {
        case .pairs:   prePairs(s)
        case .balloon: preBalloons(s)
        case .sort:    preSort(s)
        case .pattern: prePattern(s)
        case .crush:   preCount(s)
        default:       readerContent(s)
        }
    }

    /// 🔗 Four picture pairs — 🦴 with 🐶, 🥚 with 🐣.
    private func prePairs(_ s: CGFloat) -> some View {
        let w = s * 0.32, h = s * 0.17, f = s * 0.11
        return HStack(spacing: s * 0.06) {
            VStack(spacing: s * 0.035) {
                tile("🦴", OptionCard.tints[0], .correct, w: w, h: h, font: f)
                tile("🥚", OptionCard.tints[1], .picked, w: w, h: h, font: f)
                tile("☂️", OptionCard.tints[2], w: w, h: h, font: f)
            }
            VStack(spacing: s * 0.035) {
                tile("🐣", OptionCard.tints[2], w: w, h: h, font: f)
                tile("🐶", OptionCard.tints[3], .correct, w: w, h: h, font: f)
                tile("🌧️", OptionCard.tints[0], w: w, h: h, font: f)
            }
        }
    }

    /// 🎈 One picture, one colour and a quantity — the three גן rules at once.
    private func preBalloons(_ s: CGFloat) -> some View {
        let items: [(String, Color, CGFloat, CGFloat)] = [("🐶", Self.pink, -0.27, 0.05), ("", Self.blue, 0, -0.08),
                                                          ("🍎🍎", Self.orange, 0.27, 0.07)]
        return ZStack {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                VStack(spacing: 0) {
                    Text(it.0)
                        .font(.system(size: it.0.count > 1 ? s * 0.08 : s * 0.13))
                        .lineLimit(1).minimumScaleFactor(0.4)
                        .frame(width: s * 0.22, height: s * 0.26)
                        .background(Ellipse().fill(RadialGradient(colors: [it.1.opacity(0.95), it.1.opacity(0.75)],
                                                                  center: UnitPoint(x: 0.35, y: 0.3),
                                                                  startRadius: 1, endRadius: s * 0.22)))
                        .overlay(Ellipse().strokeBorder(.white.opacity(0.45), lineWidth: 1))
                    Rectangle().fill(.white.opacity(0.55)).frame(width: 1, height: s * 0.07)
                }
                .offset(x: s * it.2, y: s * it.3)
            }
        }
    }

    /// 🧺 Two baskets wearing pictures, and a picture to drop in.
    private func preSort(_ s: CGFloat) -> some View {
        let baskets = ["🌊", "🌳"]
        return VStack(spacing: s * 0.05) {
            tile("🐬", AppColor.starGold, .picked, w: s * 0.26, h: s * 0.17, font: s * 0.1)
            HStack(spacing: s * 0.06) {
                ForEach(baskets.indices, id: \.self) { i in
                    Text(baskets[i])
                        .font(.system(size: s * 0.1))
                        .frame(width: s * 0.3, height: s * 0.21)
                        .miniGameTile(.normal, tint: i == 0 ? Self.blue : Self.mint, radius: 12)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .padding(3))
                }
            }
        }
    }

    /// 🧠 🔴 🔵 🔴 🔵 ❓ and three pictures to choose from.
    private func prePattern(_ s: CGFloat) -> some View {
        let seq = ["🔴", "🔵", "🔴", "🔵", "?"]
        let opts = ["🟡", "🔴", "🟢"]
        let w = s * 0.145
        return VStack(spacing: s * 0.05) {
            HStack(spacing: s * 0.02) {
                ForEach(seq.indices, id: \.self) { i in
                    tile(seq[i], .white.opacity(0.2), seq[i] == "?" ? .picked : .normal, w: w, h: w, font: w * 0.55)
                }
            }
            HStack(spacing: s * 0.035) {
                ForEach(opts.indices, id: \.self) { i in
                    tile(opts[i], OptionCard.tints[i], i == 1 ? .correct : .normal, w: w * 1.2, h: w, font: w * 0.5)
                }
            }
        }
    }

    /// 🧱 A row of apples to collect, and blocks carrying one, two or three.
    private func preCount(_ s: CGFloat) -> some View {
        let side = s * 0.16
        let blocks = ["🍎", "🍎🍎", "🍎🍎🍎"]
        let colors: [Color] = [Self.pink, Self.mint, Self.orange]
        return VStack(spacing: s * 0.05) {
            HStack(spacing: 1) {
                ForEach(0..<4, id: \.self) { _ in Text("🍎").font(.system(size: s * 0.085)) }
            }
            HStack(spacing: s * 0.03) {
                ForEach(blocks.indices, id: \.self) { i in
                    Text(blocks[i])
                        .font(.system(size: side * (0.5 - CGFloat(i) * 0.11)))
                        .lineLimit(1).minimumScaleFactor(0.4)
                        .frame(width: side, height: side)
                        .background(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                            .fill(colors[i].opacity(0.85)))
                        .overlay(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                            .strokeBorder(i == 0 ? AppColor.starGold : .white.opacity(0.45), lineWidth: i == 0 ? 2.5 : 1))
                }
            }
        }
    }

    // MARK: - The twelve as a reader sees them

    @ViewBuilder
    private func readerContent(_ s: CGFloat) -> some View {
        switch kind {
        case .pairs:      pairs(s)
        case .balloon:    balloons(s)
        case .word:       word(s)
        case .crush:      crush(s)
        case .wordSearch: wordSearch(s)
        case .lightning:  lightning(s)
        case .sort:       sort(s)
        case .pattern:    pattern(s)
        case .game2048:   g2048(s)
        case .vault:      vault(s)
        case .grocery:    grocery(s)
        case .balance:    balance(s)
        }
    }

    // MARK: - Bits

    private func tile(_ text: String, _ tint: Color, _ state: MiniGameTileState = .normal, w: CGFloat, h: CGFloat, font: CGFloat) -> some View {
        Text(text)
            .font(.system(size: font, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.5)
            .frame(width: w, height: h)
            .miniGameTile(state, tint: tint, radius: min(w, h) * 0.26)
    }

    private func solid(_ text: String, _ color: Color, side: CGFloat) -> some View {
        Text(text)
            .font(.system(size: side * 0.42, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .background(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous).fill(color.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous).strokeBorder(.white.opacity(0.45), lineWidth: 1))
    }

    // MARK: - The twelve

    private func pairs(_ s: CGFloat) -> some View {
        let w = s * 0.34, h = s * 0.14, f = s * 0.07
        let hebrewish = topic == .hebrew || topic == .reading
        let left = topic == .math ? ["6 × 7", "9 + 8", "45 ÷ 5"] : ["🐶", "☀️", "🍎"]
        let right: [String] = topic == .math ? ["17", "42", "9"]
            : (topic == .english ? ["sun", "dog", "apple"] : (hebrewish ? ["שֶׁמֶשׁ", "כֶּלֶב", "תַּפּוּחַ"] : ["🌙", "🦴", "🌳"]))
        return HStack(spacing: s * 0.05) {
            VStack(spacing: s * 0.03) {
                tile(left[0], OptionCard.tints[0], .correct, w: w, h: h, font: f)
                tile(left[1], OptionCard.tints[1], .picked, w: w, h: h, font: f)
                tile(left[2], OptionCard.tints[2], w: w, h: h, font: f)
            }
            VStack(spacing: s * 0.03) {
                tile(right[0], OptionCard.tints[2], w: w, h: h, font: f)
                tile(right[1], OptionCard.tints[3], .correct, w: w, h: h, font: f)
                tile(right[2], OptionCard.tints[0], w: w, h: h, font: f)
            }
        }
    }

    private func balloons(_ s: CGFloat) -> some View {
        let items: [(String, Color, CGFloat, CGFloat)] = [("🐙", Self.pink, -0.26, 0.04), ("12", Self.blue, 0, -0.08),
                                                          ("🦁", Self.orange, 0.26, 0.06)]
        return ZStack {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                VStack(spacing: 0) {
                    Text(it.0)
                        .font(.system(size: s * 0.09, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: s * 0.2, height: s * 0.24)
                        .background(Ellipse().fill(RadialGradient(colors: [it.1.opacity(0.95), it.1.opacity(0.75)],
                                                                  center: UnitPoint(x: 0.35, y: 0.3), startRadius: 1, endRadius: s * 0.2)))
                        .overlay(Ellipse().strokeBorder(.white.opacity(0.45), lineWidth: 1))
                    Rectangle().fill(.white.opacity(0.55)).frame(width: 1, height: s * 0.08)
                }
                .offset(x: s * it.2, y: s * it.3)
            }
        }
    }

    private func word(_ s: CGFloat) -> some View {
        let letters = hebrewLetters ? ["ב", "י", "ת"] : ["C", "A", "T"]
        let w = s * 0.13
        return VStack(spacing: s * 0.04) {
            Text(hebrewLetters ? "🏠" : "🐱").font(.system(size: s * 0.16))
            HStack(spacing: s * 0.02) {
                tile(letters[0], .white.opacity(0.2), .normal, w: w, h: w * 1.15, font: w * 0.55)
                tile(letters[1], .white.opacity(0.2), .normal, w: w, h: w * 1.15, font: w * 0.55)
                tile("", .white.opacity(0.2), .picked, w: w, h: w * 1.15, font: w * 0.55)
            }
            .environment(\.layoutDirection, hebrewLetters ? .rightToLeft : .leftToRight)
            HStack(spacing: s * 0.025) {
                ForEach(Array((hebrewLetters ? ["ת", "ש", "מ"] : ["T", "O", "S"]).enumerated()), id: \.offset) { i, l in
                    tile(l, OptionCard.tints[i], w: w * 0.9, h: w * 0.9, font: w * 0.5)
                }
            }
        }
    }

    private func crush(_ s: CGFloat) -> some View {
        let side = s * 0.13
        let vals = [["3", "7", "5", "2"], ["6", "4", "8", "1"]]
        let colors: [Color] = [Self.pink, Self.mint, Self.orange, Self.blue, Self.purple]
        return VStack(spacing: s * 0.03) {
            HStack(spacing: 4) {
                Text("🎯").font(.system(size: s * 0.07))
                Text("10").font(.system(size: s * 0.11, weight: .black, design: .rounded)).foregroundStyle(AppColor.starGold)
            }
            ForEach(0..<2, id: \.self) { r in
                HStack(spacing: s * 0.025) {
                    ForEach(0..<4, id: \.self) { c in
                        solid(vals[r][c], colors[(r * 4 + c) % colors.count], side: side)
                            .overlay(RoundedRectangle(cornerRadius: side * 0.22).strokeBorder(AppColor.starGold, lineWidth: (r == 0 && (c == 0 || c == 1)) ? 2.5 : 0))
                    }
                }
            }
        }
    }

    private func wordSearch(_ s: CGFloat) -> some View {
        let grid = hebrewLetters
            ? [["כ", "ל", "ב", "ש"], ["ע", "ץ", "ר", "מ"], ["ס", "פ", "ר", "ד"], ["ג", "ת", "י", "נ"]]
            : [["D", "O", "G", "K"], ["S", "U", "N", "A"], ["P", "C", "A", "T"], ["E", "R", "B", "L"]]
        let hit: Set<Int> = [0, 1, 2]
        let cell = s * 0.105
        return VStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { r in
                HStack(spacing: 2) {
                    ForEach(0..<4, id: \.self) { c in
                        Text(grid[r][c])
                            .font(.system(size: cell * 0.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: cell, height: cell)
                            .background(RoundedRectangle(cornerRadius: cell * 0.25)
                                .fill(r == 0 && hit.contains(c) ? Self.mint.opacity(0.65) : .white.opacity(0.10)))
                    }
                }
            }
        }
        .padding(6)
        .glassInset(radius: 10)
    }

    private func lightning(_ s: CGFloat) -> some View {
        VStack(spacing: s * 0.04) {
            tile(topic == .math || topic == nil ? "7 × 8 = 56"
                 : (topic == .english ? "cat = 🐱" : (wordy ? "חָתוּל = 🐱" : "🐬 → 🌊")),
                 AppColor.starGold, .normal, w: s * 0.62, h: s * 0.17, font: s * 0.075)
            HStack(spacing: s * 0.05) {
                tile("✓", AppColor.successMint, .correct, w: s * 0.28, h: s * 0.17, font: s * 0.09)
                tile("✗", Color(hex: "B7ABFF"), w: s * 0.28, h: s * 0.17, font: s * 0.09)
            }
        }
    }

    private func sort(_ s: CGFloat) -> some View {
        let item = topic == .math ? "14" : (topic == .english ? "dog" : "🐬")
        let baskets = topic == .math ? ["👯", "🧍"] : ["🌊", "🌳"]
        return VStack(spacing: s * 0.05) {
            tile(item, AppColor.starGold, .picked, w: s * 0.24, h: s * 0.15, font: s * 0.08)
            HStack(spacing: s * 0.06) {
                ForEach(baskets.indices, id: \.self) { i in
                    Text(baskets[i])
                        .font(.system(size: s * 0.09))
                        .frame(width: s * 0.3, height: s * 0.2)
                        .miniGameTile(.normal, tint: i == 0 ? Self.blue : Self.pink, radius: 12)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).padding(3))
                }
            }
        }
    }

    private func pattern(_ s: CGFloat) -> some View {
        let seq = topic == .english ? ["A", "C", "E", "G", "?"] : (topic == .hebrew ? ["א", "ב", "ג", "ד", "?"] : ["2", "4", "6", "8", "?"])
        let w = s * 0.14
        return VStack(spacing: s * 0.05) {
            HStack(spacing: s * 0.02) {
                ForEach(seq.indices, id: \.self) { i in
                    tile(seq[i], .white.opacity(0.2), seq[i] == "?" ? .picked : .normal, w: w, h: w, font: w * 0.5)
                }
            }
            .environment(\.layoutDirection, topic == .hebrew ? .rightToLeft : .leftToRight)
            HStack(spacing: s * 0.03) {
                ForEach(Array((topic == .english ? ["H", "I", "J"] : (topic == .hebrew ? ["ה", "ו", "ז"] : ["9", "10", "12"])).enumerated()), id: \.offset) { i, o in
                    tile(o, OptionCard.tints[i], i == 1 ? .correct : .normal, w: w * 1.2, h: w * 0.9, font: w * 0.45)
                }
            }
        }
    }

    private func g2048(_ s: CGFloat) -> some View {
        let vals = [[2, 4, 0], [8, 16, 2], [32, 0, 4]]
        let side = s * 0.15
        return VStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { c in
                        let v = vals[r][c]
                        if v == 0 {
                            RoundedRectangle(cornerRadius: side * 0.2).fill(.white.opacity(0.1)).frame(width: side, height: side)
                        } else {
                            solid("\(v)", Board2048.color(v), side: side)
                        }
                    }
                }
            }
        }
        .padding(5)
        .glassInset(radius: 10)
    }

    /// 🔐 The door being typed into, above the clue list that opens it.
    private func vault(_ s: CGFloat) -> some View {
        let side = s * 0.13
        return VStack(spacing: s * 0.04) {
            HStack(spacing: s * 0.025) {
                tile("7", AppColor.starGold, .picked, w: side, h: side * 1.1, font: side * 0.5)
                tile("•", .white.opacity(0.18), w: side, h: side * 1.1, font: side * 0.42)
                tile("•", .white.opacity(0.18), w: side, h: side * 1.1, font: side * 0.42)
            }
            VStack(spacing: s * 0.022) {
                clueBar(s, open: true, fill: 0.46)
                clueBar(s, open: true, fill: 0.34)
                clueBar(s, open: false, fill: 0.26)
            }
        }
    }

    private func clueBar(_ s: CGFloat, open: Bool, fill: CGFloat) -> some View {
        HStack(spacing: s * 0.025) {
            Text(open ? "🔑" : "🔒").font(.system(size: s * 0.05))
            Capsule().fill(.white.opacity(open ? 0.5 : 0.16))
                .frame(width: s * fill, height: s * 0.032)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, s * 0.03)
        .padding(.vertical, s * 0.016)
        .frame(width: s * 0.72, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: s * 0.032, style: .continuous)
            .fill(.white.opacity(open ? 0.12 : 0.05)))
    }

    private func grocery(_ s: CGFloat) -> some View {
        let items: [(String, String)] = [("🥛", "6"), ("🍞", "8"), ("🍎", "3")]
        return VStack(spacing: s * 0.035) {
            Text("💰 20 ₪")
                .font(.system(size: s * 0.07, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.14)))
            HStack(spacing: s * 0.03) {
                ForEach(items.indices, id: \.self) { i in
                    VStack(spacing: 1) {
                        Text(items[i].0).font(.system(size: s * 0.08))
                        Text(items[i].1 + " ₪").font(.system(size: s * 0.05, weight: .black, design: .rounded)).foregroundStyle(.white)
                    }
                    .frame(width: s * 0.2, height: s * 0.2)
                    .miniGameTile(i == 0 ? .picked : .normal, tint: OptionCard.tints[i], radius: 10)
                }
            }
            Text("🛒 🥛").font(.system(size: s * 0.07))
        }
    }

    private func balance(_ s: CGFloat) -> some View {
        ZStack {
            Rectangle().fill(.white.opacity(0.5)).frame(width: 3, height: s * 0.3).offset(y: s * 0.05)
            Capsule().fill(LinearGradient(colors: [Color(hex: "FFD23F"), Color(hex: "FF9F1C")], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.66, height: 6)
                .rotationEffect(.degrees(8))
                .offset(y: -s * 0.1)
            tile("7 + ?", AppColor.starGold, .picked, w: s * 0.26, h: s * 0.13, font: s * 0.06)
                .offset(x: -s * 0.3, y: s * 0.03)
            tile("12", .white.opacity(0.2), w: s * 0.22, h: s * 0.13, font: s * 0.07)
                .offset(x: s * 0.3, y: s * 0.12)
        }
    }
}

/// The regular questions' card miniature: a question line and four answers.
struct QuestionsPreview: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height * 1.5)
            VStack(spacing: s * 0.05) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.85))
                    .frame(width: s * 0.6, height: s * 0.06)
                RoundedRectangle(cornerRadius: 6)
                    .fill(.white.opacity(0.5))
                    .frame(width: s * 0.4, height: s * 0.05)
                LazyVGrid(columns: [GridItem(.fixed(s * 0.4), spacing: s * 0.04), GridItem(.fixed(s * 0.4))], spacing: s * 0.04) {
                    ForEach(0..<4, id: \.self) { i in
                        Capsule()
                            .fill(.clear)
                            .frame(height: s * 0.13)
                            .miniGameTile(i == 2 ? .correct : .normal, tint: OptionCard.tints[i], radius: s * 0.065)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
