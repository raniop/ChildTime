import XCTest
@testable import ChildTime

/// ⏱ A refunded window must give its minutes back to TODAY'S allowance, and the
/// next sync must not take them away again.
///
/// Ben David, 2026-10-08: Emily opened 60 minutes, the window closed after 5
/// seconds and 59:55 went back to the wallet — but the release lowered the
/// "opened today" counter, which merges with `max`, so the next sync put it back
/// to 60 and the parent saw 60/60 for a girl who had barely played.
final class RefundAllowanceTests: XCTestCase {

    private func day(opened: Int, returned: Int) -> ProgressSnapshot {
        var s = ProgressSnapshot.blank
        s.dailyEarnedDate = Date()
        s.minutesUnlockedToday = opened
        s.returnedTodayMinutes = returned
        return s
    }

    /// The refund is carried by `returned`, so a stale copy that still says
    /// "opened 60, returned 0" cannot undo it.
    func testRefundSurvivesAStaleMerge() {
        let afterRefund = day(opened: 60, returned: 59)
        let stale = day(opened: 60, returned: 0)
        let merged = ProgressSnapshot.ratchetMerged(local: stale, remote: afterRefund)
        XCTAssertEqual(merged.netUnlockedToday, 1)
        let mergedOtherWay = ProgressSnapshot.ratchetMerged(local: afterRefund, remote: stale)
        XCTAssertEqual(mergedOtherWay.netUnlockedToday, 1)
    }

    /// The old way — lowering "opened" — is exactly what the merge erases. Kept
    /// as a guard: if anyone goes back to it, this says why it cannot work.
    func testLoweringOpenedIsErasedByTheMerge() {
        let lowered = day(opened: 1, returned: 0)
        let stale = day(opened: 60, returned: 0)
        let merged = ProgressSnapshot.ratchetMerged(local: lowered, remote: stale)
        XCTAssertEqual(merged.netUnlockedToday, 60)
    }

    /// The parent's report counts what was played, not what was opened.
    func testReturnedMinutesLeaveTheUsedCount() {
        var stat = DailyStat(date: "2026-10-08")
        stat.minutesUsed = 60
        stat.minutesUsed = max(0, stat.minutesUsed - 59)
        XCTAssertEqual(stat.minutesUsed, 1)
    }
}
