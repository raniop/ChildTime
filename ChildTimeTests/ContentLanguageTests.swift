import XCTest
@testable import ChildTime

/// 🌍 Questions follow the app language: Hebrew keeps its whole catalog, and a
/// world with no questions in another language is not offered there.
final class ContentLanguageTests: XCTestCase {
    override func tearDown() { LanguageStore.shared.setForTesting(.he); super.tearDown() }

    func testHebrewKeepsEveryWorld() {
        LanguageStore.shared.setForTesting(.he)
        // 🎊 .holidays is the Arabic audience's own holidays, not a translation of
        // anything, and is hidden everywhere else INCLUDING Hebrew by design.
        for topic in Topic.allCases where topic != .holidays {
            XCTAssertTrue(ContentAvailability.hasContent(topic), "\(topic) must stay available in Hebrew")
        }
        XCTAssertFalse(ContentAvailability.hasContent(.holidays), "holidays is Arabic-only")
        XCTAssertTrue(ContentAvailability.hasContent(.holidays, in: .ar))
        XCTAssertEqual(QuestionBanks.bank(for: .animals)?.count, QuestionBanks.builtInBank(for: .animals).map { $0.count + RemoteQuestionBank.shared.questions(for: .animals, in: .he).count })
    }

    /// 🖤 The black kid home (2026-10-04).
    ///
    /// `hasContent` is Hebrew's no-op and everyone else's full bank assembly, and
    /// the kid's home asks it for every pack, inside a filter, inside the grid's
    /// `ForEach`. One render rebuilt hundreds of banks on the main thread, so in
    /// English the first frame never arrived and an English-speaking child opened
    /// Tofy to a black screen (Hebrew drew instantly — it never does the work).
    ///
    /// This is the shape of one render, repeated. It has to stay cheap in EVERY
    /// language: before the cache this took minutes, now it is milliseconds.
    func testAvailabilityStaysCheapInEveryLanguage() {
        let packTopics = QuestionPacks.all.map(\.topic)
        let started = Date()
        for _ in 0..<200 {
            for language in AppLanguage.allCases {
                for topic in packTopics { _ = ContentAvailability.hasContent(topic, in: language) }
                for topic in Topic.allCases { _ = ContentAvailability.hasContent(topic, in: language) }
            }
        }
        let elapsed = Date().timeIntervalSince(started)
        XCTAssertLessThan(elapsed, 2.0, "resolving the kid home's content took \(elapsed)s — the home will not draw its first frame")
    }

    /// Remembering an answer must not change it, and new cloud questions must
    /// still get through (the sync clears the cache).
    func testCachedAvailabilityMatchesAFreshAnswer() {
        var before: [String: Bool] = [:]
        for language in AppLanguage.allCases {
            for topic in Topic.allCases {
                before["\(topic.rawValue)|\(language.rawValue)"] = ContentAvailability.hasContent(topic, in: language)
            }
        }
        ContentCache.invalidate()
        for language in AppLanguage.allCases {
            for topic in Topic.allCases {
                let key = "\(topic.rawValue)|\(language.rawValue)"
                XCTAssertEqual(before[key], ContentAvailability.hasContent(topic, in: language), "\(key) changed after the cache was cleared")
            }
        }
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
