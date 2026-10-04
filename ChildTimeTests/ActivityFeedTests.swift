import XCTest
@testable import ChildTime

/// 🔔 The parent's activity centre: the merge, the day grouping, the rows the
/// feed derives from state the app already holds, the unread mark — and the two
/// rules this feature must not break (no niqqud in parent copy; every push type
/// the backend sends has a row to land in).
@MainActor
final class ActivityFeedTests: XCTestCase {

    override func setUp() {
        super.setUp()
        ActivityLog.reset()
        LanguageStore.shared.setForTesting(.he)
    }

    override func tearDown() {
        ActivityLog.reset()
        LanguageStore.shared.setForTesting(.he)
        super.tearDown()
    }

    // MARK: - Parent copy has NO niqqud

    /// Every line the feed can show is parent-facing, so none of it may carry
    /// vowel points — and none may come back empty either.
    func testNoNiqqudInAnyLine() {
        // Every Hebrew vowel point / dagesh / shin-dot / qamats-qatan.
        let niqqud = CharacterSet(charactersIn:
            "\u{05B0}\u{05B1}\u{05B2}\u{05B3}\u{05B4}\u{05B5}\u{05B6}\u{05B7}"
            + "\u{05B8}\u{05B9}\u{05BA}\u{05BB}\u{05BC}\u{05C1}\u{05C2}\u{05C7}")
        for kind in ActivityKind.allCases {
            for line in [kind.line(), kind.line(number: 7, value: "מדע")] {
                XCTAssertFalse(line.isEmpty, "\(kind) has no line")
                XCTAssertNil(line.rangeOfCharacter(from: niqqud),
                             "\(kind) carries niqqud in parent-facing copy: \(line)")
            }
        }
        for status in [ActivityStatus.sending, .reachedCloud, .deviceConfirmed, .failed] {
            XCTAssertNil(status.label.rangeOfCharacter(from: niqqud), status.label)
        }
    }

    /// A number or a value actually reaches the line (a silent 0 would read
    /// "רצף של 0 תשובות נכונות").
    func testNumbersAndValuesReachTheLine() {
        XCTAssertTrue(ActivityKind.streak.line(number: 12).contains("12"))
        XCTAssertTrue(ActivityKind.giftSent.line(number: 15).contains("15"))
        XCTAssertTrue(ActivityKind.levelUp.line(number: 7).contains("7"))
        XCTAssertTrue(ActivityKind.worldUnlocked.line(value: "ממלכת המספרים").contains("ממלכת המספרים"))
        // …and with nothing to say, the line still stands on its own.
        XCTAssertFalse(ActivityKind.worldUnlocked.line().contains(":"))
    }

    // MARK: - Every push the backend sends has somewhere to land

    func testEveryBackendPushTypeMaps() {
        // The `type`/`kind` strings functions/index.js attaches to parent pushes.
        let sent = ["sessionStart", "sessionEnd", "milestone", "streak", "wheelWin",
                    "discovery", "assistRequest", "parentHelp", "screenTimeStart",
                    "screenTimeEnd", "screenTimeMoved", "parentGateOpened",
                    "playPINForgot", "giftOpenFailed", "levelUp", "worldUnlocked",
                    "personalBest", "choreApproval", "support-chat", "weeklyReport",
                    "premium-request", "pack-request", "pass-ending", "gift-start",
                    "gift-day", "campaign", "retention-notice", "dupAlert",
                    "timeTransferParent", "timeTransferSeller", "childLinkRequest",
                    "childLinkApproved"]
        for type in sent {
            XCTAssertNotNil(ActivityKind.fromPushType(type), "no feed row for push type \(type)")
        }
        // Anything the server learns before the app does still shows up.
        XCTAssertNil(ActivityKind.fromPushType("something-new-in-2027"))
        ActivityLog.recordNotification(type: "something-new-in-2027", identifier: "x",
                                       body: "טקסט ההתראה", at: Date())
        XCTAssertEqual(ActivityLog.items.first?.kind, .push)
        XCTAssertEqual(ActivityLog.items.first?.detail, "טקסט ההתראה")
    }

    // MARK: - The merge

    func testMergeSortsDedupesAndCaps() {
        let now = Date()
        let raw = [
            ActivityItem(at: now.addingTimeInterval(-600), kind: .streak, childID: "a", number: 5),
            ActivityItem(at: now, kind: .giftSent, childID: "a", number: 10),
            // The same happening, recorded twice within three minutes — once by
            // this device when the push arrived, once by the server when it sent.
            ActivityItem(id: "other", at: now.addingTimeInterval(-660), kind: .streak,
                         childID: "a", value: "מדע"),
            // Same kind, DIFFERENT child — two rows, not one.
            ActivityItem(at: now.addingTimeInterval(-620), kind: .streak, childID: "b", number: 5),
        ]
        let merged = ActivityItem.merged(raw)
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged.first?.kind, .giftSent, "newest first")
        // The duplicate handed over the detail it alone knew.
        let streakA = merged.first { $0.kind == .streak && $0.childID == "a" }
        XCTAssertEqual(streakA?.number, 5)
        XCTAssertEqual(streakA?.value, "מדע")

