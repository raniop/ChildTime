import XCTest
@testable import ChildTime

/// 🌍 Questions follow the app language: Hebrew keeps its whole catalog, and a
/// world with no questions in another language is not offered there.
final class ContentLanguageTests: XCTestCase {
    override func tearDown() { LanguageStore.shared.setForTesting(.he); super.tearDown() }

    func testHebrewKeepsEveryWorld() {
        LanguageStore.shared.setForTesting(.he)
        for topic in Topic.allCases {
            XCTAssertTrue(ContentAvailability.hasContent(topic), "\(topic) must stay available in Hebrew")
        }
        XCTAssertEqual(QuestionBanks.bank(for: .animals)?.count, QuestionBanks.builtInBank(for: .animals).map { $0.count + RemoteQuestionBank.shared.questions(for: .animals, in: .he).count })
    }

    func testEnglishNeverServesHebrew() {
        LanguageStore.shared.setForTesting(.en)
        XCTAssertTrue(ContentAvailability.hasContent(.math), "math is generated in every language")
        XCTAssertFalse(ContentAvailability.hasContent(.israel), "no English content for Israel-only worlds")
        XCTAssertFalse(ContentAvailability.hasContent(.hebrew))
        let hebrew = try! NSRegularExpression(pattern: "[\\u0590-\\u05FF]")
        for topic in Topic.allCases where topic != .math && topic != .reading {
            for q in QuestionBanks.bank(for: topic) ?? [] {
                let text = ([q.prompt, q.correctAnswer] + q.distractors).joined(separator: " ")
                XCTAssertNil(hebrew.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), "Hebrew in English \(topic): \(q.prompt)")
            }
        }
    }
}
