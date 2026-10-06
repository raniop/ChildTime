//
//  QuietHoursTests.swift
//  ChildTimeTests
//
//  🏫🌙 School time and bedtime (Rani, 2026-10-06). The schedule decides when
//  minutes may not open; the close-at-start path decides how much comes back.
//  Both run on a fixed calendar (Asia/Jerusalem) so the tests read like a week.
//

import Testing
import Foundation
@testable import ChildTime

@Suite struct QuietHoursSchedule {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
        return c
    }()

    /// 2026-10-06 is a Tuesday; the 9th a Friday; the 10th a Saturday.
    func at(_ day: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: m))!
    }

    var both: QuietHours { QuietHours(school: QuietHours.schoolDefault, bedtime: QuietHours.bedtimeDefault) }

    @Test func schoolHoursOnASchoolDay() {
        let q = both
        #expect(q.active(at: at(6, 7, 59), calendar: cal) == nil)
        let s = q.active(at: at(6, 8, 0), calendar: cal)
        #expect(s?.kind == .school)
        #expect(s?.end == at(6, 13, 30))
        #expect(q.active(at: at(6, 13, 30), calendar: cal) == nil)
    }

    @Test func fridayEndsEarlyAndSaturdayIsFree() {
        let q = both
        #expect(q.active(at: at(9, 11, 59), calendar: cal)?.end == at(9, 12, 0))
        #expect(q.active(at: at(9, 12, 30), calendar: cal) == nil)
        #expect(q.active(at: at(10, 10, 0), calendar: cal) == nil)
    }

    @Test func bedtimeCrossesMidnight() {
        let q = both
        #expect(q.active(at: at(6, 20, 29), calendar: cal) == nil)
        let night = q.active(at: at(6, 23, 0), calendar: cal)
        #expect(night?.kind == .bedtime)
        #expect(night?.end == at(7, 7, 0))
        // After midnight the window still belongs to the evening it started.
        #expect(q.active(at: at(7, 3, 0), calendar: cal)?.end == at(7, 7, 0))
        #expect(q.active(at: at(7, 7, 0), calendar: cal) == nil)
    }

    @Test func bedtimeOnlyOnChosenNights() {
        var bed = QuietHours.bedtimeDefault
        bed.days = [1, 2, 3, 4, 5]          // Sunday–Thursday nights
        let q = QuietHours(bedtime: bed)
        #expect(q.active(at: at(6, 22, 0), calendar: cal) != nil)    // Tuesday night
        #expect(q.active(at: at(9, 22, 0), calendar: cal) == nil)    // Friday night
        #expect(q.active(at: at(10, 2, 0), calendar: cal) == nil)    // Saturday 02:00 (Friday's night)
    }

    @Test func noSchoolTodayAndVacation() {
        var q = both
        q.schoolOffDay = QuietHours.dayKey(at(6, 9, 0), calendar: cal)
        #expect(q.active(at: at(6, 9, 0), calendar: cal) == nil)
        #expect(q.active(at: at(7, 9, 0), calendar: cal)?.kind == .school)   // tomorrow as usual
        #expect(q.active(at: at(6, 21, 0), calendar: cal)?.kind == .bedtime) // bedtime untouched
        q.schoolOffDay = nil
        q.schoolPaused = true
        #expect(q.active(at: at(7, 9, 0), calendar: cal) == nil)
    }

    @Test func backToBackWindowsReadAsOne() {
        var school = QuietHours.schoolDefault
        school.start = 7 * 60                // school from 07:00, bedtime until 07:00
        let q = QuietHours(school: school, bedtime: QuietHours.bedtimeDefault)
        let o = q.active(at: at(6, 6, 0), calendar: cal)
        #expect(o?.kind == .bedtime)
        #expect(o?.end == at(6, 13, 30))     // no seam of play at 07:00
    }

    @Test func secondsUntilQuietCapsAWindow() {
        let q = both
        #expect(q.secondsUntilQuiet(from: at(6, 20, 10), calendar: cal) == 20 * 60)
        #expect(q.secondsUntilQuiet(from: at(6, 21, 0), calendar: cal) == 0)
        #expect(q.nextStart(after: at(6, 13, 30), calendar: cal) == at(6, 20, 30))
    }

    @Test func offWindowsNeverBite() {
        var q = both
        q.school?.enabled = false
        q.bedtime?.enabled = false
        #expect(q.isEmpty)
        #expect(q.active(at: at(6, 9, 0), calendar: cal) == nil)
        #expect(QuietHours().nextStart(after: at(6, 9, 0), calendar: cal) == nil)
    }

    @Test func survivesTheRecordRoundTrip() throws {
        var p = Profile(name: "נועה")
        p.quietHours = both
        let record = ChildRecord(profile: p, householdID: "hh")
        let back = try #require(record.toProfile())
        #expect(back.quietHours == both)
        // …and a profile stored before quiet hours existed decodes to nil.
        let data = try JSONEncoder().encode(Profile(name: "דן"))
        #expect(try JSONDecoder().decode(Profile.self, from: data).quietHours == nil)
    }
}

// Nested in the serialized economy suite: drives `ProgressStore.shared`.
extension MiniGameEconomy {

@MainActor
@Suite struct QuietHoursClose {
    private func fresh() -> ProgressStore {
        ProgressStore.shared.resetAll()
        if ProgressStore.shared.isUnlocked { ProgressStore.shared.endUnlock() }
        return ProgressStore.shared
    }

    @Test func earnedWindowGivesBackWhatWasLeftAtTheStart() {
        let p = fresh()
        let before = p.earnedSecondsAvailable + p.pendingSecondsCarry
        p.startUnlock(minutes: 30)
        // Bedtime began 10 minutes in — even if the app only noticed later.
        let cut = Date().addingTimeInterval(10 * 60)
        #expect(p.closeForQuietTime(at: cut))
        #expect(!p.isUnlocked)
        let back = p.earnedSecondsAvailable + p.pendingSecondsCarry - before
        #expect(abs(back - 20 * 60) <= 1)
    }

    @Test func aLateNoticeStillRefundsAsOfTheStart() {
        let p = fresh()
        let before = p.earnedSecondsAvailable + p.pendingSecondsCarry
        p.startUnlock(minutes: 5)
        // The window would have run out long before the app woke — the cut
        // at minute 2 still owes the last 3.
        #expect(p.closeForQuietTime(at: Date().addingTimeInterval(2 * 60)))
        let back = p.earnedSecondsAvailable + p.pendingSecondsCarry - before
        #expect(abs(back - 3 * 60) <= 1)
    }

    @Test func giftWindowGoesBackToTheGiftPocket() {
        let p = fresh()
        let before = p.giftSecondsAvailable
        p.startUnlock(minutes: 10, manual: true, leaseKind: "gift")
        #expect(p.closeForQuietTime(at: Date().addingTimeInterval(4 * 60)))
        #expect(!p.isUnlocked)
        #expect(abs(p.giftSecondsAvailable - before - 6 * 60) <= 1)
    }

    @Test func theParentsOwnOpenKeepsRunning() {
        let p = fresh()
        p.startUnlock(minutes: 15, manual: true)       // kind "grant"
        #expect(!p.closeForQuietTime(at: Date()))
        #expect(p.isUnlocked)
        p.endUnlock()
    }

    @Test func nothingOpenIsANoOp() {
        let p = fresh()
        #expect(!p.closeForQuietTime(at: Date()))
    }
}

}
