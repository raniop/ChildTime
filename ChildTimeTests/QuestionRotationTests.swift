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
            for grade in 1...8 {
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
            for grade in 1...8 where bank.filter({ $0.grades.contains(grade) }).count < 15 {
                gaps.append("\(topic.rawValue) כיתה \(grade): \(bank.filter { $0.grades.contains(grade) }.count)")
            }
        }
        print("📋 grade-tag gaps (content backlog):\n" + gaps.joined(separator: "\n"))
    }
}

// MARK: - Coverage export

extension QuestionRotationTests {

    /// Writes the real per-topic / per-grade counts to `docs/admin/`, where the
    /// founder dashboard renders them as a matrix. Run with
    /// `EXPORT_COVERAGE=1` after touching any bank:
    ///   xcodebuild test -only-testing:ChildTimeTests/QuestionRotationTests/testExportCoverage
    func testExportCoverage() throws {
        guard ProcessInfo.processInfo.environment["EXPORT_COVERAGE"] == "1",
              let out = ProcessInfo.processInfo.environment["COVERAGE_OUT"] else {
            throw XCTSkip("set EXPORT_COVERAGE=1 and COVERAGE_OUT=<path> to refresh the dashboard data")
        }
        var topicsOut: [[String: Any]] = []
        for topic in topics {
            guard let bank = QuestionBanks.bank(for: topic), !bank.isEmpty else { continue }
            var grades: [[String: Any]] = []
            for g in 0...8 {
                grades.append([
                    "grade": g,
                    "tagged": bank.filter { $0.grades.contains(g) }.count,
                    "pool": QuestionGenerator.effectivePool(topic: topic, grade: g).count,
                ])
            }
            var tiers: [String: Int] = [:]
            for q in bank { tiers[q.difficulty.rawValue, default: 0] += 1 }
            topicsOut.append([
                "topic": topic.rawValue,
                "label": topic.displayName,
                "emoji": topic.emoji,
                "total": bank.count,
                "tiers": tiers,
                "grades": grades,
            ])
        }
        let payload: [String: Any] = [
            "generatedAt": ISO8601DateFormatter().string(from: Date()),
            "minGradePool": QuestionGenerator.minGradePool,
            "topics": topicsOut,
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: out))
        print("📊 coverage written to \(out)")
    }
}

/// Rani, 2026-10-02, watching Dan (כיתה ב׳) play logic: "נראה לי היו שאלות קלות
/// מידי". ב׳ logic was 87 easy / 83 medium / 22 hard, so a child doing well ran
/// through the hard ones and walked DOWN hard → medium → easy to "מה בא אחרי 5?".
final class StretchTierTests: XCTestCase {

    override func setUp() {
        super.setUp()
        QuestionMemory.shared.clear()
        LanguageStore.shared.setForTesting(.he)
    }

    /// Asking for HARD at a grade with no hard items borrows hard ones from the
    /// grade above instead of handing out nothing hard at all.
    func testHardLogicAtGradeTwoBorrowsFromGradeThree() {
        let own = QuestionGenerator.effectivePool(topic: .logic, grade: 2)
        let stretch = QuestionGenerator.stretchItems(topic: .logic, difficulty: .hard, grade: 2, pool: own)
        XCTAssertFalse(stretch.isEmpty, "no hard logic for a strong 2nd grader to move up to")
        XCTAssertTrue(stretch.allSatisfy { $0.difficulty == .hard && $0.grades.contains(3) })
        // …and the picker, asked for hard, now actually serves hard.
        QuestionMemory.shared.beginSession()
        for _ in 0..<8 {
            let q = QuestionMemory.shared.pickFresh(own + stretch, for: .logic, target: .hard)
            XCTAssertEqual(q?.difficulty, .hard, "asked for hard, got \(String(describing: q?.difficulty))")
        }
    }

    /// Easy questions never pull a stretch — the stretch is for children doing well.
    func testEasyNeverStretches() {
        let own = QuestionGenerator.effectivePool(topic: .logic, grade: 2)
        XCTAssertTrue(QuestionGenerator.stretchItems(topic: .logic, difficulty: .easy, grade: 2, pool: own).isEmpty)
    }

    /// The גן-level counting items no longer reach a 2nd grader.
    func testPreschoolCountingIsNotServedToGradeTwo() {
        let pool = QuestionGenerator.effectivePool(topic: .logic, grade: 2)
        let prompts = pool.map { $0.prompt }
        XCTAssertFalse(prompts.contains("מָה בָּא אַחֲרֵי הַמִּסְפָּר 5?"))
        XCTAssertFalse(prompts.contains("מָה הַמִּסְפָּר הַבָּא? 1, 2, 3, ?"))
        // …but a 1st grader still has them.
        let first = QuestionGenerator.effectivePool(topic: .logic, grade: 1).map { $0.prompt }
        XCTAssertTrue(first.contains("מָה בָּא אַחֲרֵי הַמִּסְפָּר 5?"))
    }

    /// No bonus (7-minute) question may carry its own explanation in the answer.
    func testNoBonusAnswerGivesItselfAway() {
        for topic: Topic in [.english, .hebrew, .logic, .science, .history, .geography, .money] {
            for item in BonusQuestionBank.pool(for: topic) {
                XCTAssertFalse(item.correctAnswer.contains("—"),
                               "\(topic.rawValue): bonus answer explains itself — \(item.correctAnswer)")
            }
        }
    }
}

/// "אֵיךְ אוֹמְרִים הַרְבֵּה דֶּלֶת?" offered "דְּלָתוֹת" (right) and "דֶּלֶתוֹת" (wrong) —
/// a plural question that turned into a niqqud quiz (2026-10-02). In a PLURAL
/// question no wrong option may spell the right answer with the same letters.
/// Grammar questions are left alone on purpose: in סמיכות, בניינים and gender
/// (בֵּית / בַּיִת, פֻּעַל / פִּעֵל, לָךְ / לְךָ) the niqqud IS the lesson.
final class LookAlikeOptionTests: XCTestCase {
    private func letters(_ s: String) -> String {
        String(String.UnicodeScalarView(s.unicodeScalars.filter { !(0x0591...0x05C7).contains($0.value) }))
    }

    func testPluralQuestionsHaveNoLookAlikeOptions() {
        LanguageStore.shared.setForTesting(.he)
        var bad: [String] = []
        let items = (QuestionBanks.builtInBank(for: .hebrew) ?? []) + BonusQuestionBank.pool(for: .hebrew)   // the code, not the device's cloud cache
        for q in items {
            let p = letters(q.prompt)
            guard p.contains("הרבה") || p.contains("הרבים") || p.contains("צורת הרבים") else { continue }
            for d in q.distractors where letters(d) == letters(q.correctAnswer) {
                bad.append("\(p.prefix(40)): \(q.correctAnswer) ≈ \(d)")
            }
        }
        XCTAssertTrue(bad.isEmpty, "look-alike plural options:\n" + bad.joined(separator: "\n"))
    }
}
