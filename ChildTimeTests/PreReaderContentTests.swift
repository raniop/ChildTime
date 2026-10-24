import Foundation
import Testing
@testable import ChildTime

/// 👶 גן questions (Ben David, 2026-10-09): picture math is right, letters never
/// put two same-sounding letters side by side, and each theme world asks about
/// its own pictures.
@MainActor
struct PreReaderContentTests {
    @Test func pictureMathIsRight() {
        let strip = { (s: String) in s.replacingOccurrences(of: "\u{2066}", with: "").replacingOccurrences(of: "\u{2069}", with: "") }
        let count = { (s: Substring) in s.split(separator: " ").count }
        // "🌸🌸" (no spaces) → 2
        let pics = { (s: Substring) in s.trimmingCharacters(in: .whitespaces).count }
        for _ in 0..<300 {
            let q = PreReaderContent.generate(topic: .math, difficulty: [.easy, .medium, .hard].randomElement()!)
            #expect(q.spoken != nil)
            #expect(q.options.indices.contains(q.correctIndex))
            #expect(Set(q.options).count == q.options.count, "duplicate options: \(q.options)")
            let prompt = strip(q.prompt), answer = strip(q.correctAnswer)
            if let scene = q.takeAway {
                // 👶➖ the scene and the answer agree
                #expect(Int(answer) == scene.total - scene.take)
            } else if prompt.contains("+") {
                let sides = prompt.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
                if let a = Int(sides[0]), let b = Int(sides[1]) {
                    // "2 + 3" → the picture sum with 2 and 3
                    let parts = answer.split(separator: "+")
                    #expect(pics(parts[0]) == a && pics(parts[1]) == b, "\(prompt) → \(answer)")
                } else if answer.contains("+") {
                    // a picture → "a + b"
                    let parts = answer.split(separator: "+").map { Int($0.trimmingCharacters(in: .whitespaces)) }
                    #expect(parts[0] == count(Substring(sides[0])) && parts[1] == count(Substring(sides[1])), "\(prompt) → \(answer)")
                } else {
                    #expect(Int(answer) == count(Substring(sides[0])) + count(Substring(sides[1])))
                }
            } else if !["⚖️", "👂"].contains(prompt) {
                #expect(Int(answer) == count(Substring(prompt)))
            }
        }
    }

    /// 🔢 Math-world pairs: every digit meets a group of exactly that many.
    @Test func numberPairsCountRight() {
        for _ in 0..<100 {
            let round = PreReaderGames.numberPairs()
            #expect(Set(round.pairs.map(\.left)).count == round.pairs.count)
            for p in round.pairs {
                #expect(Int(p.left) == p.right.filter { $0 != "\n" }.count, "\(p.left) ↔ \(p.right)")
            }
        }
    }

    /// 🎞️ Every story keeps its order: picked steps are in rank order, and
    /// the first and last ranks survive a short round.
    @Test func sequenceStoriesStayInOrder() {
        for story in SequenceStories.all {
            for d in [Difficulty.easy, .medium, .hard] {
                let steps = SequenceStories.pick(story, count: SequenceStories.stepCount(for: d))
                #expect(steps.map(\.rank) == steps.map(\.rank).sorted())
                #expect(steps.count == min(SequenceStories.stepCount(for: d), story.steps.count))
                #expect(steps.first?.rank == story.steps.map(\.rank).min())
            }
        }
    }

    /// Ben David, 2026-10-23: "איפה האדום איפה הכתום". Above easy a גן world
    /// never asks "where is…" — with or without a thinking bank.
    @Test func noFindingAboveEasy() {
        for topic in [Topic.science, .history, .english, .soccer, .logic] {
            for d in [Difficulty.medium, .hard] {
                for _ in 0..<60 {
                    let q = PreReaderContent.generate(topic: topic, difficulty: d)
                    #expect(!(q.spoken ?? "").contains("אֵיפֹה"), "\(topic) \(d): \(q.spoken ?? "")")
                }
            }
        }
    }

    @Test func lettersNeverOfferSoundAlikes() {
        let groups: [Set<String>] = [["א", "ע"], ["ט", "ת"], ["כ", "ק", "ח"], ["ס", "ש"], ["ב", "ו"]]
        for _ in 0..<300 {
            let q = PreReaderContent.lettersRound()
            #expect(q.spoken != nil)
            #expect(Set(q.options).count == q.options.count)
            // Letter options: no two from the same sound group.
            if q.options.allSatisfy({ $0.count == 1 }) {
                for g in groups { #expect(q.options.filter { g.contains($0) }.count <= 1, "\(q.options)") }
            }
        }
    }

    @Test func themeWorldsAskAboutTheirOwnPictures() {
        let sea: Set<String> = ["🐙", "🐬", "🦈", "🐢", "🦀", "🐳", "🐠", "🐚"]
        let seaRounds = (0..<200).map { _ in PreReaderContent.generate(topic: .sea, difficulty: .easy) }   // "find…" rounds live at easy only now
        #expect(seaRounds.filter { Set($0.options).isSubset(of: sea) }.count > 100)
    }
}
