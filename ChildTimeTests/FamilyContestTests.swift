import Foundation
import Testing
@testable import ChildTime

/// 🏆 The weekly family contest (Rani, 2026-10-24): goals follow what each
/// child really did, the jar pays at ⅓ ⅔ and full, the crown goes by percent
/// of your OWN goal, and a week is Sunday → Saturday.
struct FamilyContestTests {
    @Test func goalGrowsAfterAStrongWeek() {
        // "אם ילד עשה שבוע 600 תשובות… שבוע הבא שיהיה יותר"
        #expect(FamilyContest.goal(lastWeek: 600, weekBefore: 500) == 660)
    }

    @Test func aWeakWeekPullsTheGoalDownNotUp() {
        let g = FamilyContest.goal(lastWeek: 200, weekBefore: 600)
        #expect(g == 440)                      // (200 + 600) / 2 × 1.1
        #expect(g < FamilyContest.goal(lastWeek: 600, weekBefore: 500))
    }

    @Test func aNewChildStartsFromTheirDailyAverage() {
        #expect(FamilyContest.goal(lastWeek: 0, weekBefore: 0, recentDailyAverage: 40) == 310)   // 40 × 7 × 1.1
        #expect(FamilyContest.goal(lastWeek: 0, weekBefore: 0) == FamilyContest.minGoal)
    }

    @Test func stagesAreThirdsInRoundTens() {
        #expect(FamilyContest.stages(target: 1200) == [400, 800, 1200])
        #expect(FamilyContest.stages(target: 1110) == [370, 740, 1110])
        #expect(FamilyContest.reached(820, target: 1200) == [0, 1])
        #expect(FamilyContest.reached(1200, target: 1200) == [0, 1, 2])
        #expect(FamilyContest.reached(0, target: 0).isEmpty)
    }

    @Test func theLittleOneCanWin() {
        let big = UUID(), little = UUID()
        let s: [FamilyContest.Standing] = [
            .init(childID: big, goal: 800, done: 480),     // 60%
            .init(childID: little, goal: 150, done: 120),  // 80%
        ]
        #expect(FamilyContest.champions(s) == [little])
        #expect(FamilyContest.endPrize(s[1], all: s, lastWeekDone: 0) == FamilyContest.championPrize)
        #expect(FamilyContest.endPrize(s[0], all: s, lastWeekDone: 0) == 0)
    }

    @Test func goalPlusCrown() {
        let a = UUID(), b = UUID()
        let s: [FamilyContest.Standing] = [.init(childID: a, goal: 100, done: 120), .init(childID: b, goal: 100, done: 100)]
        #expect(FamilyContest.endPrize(s[0], all: s, lastWeekDone: 0) == FamilyContest.goalPrize + FamilyContest.championPrize)
        #expect(FamilyContest.endPrize(s[1], all: s, lastWeekDone: 0) == FamilyContest.goalPrize)
    }

    @Test func nobodyLeadsBeforeAnyAnswer() {
        let s: [FamilyContest.Standing] = [.init(childID: UUID(), goal: 100, done: 0), .init(childID: UUID(), goal: 90, done: 0)]
        #expect(FamilyContest.champions(s).isEmpty)
    }

    @Test func oneChildRacesLastWeek() {
        let me = FamilyContest.Standing(childID: UUID(), goal: 300, done: 250)
        #expect(FamilyContest.endPrize(me, all: [me], lastWeekDone: 200) == FamilyContest.championPrize)
        #expect(FamilyContest.endPrize(me, all: [me], lastWeekDone: 260) == 0)
    }

    @Test func theWeekStartsOnSunday() {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 28; c.hour = 15   // a Wednesday
        let wed = FamilyContest.calendar.date(from: c)!
        #expect(FamilyContest.weekKey(wed) == "2026-10-25")
        #expect(FamilyContest.dayKeys(from: FamilyContest.weekStart(wed)).last == "2026-10-31")
        #expect(FamilyContest.daysLeft(wed) == 4)
    }

    @Test func rollingKeepsOnlyTheWeekJustBefore() {
        let last = ContestRecord(current: .init(week: "2026-10-18", goal: 500, boost: 0, paid: [0]))
        let rolled = last.rolled(to: "2026-10-25", prevKey: "2026-10-18", goal: 550)
        #expect(rolled.prev?.week == "2026-10-18" && rolled.prev?.paid == [0])
        #expect(rolled.current.goal == 550 && rolled.current.paid.isEmpty)
        let stale = ContestRecord(current: .init(week: "2026-10-04", goal: 500, boost: 0, paid: []))
        #expect(stale.rolled(to: "2026-10-25", prevKey: "2026-10-18", goal: 550).prev == nil)
        #expect(rolled.rolled(to: "2026-10-25", prevKey: "2026-10-18", goal: 999) == rolled)
    }

    @Test func recordSurvivesFirestoreShape() {
        let r = ContestRecord(current: .init(week: "2026-10-25", goal: 660, boost: 40, paid: [0, 1]),
                              prev: .init(week: "2026-10-18", goal: 600, boost: 0, paid: [0]), settled: "2026-10-11")
        let back = ContestRecord(r.data.mapValues { v -> Any in
            if let d = v as? [String: Any] { return d.mapValues { ($0 as? Int).map(NSNumber.init(value:)) ?? ($0 as? [Int]).map { $0.map(NSNumber.init(value:)) } ?? $0 } }
            if let i = v as? Int { return NSNumber(value: i) }
            if let a = v as? [Int] { return a.map(NSNumber.init(value:)) }
            return v
        })
        #expect(back == r)
    }
}
