import Testing
@testable import ChildTime

/// 👶 גן questions (Ben David, 2026-10-09): picture math is right, letters never
/// put two same-sounding letters side by side, and each theme world asks about
/// its own pictures.
@MainActor
struct PreReaderContentTests {
    @Test func pictureMathIsRight() {
        for _ in 0..<300 {
            let q = PreReaderContent.generate(topic: .math)
            #expect(q.spoken != nil)
            #expect(q.options.indices.contains(q.correctIndex))
            #expect(Set(q.options).count == q.options.count, "duplicate options: \(q.options)")
            let count = { (s: Substring) in s.split(separator: " ").count }
            if q.prompt.contains("➕") {
                let sides = q.prompt.split(separator: "➕")
                #expect(Int(q.correctAnswer) == count(sides[0]) + count(sides[1]))
            } else if q.prompt.contains("➖") {
                let sides = q.prompt.split(separator: "➖")
                #expect(Int(q.correctAnswer) == count(sides[0]) - count(sides[1]))
            } else if !["⚖️", "👂"].contains(q.prompt) {
                #expect(Int(q.correctAnswer) == count(Substring(q.prompt)))
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
        let seaRounds = (0..<200).map { _ in PreReaderContent.generate(topic: .sea) }
        #expect(seaRounds.filter { Set($0.options).isSubset(of: sea) }.count > 100)
    }
}
