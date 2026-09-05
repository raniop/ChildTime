import Testing
import Foundation
@testable import ChildTime

// MARK: - 📊 Child report engine
//
// The parent report is pure functions over `DailyStat` history. These pin the
// thresholds that keep it honest: never label a child off two misses, never call
// noise a trend, always name the specific skill when one is known.

@MainActor
@Suite("Child report")
struct ChildReportTests {

    private func key(daysAgo: Int) -> String {
        LearningHistoryStore.dayKey(Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
    }
    private func day(_ daysAgo: Int, _ topics: [(Topic, Int, Int, [String: (Int, Int)])],
                     earned: Int = 0, used: Int = 0) -> DailyStat {
        var d = DailyStat(date: key(daysAgo: daysAgo))
        d.minutesEarned = earned; d.minutesUsed = used
        for (t, a, c, skills) in topics {
            var td = DailyStat.TopicDay(answered: a, correct: c, responseMsTotal: 0)
            if !skills.isEmpty {
                td.perSkill = skills.mapValues { DailyStat.SkillDay(answered: $0.0, correct: $0.1) }
            }
            d.perTopic[t.rawValue] = td
            d.questionsAnswered += a; d.correct += c; d.wrong += a - c
        }
        return d
    }
    private func engine(_ history: [DailyStat]) -> InsightsEngine {
        InsightsEngine(history: history,
                       profile: LearningProfile(snapshot: .blank, enabledTopics: Set(Topic.allCases), age: .preK))
    }

    @Test("topics come best-first and a wide gap is called out with the exact skill")
    func gapInsightNamesTheSkill() {
        let e = engine([day(0, [
            (.money, 12, 12, [:]),
            (.math, 18, 7, ["mul": (6, 5), "fractions": (9, 2), "addSub": (3, 3)]),
        ])])
        let topics = e.topicReports(.today)
        #expect(topics.first?.topic == .money)
        #expect(topics.last?.topic == .math)
        #expect(topics.last?.verdict == .weak)

        let skills = e.skillReports(.math, .today)
        #expect(skills.first?.key == "fractions")           // weakest first
        #expect(skills.first?.name == SkillCatalog.name("fractions"))

        let i = e.dailyInsight(name: "יואב", isGirl: false, period: .today)
        #expect(i?.emoji == "💡")
        #expect(i?.body.contains(SkillCatalog.name("fractions")) == true)
        #expect(i?.recommendation != nil)                   // always ends in something to do
    }

    @Test("a child is never labelled off a handful of answers")
    func tooFewIsNotAVerdict() {
        let e = engine([day(0, [(.logic, 4, 1, [:])])])
        #expect(e.topicReports(.today).first?.verdict == .tooFew)
        #expect(e.toPractice(.today).isEmpty)               // 25% on 4 answers → say nothing
        #expect(e.skillReports(.math, .today).isEmpty)
    }

    @Test("a trend needs enough answers in BOTH periods")
    func deltasIgnoreNoise() {
        // This week: strong. Last week: only 3 answers → no delta may be claimed.
        let e = engine([day(1, [(.geography, 20, 18, [:])]),
                        day(9, [(.geography, 3, 1, [:])])])
        #expect(e.topicDeltas(.week).isEmpty)
        #expect(e.overallDelta(.week) == nil)

        // With a real prior sample the improvement shows, in percentage points.
        let e2 = engine([day(1, [(.geography, 20, 18, [:])]),
                         day(9, [(.geography, 20, 12, [:])])])
        let d = e2.topicDeltas(.week).first
        #expect(d?.topic == .geography)
        #expect(abs((d?.deltaPoints ?? 0) - 30) < 0.01)
        #expect(e2.dailyInsight(name: "נועה", isGirl: true, period: .week)?.emoji == "🌟")
    }

    @Test("mastered and to-practise name skills when they exist, topics otherwise")
    func masteryLists() {
        let e = engine([day(0, [
            (.hebrew, 10, 10, [:]),                                           // whole topic mastered
            (.math, 20, 9, ["mul": (8, 8), "fractions": (12, 1)]),           // one skill strong, one weak
        ])])
        let done = e.mastered(.today).map(\.name)
        let todo = e.toPractice(.today).map(\.name)
        #expect(done.contains(Topic.hebrew.displayName))
        #expect(done.contains(SkillCatalog.name("mul")))
        #expect(todo.contains(SkillCatalog.name("fractions")))
        #expect(!todo.contains(SkillCatalog.name("mul")))
    }

    @Test("day points are a real calendar: zero-filled, oldest first, today last")
    func dayPointsAreACalendar() {
        let e = engine([day(0, [(.math, 5, 4, [:])], earned: 12, used: 7),
                        day(3, [(.math, 8, 8, [:])], earned: 20, used: 20)])
        let pts = e.dayPoints(days: 7)
        #expect(pts.count == 7)
        #expect(pts.last?.date == key(daysAgo: 0))
        #expect(pts.first?.date == key(daysAgo: 6))
        #expect(pts.last?.questions == 5)
        #expect(pts.last?.earned == 12 && pts.last?.used == 7)
        #expect(pts[3].questions == 8)
        #expect(pts[1].questions == 0 && pts[1].accuracy == 0)   // an empty day is present, not skipped
    }

    @Test("an unknown skill key still shows something readable")
    func skillFallback() {
        #expect(SkillCatalog.name("nope") == "nope")
        #expect(!SkillCatalog.name("fractions").isEmpty)
    }
}