        let many = (0..<50).map {
            ActivityItem(at: now.addingTimeInterval(Double(-$0) * 3_600), kind: .playStarted,
                         childID: "c\($0)")
        }
        XCTAssertEqual(ActivityItem.merged(many, cap: 10).count, 10)
    }

    // MARK: - Day grouping

    func testGroupsByDayNewestFirst() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 14))!
        let items = [
            ActivityItem(at: now, kind: .giftSent, childID: "a", number: 5),
            ActivityItem(at: now.addingTimeInterval(-3_600), kind: .playStarted, childID: "a"),
            ActivityItem(at: now.addingTimeInterval(-26 * 3_600), kind: .playEnded, childID: "a"),
            ActivityItem(at: now.addingTimeInterval(-5 * 86_400), kind: .weeklyReport),
        ]
        let days = ActivityDay.group(ActivityItem.merged(items), now: now, calendar: cal)
        XCTAssertEqual(days.count, 3)
        XCTAssertEqual(days[0].title, tr("היום"))
        XCTAssertEqual(days[0].items.count, 2)
        XCTAssertEqual(days[1].title, tr("אתמול"))
        XCTAssertNotEqual(days[2].title, tr("אתמול"), "older days get a real date")
        XCTAssertFalse(days[2].title.isEmpty)
    }

    // MARK: - Derived rows (no new write path)

    func testDerivesChoresDevicesAndTodaysMinutes() {
        let now = Date()
        let kid = UUID()
        var input = ActivityDerived.Input()
        input.now = now
        input.children = [(id: kid, name: "דנה")]
        input.caps = [kid: 60]

        var snapshot = ProgressSnapshot.blank
        snapshot.dailyEarnedDate = now
        snapshot.minutesEarnedToday = 35
        snapshot.minutesUnlockedToday = 60
        snapshot.lastModifiedAt = now
        input.snapshots = [kid: snapshot]

        input.chores = [
            Chore(id: "c1", childID: kid.uuidString, title: "לסדר את החדר", emoji: "🧹",
                  rewardMinutes: 20, rewardCoins: 0, isDaily: true, timesPerDay: 1,
                  createdAt: 0, markedDoneAt: now.timeIntervalSince1970 - 300,
                  chosenReward: "minutes", lastApprovedAt: nil, photoData: nil,
                  approvedTodayCount: 0, approvedTodayAt: nil, archived: false),
            Chore(id: "c2", childID: kid.uuidString, title: "להשקות", emoji: "🪴",
                  rewardMinutes: 10, rewardCoins: 0, isDaily: true, timesPerDay: 1,
                  createdAt: 0, markedDoneAt: nil, chosenReward: nil,
                  lastApprovedAt: now.timeIntervalSince1970 - 7_200, photoData: nil,
                  approvedTodayCount: 1, approvedTodayAt: now.timeIntervalSince1970 - 7_200,
                  archived: false),
        ]

        let fresh = ChildDevice(id: "\(kid.uuidString)_new", childID: kid.uuidString,
                                householdID: "h", deviceID: "new", name: "iPad", kind: "ipad",
                                systemVersion: "18", joinedAt: now.addingTimeInterval(-86_400),
                                lastSeenAt: now)
        let quiet = ChildDevice(id: "\(kid.uuidString)_old", childID: kid.uuidString,
                                householdID: "h", deviceID: "old", name: "iPhone", kind: "iphone",
                                systemVersion: "18", joinedAt: now.addingTimeInterval(-10 * 86_400),
                                lastSeenAt: now.addingTimeInterval(-5 * 86_400))
        input.devices = [kid.uuidString: [fresh, quiet]]

        let kinds = Set(ActivityDerived.items(input).map(\.kind))
        XCTAssertTrue(kinds.contains(.choreWaiting))
        XCTAssertTrue(kinds.contains(.choreApproved))
        XCTAssertTrue(kinds.contains(.deviceJoined))
        XCTAssertTrue(kinds.contains(.deviceQuiet))
        XCTAssertTrue(kinds.contains(.minutesEarned))
        XCTAssertTrue(kinds.contains(.dailyCapReached))

        // A device seen today is not "quiet", and a cap that is off is not "reached".
        input.devices = [kid.uuidString: [fresh]]
        input.caps = [kid: 0]
        let quieter = Set(ActivityDerived.items(input).map(\.kind))
        XCTAssertFalse(quieter.contains(.deviceQuiet))
        XCTAssertFalse(quieter.contains(.dailyCapReached))
    }

    /// Derived rows are keyed stably, so re-deriving never duplicates a row.
    func testDerivedRowsAreStableAcrossRefreshes() {
        let now = Date()
        let kid = UUID()
        var input = ActivityDerived.Input()
        input.now = now
        input.children = [(id: kid, name: "יואב")]
        input.chores = [Chore(id: "c1", childID: kid.uuidString, title: "לסדר", emoji: "🧹",
                              rewardMinutes: 20, rewardCoins: 0, isDaily: true, timesPerDay: 1,
                              createdAt: 0, markedDoneAt: now.timeIntervalSince1970 - 60,
                              chosenReward: "minutes", lastApprovedAt: nil, photoData: nil,
                              approvedTodayCount: 0, approvedTodayAt: nil, archived: false)]
        let first = ActivityDerived.items(input)
        input.now = now.addingTimeInterval(120)
        let second = ActivityDerived.items(input)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(ActivityItem.merged(first + second).count, first.count)
    }

    // MARK: - The log and the unread mark

    func testLogRecordsUpdatesAndCountsUnread() {
        ActivityLog.markRead(Date().addingTimeInterval(-3_600))
        XCTAssertTrue(ActivityLog.hasReadMark)

        let id = ActivityLog.record(.giftSent, childID: "a", childName: "דנה",
                                    number: 15, status: .sending)
        XCTAssertEqual(ActivityLog.items.count, 1)
        XCTAssertEqual(ActivityLog.items.first?.status, .sending)

        ActivityLog.update(id: id, status: .reachedCloud)
        XCTAssertEqual(ActivityLog.items.first?.status, .reachedCloud)
        ActivityLog.update(id: id, status: .deviceConfirmed)
        XCTAssertEqual(ActivityLog.items.first?.status, .deviceConfirmed)
        // A confirmation never walks backwards (a late cloud ack must not undo it).
        ActivityLog.update(id: id, status: .reachedCloud)
        XCTAssertEqual(ActivityLog.items.first?.status, .deviceConfirmed)

        // Unread = newer than the mark.
        let unread = ActivityLog.items.filter { $0.at > ActivityLog.lastReadAt }.count
        XCTAssertEqual(unread, 1)
        ActivityLog.markRead()
        XCTAssertEqual(ActivityLog.items.filter { $0.at > ActivityLog.lastReadAt }.count, 0)
    }

    /// The same banner swept twice stays one row (keyed by its own identifier).
    func testSweepingTheSameNotificationTwiceIsOneRow() {
        let at = Date()
        ActivityLog.recordNotification(type: "choreApproval", identifier: "chore-7", body: "a", at: at)
        ActivityLog.recordNotification(type: "choreApproval", identifier: "chore-7", body: "a", at: at)
        XCTAssertEqual(ActivityLog.items.count, 1)
        XCTAssertEqual(ActivityLog.items.first?.kind, .choreWaiting)
    }

    /// The log is a capped ring buffer — it can never grow without bound.
    func testLogIsCapped() {
        let now = Date()
        for i in 0..<220 {
            ActivityLog.record(.playStarted, childID: "c\(i)", at: now.addingTimeInterval(Double(i)))
        }
        XCTAssertLessThanOrEqual(ActivityLog.items.count, 160)
        XCTAssertEqual(ActivityLog.items.first?.childID, "c219", "the newest survive")
    }

    // MARK: - Routing

    func testRowsRouteWhereTheyBelong() {
        XCTAssertEqual(ActivityKind.choreWaiting.destination, .chores)
        XCTAssertEqual(ActivityKind.choreApproved.destination, .chores)
        XCTAssertEqual(ActivityKind.supportReply.destination, .support)
        XCTAssertEqual(ActivityKind.whatsNew.destination, .whatsNew)
        XCTAssertEqual(ActivityKind.minutesEarned.destination, .child)
    }

    // MARK: - Other languages

    func testLinesTranslate() {
        LanguageStore.shared.setForTesting(.en)
        XCTAssertEqual(ActivityKind.choreWaiting.line(), "A chore is waiting for your approval")
        XCTAssertTrue(ActivityKind.giftSent.line(number: 15).contains("15"))
        LanguageStore.shared.setForTesting(.ru)
        XCTAssertNotEqual(ActivityKind.choreWaiting.line(), "A chore is waiting for your approval")
        LanguageStore.shared.setForTesting(.ar)
        XCTAssertFalse(ActivityKind.supportReply.line().isEmpty)
    }
}
