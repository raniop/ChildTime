import XCTest
@testable import ChildTime

/// ז׳–ח׳ (Rani, 2026-09-11: "עד כיתה ח כולל"). Generated questions are only
/// safe in bulk if every one is checked, so these solve them back.
final class MiddleSchoolMathTests: XCTestCase {

    /// Options with the direction isolates and units stripped: "\u{2066}−3\u{2069} ₪" → "−3".
    private func bare(_ s: String) -> String {
        s.replacingOccurrences(of: "\u{2066}", with: "").replacingOccurrences(of: "\u{2069}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: " סמ\"ר", with: "").replacingOccurrences(of: " סמ\"ק", with: "")
            .replacingOccurrences(of: " ס\"מ", with: "").replacingOccurrences(of: " ₪", with: "")
            .replacingOccurrences(of: "°", with: "")
    }
    private func coefficient(_ s: Substring) -> Int { s.isEmpty ? 1 : s == "-" ? -1 : Int(s)! }
    private func int(_ s: String) -> Int? { Int(bare(s).replacingOccurrences(of: "−", with: "-")) }

    private func sample(grade: Int, count: Int = 1500) -> [Question] {
        (0..<count).map { i in
            CurriculumMath.generate(grade: grade, difficulty: [.easy, .medium, .hard][i % 3])
        }
    }

    func testEveryQuestionIsWellFormed() {
        for grade in 7...8 {
            for q in sample(grade: grade) {
                XCTAssertEqual(q.options.count, 4, "\(grade): \(q.prompt)")
                XCTAssertEqual(Set(q.options.map(bare)).count, 4, "duplicate option: \(q.prompt) \(q.options)")
                XCTAssertTrue(q.options.indices.contains(q.correctIndex), q.prompt)
                XCTAssertNotNil(q.skill, "untagged: \(q.prompt)")
                XCTAssertFalse(q.options.contains { bare($0) == "−0" }, "−0 in \(q.prompt)")
                XCTAssertFalse(q.prompt.isEmpty)
                XCTAssertFalse(bare(q.prompt).contains("+ 0 ") || bare(q.prompt).contains("− 0 ") || bare(q.prompt).contains("+ 0)"), "“+ 0” in \(q.prompt)")
                XCTAssertFalse(bare(q.prompt).contains("1x"), "“1x” in \(q.prompt)")
                if let skill = q.skill {
                    XCTAssertNotEqual(SkillCatalog.name(skill), skill, "no Hebrew name for skill \(skill)")
                }
            }
        }
    }

    /// Solve the question from its own prompt and compare with the marked answer.
    func testAnswersAreCorrect() throws {
        var checked = 0
        for q in sample(grade: 7, count: 2500) + sample(grade: 8, count: 2500) {
            let p = bare(q.prompt).replacingOccurrences(of: "−", with: "-")
            let answer = bare(q.correctAnswer).replacingOccurrences(of: "−", with: "-")

            // (a) op (b) = ?
            if let m = p.firstMatch(of: /^\(?(-?\d+)\)? ([+\-×]) \(?(-?\d+)\)? = \?$/) {
                let a = Int(m.1)!, b = Int(m.3)!
                let expected = m.2 == "+" ? a + b : m.2 == "-" ? a - b : a * b
                XCTAssertEqual(Int(answer), expected, q.prompt); checked += 1
            }
            // kx ± c = r  /  x ± c = r
            if let m = p.firstMatch(of: /^(\d*)x ([+\-]) (\d+) = (-?\d+)\n/) {
                let k = coefficient(m.1), c = Int(m.3)! * (m.2 == "+" ? 1 : -1), r = Int(m.4)!
                let x = try XCTUnwrap(Int(answer))
                XCTAssertEqual(k * x + c, r, q.prompt); checked += 1
            }
            // a(x ± b) = r
            if let m = p.firstMatch(of: /^(\d+)\(x(?: ([+\-]) (\d+))?\) = (-?\d+)\n/) {
                let a = Int(m.1)!, b = m.3.map { Int($0)! * (m.2 == "+" ? 1 : -1) } ?? 0, r = Int(m.4)!
                let x = try XCTUnwrap(Int(answer))
                XCTAssertEqual(a * (x + b), r, q.prompt); checked += 1
            }
            // ax ± b = cx ± e
            if let m = p.firstMatch(of: /^(\d*)x(?: ([+\-]) (\d+))? = (\d*)x(?: ([+\-]) (\d+))?\n/) {
                let a = coefficient(m.1), b = m.3.map { Int($0)! * (m.2 == "+" ? 1 : -1) } ?? 0
                let c = coefficient(m.4), e = m.6.map { Int($0)! * (m.5 == "+" ? 1 : -1) } ?? 0
                let x = try XCTUnwrap(Int(answer))
                XCTAssertEqual(a * x + b, c * x + e, q.prompt); checked += 1
            }
            // √n = ?
            if let m = p.firstMatch(of: /^√(\d+) = \?$/) {
                let r = try XCTUnwrap(Int(answer))
                XCTAssertEqual(r * r, Int(m.1)!, q.prompt); checked += 1
            }
            // y = mx ± b, value at x
            if let m = p.firstMatch(of: /y = (-?\d*)x(?: ([+\-]) (\d+))?\n.*x = (-?\d+)\?/) {
                let slope = coefficient(m.1), b = m.3.map { Int($0)! * (m.2 == "+" ? 1 : -1) } ?? 0, x = Int(m.4)!
                XCTAssertEqual(Int(answer), slope * x + b, q.prompt); checked += 1
            }
            // Triangle's third angle
            if let m = p.firstMatch(of: /זָוִית שֶׁל (\d+)° וְזָוִית שֶׁל (\d+)°/) {
                XCTAssertEqual(Int(answer), 180 - Int(m.1)! - Int(m.2)!, q.prompt); checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 1200, "the solver recognised too few prompts — did a prompt format change?")
    }

    /// A ז׳ child used to get the WHOLE passage pool (א׳ stories included) because
    /// no passage window reached past ו׳. Now ז׳ and ח׳ have their own.
    func testReadingFallsBackToNearestGrade() {
        for grade in 7...8 {
            let universe = ReadingContent.universe(for: grade)
            XCTAssertFalse(universe.isEmpty)
            XCTAssertTrue(universe.allSatisfy { $0.gradeWindow.contains(grade) },
                          "grade \(grade) got a passage for \(universe.map(\.gradeWindow))")
            XCTAssertGreaterThanOrEqual(universe.count, 12, "ז׳–ח׳ should each have their own passages")
        }
    }

    /// Campaigns saved before ז׳–ח׳ stored gradeMax 6 for "everyone".
    func testCampaignGradeTop() {
        typealias A = Campaign.Audience
        XCTAssertEqual(A(roles: [], gradeMin: 0, gradeMax: 6, premium: "any", topics: []).effectiveMax, Int.max)
        XCTAssertEqual(A(roles: [], gradeMin: 0, gradeMax: 6, premium: "any", topics: [], gradeScale: 8).effectiveMax, 6)
        XCTAssertEqual(A(roles: [], gradeMin: 0, gradeMax: 8, premium: "any", topics: [], gradeScale: 8).effectiveMax, Int.max)
    }
}
