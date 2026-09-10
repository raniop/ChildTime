import XCTest
@testable import ChildTime

/// Rani, 2026-09-11: "עולם הכדורגל … שהוא יוצא ונכנס הן חוזרות על עצמן כל הזמן!"
///
/// These pin down the two promises the question rotation makes:
/// 1. a child never sees the same question twice in a sitting, and
/// 2. leaving the world and coming back does NOT start the rotation over —
///    the memory is supposed to survive the session.
/// They run over every real topic bank, not just soccer, because the same
/// picker serves all of them.
final class QuestionRotationTests: XCTestCase {

    private let topics: [Topic] = [
        .soccer, .dinosaurs, .space, .animals, .sea, .gifted,
        .food, .israel, .music, .body, .vehicles, .flags, .tishrei,
        .english, .hebrew, .logic, .science, .history, .geography, .money,
    ]

    override func setUp() {
        super.setUp()
        QuestionMemory.shared.clear()
    }

    /// No repeats inside one sitting, for any topic.
    func testNoRepeatsWithinASession() {
        for topic in topics {
            guard let bank = QuestionBanks.bank(for: topic), bank.count >= 10 else { continue }
            QuestionMemory.shared.clear()
            QuestionMemory.shared.beginSession()
            var seen = Set<String>()
            for _ in 0..<min(10, bank.count) {
                guard let q = QuestionMemory.shared.pickFresh(bank, for: topic, target: .medium) else { continue }
                let key = "\(q.prompt)|\(q.correctAnswer)"
                XCTAssertFalse(seen.contains(key),
                               "\(topic.rawValue): repeated \"\(q.prompt.prefix(30))\" inside one session")
                seen.insert(key)
            }
        }
    }

    /// The reported bug: leave the world, come back, and the SAME questions
    /// arrive again. A new session resets only the in-session set; the stored
    /// recency window must keep them out.
    func testLeavingAndReturningDoesNotRepeat() {
        for topic in topics {
            guard let bank = QuestionBanks.bank(for: topic), bank.count >= 20 else { continue }
            QuestionMemory.shared.clear()

            var first = Set<String>()
            QuestionMemory.shared.beginSession()
            for _ in 0..<8 {
                guard let q = QuestionMemory.shared.pickFresh(bank, for: topic, target: .medium) else { continue }
                first.insert("\(q.prompt)|\(q.correctAnswer)")
            }

            // …child leaves the world and opens it again.
            QuestionMemory.shared.beginSession()
            var repeats = 0
            for _ in 0..<8 {
                guard let q = QuestionMemory.shared.pickFresh(bank, for: topic, target: .medium) else { continue }
                if first.contains("\(q.prompt)|\(q.correctAnswer)") { repeats += 1 }
            }
            XCTAssertEqual(repeats, 0,
                           "\(topic.rawValue): \(repeats)/8 questions came back after re-entering the world")
        }
    }

    /// A grade-filtered pool must still be deep enough to rotate. A pool that
    /// collapses to a handful of items is why a child sees the same questions
    /// however good the picker is.
    func testGradePoolsAreDeepEnough() {
        var thin: [String] = []
        for topic in topics {
            guard let bank = QuestionBanks.bank(for: topic), !bank.isEmpty else { continue }
            for grade in 1...6 {
                // The pool the child ACTUALLY gets, after the nearest-grade
                // top-up — not the raw tag count.
                let pool = QuestionGenerator.effectivePool(topic: topic, grade: grade)
                let want = min(QuestionGenerator.minGradePool, bank.count)
                if pool.count < want {
                    thin.append("\(topic.rawValue) כיתה \(grade): \(pool.count)/\(want)")
                }
            }
        }
        XCTAssertTrue(thin.isEmpty, "pools too thin to rotate:\n" + thin.joined(separator: "\n"))
    }

    /// The tag coverage itself, reported for the content backlog. Not a failure —
    /// the top-up keeps these playable — but a grade with no items of its own is
    /// a grade the curriculum promise is not really keeping.
    func testReportGradeTagCoverage() {
        var gaps: [String] = []
        for topic in topics {
            guard let bank = QuestionBanks.bank(for: topic), !bank.isEmpty else { continue }
            for grade in 1...6 where bank.filter({ $0.grades.contains(grade) }).count < 15 {
                gaps.append("\(topic.rawValue) כיתה \(grade): \(bank.filter { $0.grades.contains(grade) }.count)")
            }
        }
        print("📋 grade-tag gaps (content backlog):\n" + gaps.joined(separator: "\n"))
    }
}
