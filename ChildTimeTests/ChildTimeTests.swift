//
//  ChildTimeTests.swift
//  ChildTimeTests
//
//  Created by Rani Ophir on 27/05/2026.
//

import Testing
import Foundation
@testable import ChildTime

struct ChildTimeTests {

    @Test func example() async throws {}

    /// REGRESSION: renaming the snapshot's `gems` field to `diamonds` made old
    /// payloads (which have "gems" / "stars" but NO "diamonds") fail to decode
    /// entirely, wiping ALL accumulated progress. The resilient decoder must keep
    /// every present field — and recover diamonds from the legacy `gems` key.
    @Test func oldSnapshotMissingDiamonds_keepsStars() throws {
        let json: [String: Any] = [
            "stars": 12_345,            // lots of accumulated stars
            "gems": 7,                  // legacy key (pre-diamonds)
            "xp": 88,
            "totalScore": 4_200,
            "ownedCharacterIDs": ["fox", "bear"],
            "revision": 9
            // NOTE: no "diamonds" key — exactly the old-payload shape.
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let snap = try JSONDecoder().decode(ProgressSnapshot.self, from: data)

        #expect(snap.stars == 12_345)                       // NOT wiped
        #expect(snap.diamonds == 7)                         // recovered from "gems"
        #expect(snap.xp == 88)
        #expect(snap.totalScore == 4_200)
        #expect(snap.ownedCharacterIDs == ["fox", "bear"])
        #expect(snap.revision == 9)
    }

    /// An empty / garbage payload must decode to defaults, never throw (which the
    /// vault would treat as `.blank` and overwrite good data with).
    @Test func emptySnapshotJSON_decodesToBlankNotThrow() throws {
        let data = try JSONSerialization.data(withJSONObject: [String: Any]())
        let snap = try JSONDecoder().decode(ProgressSnapshot.self, from: data)
        #expect(snap.stars == 0)
        #expect(snap.diamonds == 0)
    }

    /// The exact re-wipe scenario: a device with stale local 153★ uploading over a
    /// freshly-restored cloud 4100★. The merge-on-upload must NEVER lower the cloud.
    @Test func ratchetMerge_neverLowersCloudStars() {
        var local = ProgressSnapshot(); local.stars = 153;  local.revision = 197; local.diamonds = 34
        var cloud = ProgressSnapshot(); cloud.stars = 4100; cloud.revision = 198; cloud.diamonds = 34

        let merged = ProgressSnapshot.ratchetMerged(local: local, remote: cloud)
        #expect(merged.stars == 4100)                                   // stale push can't lower it
        #expect(ProgressSnapshot.ratchetMerged(local: cloud, remote: local).stars == 4100)
        // local added nothing → equals cloud → the upload transaction skips the write.
        #expect(ProgressSnapshot.sameProgressData(merged, cloud))
    }

    /// The voice must SAY the math operator — "4 − 2 = ?" was coming out
    /// "four two" because −/=/? are silent glyphs.
    @MainActor @Test func mathSpeech_speaksOperators() {
        let out = SpeechReader.cleanForSpeech("4 − 2 = ?")
        #expect(out.contains("פָּחוֹת"))      // minus is spoken
        #expect(out.contains("כַּמָּה זֶה"))   // "= ?" → "how much"
        #expect(!out.contains("\u{2212}"))     // no bare minus glyph left
        #expect(SpeechReader.cleanForSpeech("4 + 3 = ?").contains("וְעוֹד"))
        #expect(SpeechReader.cleanForSpeech("2 × 3 = ?").contains("כָּפוּל"))
    }

    /// Emoji/geresh must not reach the voice (it read emoji NAMES + stuttered).
    @MainActor @Test func speechStripsEmojiAndGeresh() {
        let out = SpeechReader.cleanForSpeech("🌊 אֵיזֶה 'אוֹקְיָנוֹס'?")
        #expect(!out.contains("🌊"))
        #expect(!out.contains("'"))
        #expect(out.contains("אֵיזֶה"))
    }

    /// REGRESSION (the bug Rani reproduced): a child opened the parent's 60 gift
    /// minutes on the iPhone; the iPad still showed 60 and opened a SECOND window.
    /// Cause: `revision` was a per-device ACTIVITY counter, so the busier device
    /// won every merge regardless of who wrote last, kept its stale balance and
    /// re-uploaded it — resurrecting the spend. At the SAME generation, recency
    /// must decide.
    @Test func merge_spendWinsOverBusierPeerAtSameGeneration() {
        let now = Date()
        let earlier = now.addingTimeInterval(-120)
        // The spender wrote LAST; the peer merely played more (same generation).
        var spender = ProgressSnapshot()
        spender.parentGiftMinutes = 0; spender.pendingMinutes = 0; spender.diamonds = 40
        spender.revision = 7; spender.lastModifiedAt = now
        var busyPeer = ProgressSnapshot()
        busyPeer.parentGiftMinutes = 60; busyPeer.pendingMinutes = 60; busyPeer.diamonds = 100
        busyPeer.revision = 7; busyPeer.lastModifiedAt = earlier

        let a = ProgressSnapshot.ratchetMerged(local: busyPeer, remote: spender)
        #expect(a.parentGiftMinutes == 0)
        #expect(a.pendingMinutes == 0)
        #expect(a.diamonds == 40)
        // …and the same answer from the other direction (order must not matter).
        let b = ProgressSnapshot.ratchetMerged(local: spender, remote: busyPeer)
        #expect(b.parentGiftMinutes == 0)
        #expect(b.pendingMinutes == 0)
        #expect(b.diamonds == 40)
    }

    /// A causally LATER write must beat a tampered clock: a device whose date was
    /// pushed a year forward must not override state from a newer generation.
    @Test func merge_causalGenerationBeatsSkewedClock() {
        var newer = ProgressSnapshot()          // descends from later cloud state
        newer.pendingMinutes = 0; newer.revision = 9
        newer.lastModifiedAt = Date().addingTimeInterval(-3600)
        var skewed = ProgressSnapshot()         // clock set a year ahead
        skewed.pendingMinutes = 90; skewed.revision = 8
        skewed.lastModifiedAt = Date().addingTimeInterval(365 * 24 * 3600)
        #expect(ProgressSnapshot.ratchetMerged(local: skewed, remote: newer).pendingMinutes == 0)
        #expect(ProgressSnapshot.ratchetMerged(local: newer, remote: skewed).pendingMinutes == 0)
    }

    /// The comparator must be a TOTAL order — both devices must agree on the
    /// winner. On an exact (revision, lastModifiedAt) tie the old code let each
    /// side think the other lost, so both considered themselves ahead and
    /// re-uploaded forever.
    @Test func merge_isTotalOrderOnTies() {
        let t = Date()
        var x = ProgressSnapshot(); x.pendingMinutes = 10; x.revision = 5; x.lastModifiedAt = t; x.deviceID = "AAA"
        var y = ProgressSnapshot(); y.pendingMinutes = 20; y.revision = 5; y.lastModifiedAt = t; y.deviceID = "BBB"
        let m1 = ProgressSnapshot.ratchetMerged(local: x, remote: y)
        let m2 = ProgressSnapshot.ratchetMerged(local: y, remote: x)
        #expect(m1.pendingMinutes == m2.pendingMinutes)   // same winner either way
        #expect(m1.pendingMinutes == 20)                  // higher deviceID breaks the tie
    }

    /// REGRESSION (trust-critical): the daily screen-time cap counter must be
    /// SYNCED and merged as a MAX within the same day. It used to be device-local,
    /// so a child with two devices got `cap × devices` — open 60 on the iPad, then
    /// 60 more on the iPhone — with no race and no bug required.
    @Test func minutesUnlockedToday_mergesAsMaxWithinSameDay() {
        let today = Date()
        var a = ProgressSnapshot(); a.dailyEarnedDate = today; a.minutesUnlockedToday = 60; a.revision = 10
        var b = ProgressSnapshot(); b.dailyEarnedDate = today; b.minutesUnlockedToday = 45; b.revision = 99
        // Even though b "wins" the LWW race, the cap counter takes the max.
        #expect(ProgressSnapshot.ratchetMerged(local: a, remote: b).minutesUnlockedToday == 60)
        #expect(ProgressSnapshot.ratchetMerged(local: b, remote: a).minutesUnlockedToday == 60)
    }

    /// REGRESSION: a FUTURE-dated day is never legitimate — it means the clock was
    /// moved forward (Settings → Date & Time). Adopting it froze both daily caps
    /// family-wide forever, because a future date never reads as "today".
    @Test func dailyEarnedDate_futureDatedPeerIsNotAdopted() {
        let future = Calendar.current.date(byAdding: .day, value: 400, to: Date())!
        var local = ProgressSnapshot(); local.dailyEarnedDate = Date(); local.minutesUnlockedToday = 30
        var evil  = ProgressSnapshot(); evil.dailyEarnedDate = future; evil.minutesUnlockedToday = 0
        evil.revision = 9_999
        let merged = ProgressSnapshot.ratchetMerged(local: local, remote: evil)
        let day = merged.dailyEarnedDate.map { Calendar.current.startOfDay(for: $0) }
        #expect(day == nil || day! <= Calendar.current.startOfDay(for: Date()))
    }

    /// REGRESSION: every once-per-day gate must treat a stamp dated TODAY **or
    /// later** as already used. Treating a future stamp as "not today" is what let
    /// one forward clock jump permanently unlock the daily chest, the daily
    /// challenge, boss jackpots and the variety bonus.
    @Test func dayGate_futureStampCountsAsAlreadyUsed() {
        #expect(DayGate.usedToday(nil) == false)
        #expect(DayGate.usedToday(Date()) == true)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let nextYear = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
        #expect(DayGate.usedToday(tomorrow) == true)      // must NOT re-open the reward
        #expect(DayGate.usedToday(nextYear) == true)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        #expect(DayGate.usedToday(yesterday) == false)    // a real new day still works
        #expect(DayGate.isFutureDay(tomorrow) == true)
        #expect(DayGate.isFutureDay(Date()) == false)
    }

    /// REGRESSION: diamonds are a SPENDABLE wallet. They were wrongly max-merged
    /// like ⭐ stars, so a shop purchase (diamonds go DOWN) was never written to
    /// Firestore and got reverted on the next pull. Diamonds must be LWW (the
    /// revision winner's value) so spends — and earns — both sync in either
    /// direction. Stars (rank) must STILL ratchet up regardless.
    @Test func ratchetMerge_diamondsAreSpendableLWW() {
        // Local just spent: 100 → 40, bumping revision. The spend must win.
        var local = ProgressSnapshot();  local.diamonds = 40;  local.stars = 500; local.revision = 200
        var cloud = ProgressSnapshot();  cloud.diamonds = 100; cloud.stars = 500; cloud.revision = 199
        #expect(ProgressSnapshot.ratchetMerged(local: local, remote: cloud).diamonds == 40)

        // Same spend seen from the other device (remote is the newer spender).
        var localOld = ProgressSnapshot(); localOld.diamonds = 100; localOld.revision = 199
        var remoteNew = ProgressSnapshot(); remoteNew.diamonds = 40; remoteNew.revision = 200
        #expect(ProgressSnapshot.ratchetMerged(local: localOld, remote: remoteNew).diamonds == 40)

        // Earning still propagates up (local ahead → its higher balance wins).
        var earn = ProgressSnapshot(); earn.diamonds = 120; earn.revision = 201
        var old = ProgressSnapshot();  old.diamonds = 80;   old.revision = 200
        #expect(ProgressSnapshot.ratchetMerged(local: earn, remote: old).diamonds == 120)

        // ⭐ stars are rank — they must STILL never drop, even when diamonds fall.
        #expect(ProgressSnapshot.ratchetMerged(local: local, remote: cloud).stars == 500)
    }

    /// New local earnings still propagate up.
    @Test func ratchetMerge_raisesStarsWhenLocalAhead() {
        var local = ProgressSnapshot(); local.stars = 4200; local.revision = 199
        var cloud = ProgressSnapshot(); cloud.stars = 4100; cloud.revision = 198

        let merged = ProgressSnapshot.ratchetMerged(local: local, remote: cloud)
        #expect(merged.stars == 4200)                                   // earnings preserved
        #expect(!ProgressSnapshot.sameProgressData(merged, cloud))      // upload WOULD write
    }

    /// End-to-end proof that the character shop works: catalog integrity, every
    /// image actually loads from the bundle, tier/help derivation, and a real
    /// buy (not-enough-stars → fail, enough → deduct + own, double-buy → fail).
    @MainActor @Test func characterShopWorks() throws {
        let all = Character3DCatalog.all

        // 1. Roster integrity.
        #expect(all.count == 48)
        #expect(all.filter { $0.isFree }.count == 4)
        #expect(Set(all.map(\.id)).count == 48)               // no duplicate ids
        #expect(Character3DCatalog.find(nil).id == "fox")     // default fallback
        #expect(Character3DCatalog.find("does_not_exist").id == "fox")

        // 2. Every character's PNG is bundled and decodes (proves all 36 render).
        for c in all {
            #expect(c.uiImage != nil, "missing/!loadable image for \(c.id)")
        }

        // 3. Tier + helper derivation.
        #expect(CharacterTier(priceStars: 0)     == .free)
        #expect(CharacterTier(priceStars: 1500)  == .common)
        #expect(CharacterTier(priceStars: 3500)  == .rare)
        #expect(CharacterTier(priceStars: 7000)  == .epic)
        #expect(CharacterTier(priceStars: 14000) == .legendary)
        #expect(CharacterTier(priceStars: 25000) == .mythic)
        #expect(Character3DCatalog.find("fox").helpLevel == .encourage)
        #expect(CharacterTier(priceStars: 3500).help == .hint)
        #expect(CharacterTier(priceStars: 14000).help == .explain)

        let store = CharacterStore.shared
        let progress = ProgressStore.shared

        // 4. Free characters are always owned.
        #expect(store.owns(Character3DCatalog.find("fox")))

        // 5. Buying with too few diamonds fails; with enough it deducts + grants.
        //    (Stars are rank-only now — purchases burn 💎 diamonds.)
        progress.spendDiamonds(progress.diamonds)             // zero the wallet
        #expect(progress.diamonds == 0)

        guard let target = all.first(where: { !store.owns($0) && $0.priceDiamonds > 0 }) else {
            return  // everything already owned from a prior run — nothing to buy
        }

        #expect(throws: CharacterStore.PurchaseError.self) {
            try store.purchase(target)
        }
        #expect(!store.owns(target))

        progress.addDiamonds(target.priceDiamonds)
        let before = progress.diamonds
        let starsBefore = progress.stars
        let bought = try store.purchase(target)
        #expect(bought.id == target.id)
        #expect(store.owns(target))
        #expect(progress.diamonds == before - target.priceDiamonds)
        // Spending must NOT touch the leaderboard rank.
        #expect(progress.stars == starsBefore)

        // 6. Can't buy the same character twice.
        #expect(throws: CharacterStore.PurchaseError.self) {
            try store.purchase(target)
        }
    }

    // MARK: - Live friends quiz

    /// Speed scoring: an instant correct answer earns the full base; the slowest
    /// correct answer (at the buzzer) earns half; never less (everyone-earns).
    @Test func liveGameScoring_fastestEarnsMostSlowestHalf() {
        let dur = Double(LiveGameRules.questionDurationMs)
        // Instant answer → full base points.
        #expect(LiveGameRules.points(responseMs: 0, durationMs: dur) == LiveGameRules.basePoints)
        // At the buzzer → exactly half.
        #expect(LiveGameRules.points(responseMs: dur, durationMs: dur) == LiveGameRules.basePoints / 2)
        // Past the buzzer (clock skew / grace) → still clamped at half, never lower.
        #expect(LiveGameRules.points(responseMs: dur * 2, durationMs: dur) == LiveGameRules.basePoints / 2)
        // Monotonic: faster is always ≥ slower.
        let fast = LiveGameRules.points(responseMs: dur * 0.2, durationMs: dur)
        let slow = LiveGameRules.points(responseMs: dur * 0.8, durationMs: dur)
        #expect(fast > slow)
        // Degenerate duration never crashes / divides by zero.
        #expect(LiveGameRules.points(responseMs: 100, durationMs: 0) == LiveGameRules.basePoints)
    }

    /// The game-doc parser must survive Firestore's mixed numeric bridging
    /// (Int / Int64 / NSNumber / Double) and strip the never-public answer key.
    @Test func liveGameParsing_robustToFirestoreTypes() {
        let data: [String: Any] = [
            "id": "g1", "hostID": "h1", "hostName": "דָּנָה",
            "state": "question",
            "topic": "math", "difficulty": "easy",
            "totalQuestions": Int64(5),                 // Int64 bridge
            "currentIndex": NSNumber(value: 2),         // NSNumber bridge
            "questionDurationMs": 9000.0,               // Double bridge
            "questions": [
                ["prompt": "1+1", "options": ["1", "2", "3", "4"]],
                ["prompt": "2+2", "options": ["3", "4", "5", "6"]],
                ["prompt": "3+3", "options": ["5", "6", "7", "8"]],
            ],
            "revealCorrectIndex": Int64(1),
            "scores": ["h1": NSNumber(value: 150), "f2": Int64(80)],
            "invited": ["f2", "f3"],
        ]
        let g = LiveGame(from: data)
        #expect(g != nil)
        #expect(g?.totalQuestions == 5)
        #expect(g?.currentIndex == 2)
        #expect(g?.questionDurationMs == 9000)
        #expect(g?.revealCorrectIndex == 1)
        #expect(g?.scores["h1"] == 150)
        #expect(g?.scores["f2"] == 80)
        #expect(g?.currentQuestion?.options.count == 4)
        // A doc missing required keys yields nil (not a crash, not a blank game).
        #expect(LiveGame(from: ["id": "x"]) == nil)
    }

    /// Best-of-3 match winner: most rounds won, tie-broken by total points, and a
    /// genuine dead heat returns nil.
    @Test func liveGameMatchWinner_bestOfThree() {
        // Clear: 2 rounds beats 1 regardless of points.
        #expect(LiveGame.matchWinnerID(roundWins: ["a": 2, "b": 1], scores: ["a": 10, "b": 999]) == "a")
        // Tie in rounds → decided by total points.
        #expect(LiveGame.matchWinnerID(roundWins: ["a": 1, "b": 1], scores: ["a": 300, "b": 200]) == "a")
        // No rounds decided (all draws) → fall back to total points.
        #expect(LiveGame.matchWinnerID(roundWins: [:], scores: ["a": 50, "b": 30]) == "a")
        // True dead heat (same wins AND same points) → no single winner.
        #expect(LiveGame.matchWinnerID(roundWins: ["a": 1, "b": 1], scores: ["a": 100, "b": 100]) == nil)
        // Empty game → nil, no crash.
        #expect(LiveGame.matchWinnerID(roundWins: [:], scores: [:]) == nil)
    }

    /// Game deep links round-trip through both the https Universal Link and the
    /// custom scheme, and reject non-game URLs.
    @Test func gameLink_roundTrips() {
        let id = "ABC-123"
        #expect(GameLink.id(from: GameLink.url(forID: id)) == id)
        #expect(GameLink.id(from: GameLink.appURL(forID: id)) == id)
        #expect(GameLink.isGameURL(URL(string: GameLink.appURL(forID: id))!))
        #expect(GameLink.isGameURL(URL(string: "https://\(GameLink.host)/game?g=\(id)")!))
        // A friend link is NOT a game link.
        #expect(!GameLink.isGameURL(URL(string: FriendLink.url(forCode: "XYZ"))!))
    }

    // MARK: - Day streak (consecutive days played)

    /// The core day-streak transition: same day keeps it, the next day bumps it,
    /// a gap restarts it, and the first ever play starts at 1. A fixed UTC
    /// calendar makes "next day" deterministic (no DST/midnight flakiness).
    @Test func dayStreak_transitions() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let morning = cal.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 9))!
        let sameDayEvening = cal.date(from: DateComponents(year: 2026, month: 3, day: 15, hour: 21))!
        let nextDay = cal.date(byAdding: .day, value: 1, to: morning)!
        let twoDayGap = cal.date(byAdding: .day, value: 2, to: morning)!

        // First ever play → 1.
        #expect(ProgressStore.nextDayStreak(current: 0, last: nil, now: morning, calendar: cal) == 1)
        // Same calendar day (different hour) → unchanged.
        #expect(ProgressStore.nextDayStreak(current: 5, last: morning, now: sameDayEvening, calendar: cal) == 5)
        // Next consecutive day → +1.
        #expect(ProgressStore.nextDayStreak(current: 5, last: morning, now: nextDay, calendar: cal) == 6)
        // Missed a day → restart at 1.
        #expect(ProgressStore.nextDayStreak(current: 5, last: morning, now: twoDayGap, calendar: cal) == 1)
    }

    /// REGRESSION (the cross-device bug): the streak is coupled to its
    /// `lastSessionDate`. When the device that played MOST RECENTLY has the
    /// up-to-date streak, the merge must keep that streak — even if the OTHER
    /// snapshot "wins" the revision tie-break. Otherwise a stale device silently
    /// drops the streak.
    @Test func merge_dayStreak_followsMostRecentPlay() {
        let earlier = Date(timeIntervalSince1970: 1_000_000)
        let later   = Date(timeIntervalSince1970: 2_000_000)

        // Local played later (streak 6); remote is stale (streak 5) yet wins by revision.
        var local = ProgressSnapshot()
        local.dayStreak = 6; local.lastSessionDate = later;    local.revision = 50
        var remote = ProgressSnapshot()
        remote.dayStreak = 5; remote.lastSessionDate = earlier; remote.revision = 51

        let merged = ProgressSnapshot.ratchetMerged(local: local, remote: remote)
        #expect(merged.dayStreak == 6)            // NOT dropped to the stale 5
        #expect(merged.lastSessionDate == later)

        // Symmetric case: remote played later → its streak wins.
        var local2 = ProgressSnapshot()
        local2.dayStreak = 4; local2.lastSessionDate = earlier; local2.revision = 60
        var remote2 = ProgressSnapshot()
        remote2.dayStreak = 7; remote2.lastSessionDate = later;  remote2.revision = 59
        let merged2 = ProgressSnapshot.ratchetMerged(local: local2, remote: remote2)
        #expect(merged2.dayStreak == 7)
        #expect(merged2.lastSessionDate == later)
    }

    // MARK: - Chest bonus minutes

    /// REGRESSION (the "gold box doesn't add minutes" report): end-of-session
    /// wood/gold chests used to grant 0 minutes by design, so opening one never
    /// raised the play-time wallet. They now hand out a small bonus, climbing with
    /// the tier — and opening a chest must actually credit the wallet.
    @MainActor @Test func sessionChests_grantBonusMinutes() {
        // 1. Config: the tiers carry bonus minutes (wood < gold < magic < legendary).
        #expect(RewardEngine.chestContents(kind: .wood, correctInSession: 5, minutesPerCorrect: 1).minutes == 1)
        #expect(RewardEngine.chestContents(kind: .gold, correctInSession: 5, minutesPerCorrect: 1).minutes == 3)
        #expect(RewardEngine.chestContents(kind: .magic, correctInSession: 0, minutesPerCorrect: 0).minutes == 5)
        #expect(RewardEngine.chestContents(kind: .legendary, correctInSession: 0, minutesPerCorrect: 0).minutes == 15)

        // 2. Opening a gold chest actually credits the wallet (only assert when no
        //    daily cap is in force, so the whole bonus lands today rather than
        //    banking for tomorrow).
        let p = ProgressStore.shared
        ParentSettings.shared.dailyCapEnabled = false
        if !p.dailyCap.enabled {
            let reward = RewardEngine.chestContents(kind: .gold, correctInSession: 5, minutesPerCorrect: 1)
            let before = p.pendingMinutes
            _ = p.applyChestReward(reward)
            #expect(p.pendingMinutes == before + reward.minutes)   // +3 actually added
        }
    }
}

// MARK: - 🔒 Play-window lease
//
// The single-window invariant is what stops a child opening the same 60 gift
// minutes on the iPhone AND the iPad. These lock the pure parts of it.

@MainActor
@Suite("Play window lease")
struct PlayWindowLeaseTests {

    private func lease(owner: String, granted: Int, startedSecondsAgo: Double,
                       state: PlayWindowLease.State = .open,
                       kind: PlayWindowLease.Kind = .gift) -> PlayWindowLease {
        var l = PlayWindowLease()
        l.state = state
        l.leaseID = "L1"
        l.ownerDeviceID = owner
        l.kind = kind
        l.grantedSeconds = granted
        l.startedAt = Date().addingTimeInterval(-startedSecondsAgo)
        return l
    }

    @Test("a live window on the other device blocks a second one")
    func heldElsewhereBlocks() {
        let l = lease(owner: "other-ipad", granted: 3600, startedSecondsAgo: 60)
        #expect(l.isHeld)
        #expect(!l.isMine)
        #expect(l.isHeldElsewhere())
    }

    @Test("our own window never blocks us — a retried claim is idempotent")
    func ownWindowDoesNotBlock() {
        let l = lease(owner: DeviceIdentity.installID, granted: 3600, startedSecondsAgo: 60)
        #expect(l.isMine)
        #expect(!l.isHeldElsewhere())
    }

    @Test("remaining time is derived from the SERVER start, not stored")
    func remainingIsDerived() {
        let l = lease(owner: "other", granted: 600, startedSecondsAgo: 200)
        #expect(abs(l.remainingSeconds() - 400) <= 1)
    }

    @Test("remaining never goes negative")
    func remainingFloorsAtZero() {
        let l = lease(owner: "other", granted: 600, startedSecondsAgo: 5000)
        #expect(l.remainingSeconds() == 0)
    }

    @Test("a dead lease stops blocking, so a crashed device can't hold the window hostage")
    func expiredLeaseReleases() {
        let past = 600 + PlayWindowLease.expiryGraceSeconds + 10
        let l = lease(owner: "other", granted: 600, startedSecondsAgo: Double(past))
        #expect(l.isExpired())
        #expect(!l.isHeldElsewhere())
    }

    @Test("the grace period keeps a just-finished window from being stolen on clock skew")
    func graceProtectsAgainstSkew() {
        let l = lease(owner: "other", granted: 600, startedSecondsAgo: 640)
        #expect(!l.isExpired())
        #expect(l.isHeldElsewhere())
    }

    @Test("an idle lease is not held even if stale fields linger")
    func idleIsNotHeld() {
        var l = lease(owner: "other", granted: 600, startedSecondsAgo: 10, state: .idle)
        #expect(!l.isHeld)
        #expect(!l.isHeldElsewhere())
        l.state = .releasing
        #expect(l.isHeld)   // still playing until it confirms closed
    }

    @Test("round-trips through Firestore without losing the fields the refund needs")
    func firestoreRoundTrip() {
        let started = Date().addingTimeInterval(-120)
        let parsed = PlayWindowLease.from([
            "state": "open", "leaseID": "abc", "ownerDeviceID": "dev-1",
            "ownerKind": "iPad", "ownerName": "האייפד של נועה",
            "kind": "gift", "grantedSeconds": 3600,
            "startedAt": started,
            "lastReleasedLeaseID": "zzz",
        ])
        #expect(parsed.state == .open)
        #expect(parsed.leaseID == "abc")
        #expect(parsed.kind == .gift)
        #expect(parsed.grantedSeconds == 3600)
        #expect(parsed.ownerName == "האייפד של נועה")
        #expect(parsed.lastReleasedLeaseID == "zzz")
        #expect(abs(parsed.remainingSeconds() - 3480) <= 2)
    }

    
    @Test("a hand-off resumes at the exact second, not a rounded minute")
    func handoffKeepsTheSeconds() {
        // 38:50 left → the whole thing moves across.
        let spend = WalletSeconds.spend(want: 38 * 60 + 50, minutes: 38, carry: 50)
        #expect(spend.granted == 38 * 60 + 50)
        #expect(spend.minutesOut == 38)
        #expect(spend.carryLeft == 0)
    }

    @Test("time is neither minted nor lost across a full transfer round trip")
    func transferConservesTime() {
        // Start: 60 whole minutes, nothing odd. Open it all, play 70 seconds,
        // hand off, and repeat — the total the child owns must never drift.
        var minutes = 60, carry = 0
        var granted = 0
        for _ in 0..<12 {
            let s = WalletSeconds.spend(want: minutes * 60 + carry, minutes: minutes, carry: carry)
            granted = s.granted
            minutes -= s.minutesOut
            carry = s.carryLeft
            #expect(minutes >= 0)
            // 70 seconds actually played, the rest comes back.
            let left = max(0, granted - 70)
            let r = WalletSeconds.refund(seconds: left, carry: carry)
            minutes += r.minutesIn
            carry = r.carryLeft
        }
        // 12 hand-offs × 70s played = 840s spent, out of 3600s.
        #expect(minutes * 60 + carry == 3600 - 840)
    }

    @Test("spending never exceeds what the child actually has")
    func spendIsBounded() {
        let s = WalletSeconds.spend(want: 99 * 60, minutes: 3, carry: 20)
        #expect(s.granted == 3 * 60 + 20)
        #expect(s.minutesOut == 3)
        #expect(s.carryLeft == 0)
    }

    @Test("a part-minute withdrawal is charged, not given away free")
    func partialMinuteIsCharged() {
        // Wants 30s, holds 5 minutes and no carry: a whole minute leaves the
        // pocket and the unused 30s land in the carry — total unchanged.
        let s = WalletSeconds.spend(want: 30, minutes: 5, carry: 0)
        #expect(s.granted == 30)
        #expect(s.minutesOut == 1)
        #expect(s.carryLeft == 30)
        #expect((5 * 60 + 0) == (5 - s.minutesOut) * 60 + s.carryLeft + s.granted)
    }

    
    
    
    
    
    @Test("an unparseable lease doc reads as idle — never as someone else holding it")
    func garbageReadsAsIdle() {
        let parsed = PlayWindowLease.from(["state": "🤷", "grantedSeconds": "lots"])
        #expect(parsed.state == .idle)
        #expect(!parsed.isHeld)
    }
}


// MARK: - 🗺️ Category card order
//
// The kid's topic cards move once a day so a child stops tapping the same corner
// out of habit. What must NOT happen: cards moving mid-session (a child lands on
// a topic they didn't pick), a card vanishing, or the two devices disagreeing.

@MainActor
@Suite("Category card order")
struct WorldOrderTests {
    private let kid = UUID(uuidString: "C3C8CA83-7412-4B78-9E1A-0CC52D18D0F5")!
    private var worlds: [World] { Worlds.all }

    @Test("the same child on the same day always gets the same order")
    func stableWithinTheDay() {
        let day = Date()
        let a = WorldMapView.orderForToday(worlds, childID: kid, on: day)
        let b = WorldMapView.orderForToday(worlds, childID: kid, on: day.addingTimeInterval(3600))
        #expect(a.map(\.id) == b.map(\.id))
    }

    @Test("the order does change across days")
    func variesAcrossDays() {
        let base = WorldMapView.orderForToday(worlds, childID: kid).map(\.id)
        let changed = (1...7).contains { d in
            let later = Date().addingTimeInterval(Double(d) * 86_400)
            return WorldMapView.orderForToday(worlds, childID: kid, on: later).map(\.id) != base
        }
        #expect(changed)
    }

    @Test("no card is ever lost or duplicated")
    func everyCardSurvives() {
        for d in 0..<30 {
            let day = Date().addingTimeInterval(Double(d) * 86_400)
            let out = WorldMapView.orderForToday(worlds, childID: kid, on: day)
            #expect(out.count == worlds.count)
            #expect(Set(out.map(\.id)) == Set(worlds.map(\.id)))
        }
    }

    @Test("the 💫 arena keeps its slot — a special card must not wander")
    func bonusWorldStaysPut() {
        guard let fixed = worlds.firstIndex(where: { $0.isBonusWorld }) else { return }
        for d in 0..<30 {
            let day = Date().addingTimeInterval(Double(d) * 86_400)
            let out = WorldMapView.orderForToday(worlds, childID: kid, on: day)
            #expect(out[fixed].isBonusWorld)
        }
    }

    @Test("two children get different orders on the same day")
    func differsPerChild() {
        let a = WorldMapView.orderForToday(worlds, childID: UUID(), on: Date()).map(\.id)
        let b = WorldMapView.orderForToday(worlds, childID: UUID(), on: Date()).map(\.id)
        #expect(a != b)
    }
}


// MARK: - 🧬 Child data ownership
//
// A real family had one child's stars written into their sibling's document.
// Accumulators merge by `max`, so the sibling's numbers ratcheted up permanently
// and no cloud-side restore could bring them down. The store now carries its
// owner, and every write-out checks it.

@MainActor
@Suite("Child data ownership")
struct DataOwnershipTests {

    @Test("a bound store only ever claims to hold that child's data")
    func bindingIsExclusive() {
        let a = UUID(), b = UUID()
        let p = ProgressStore.shared
        p.bind(to: a)
        #expect(p.holdsData(for: a))
        #expect(!p.holdsData(for: b))   // the write to b's document is refused
        p.bind(to: b)
        #expect(p.holdsData(for: b))
        #expect(!p.holdsData(for: a))
    }

    @Test("an unbound store refuses every child — it holds someone else's leftovers")
    func unboundRefuses() {
        let p = ProgressStore.shared
        p.bind(to: nil)
        #expect(!p.holdsData(for: UUID()))
    }
}


// MARK: - 💰 Wallet counters
//
// The balance is no longer stored. Each pocket keeps two lifetime totals that only
// ever rise, merged by `max`. These lock the one promise that matters: a device
// holding an out-of-date copy can never reduce a child's minutes, while a parent
// deliberately taking minutes away still works.

@MainActor
@Suite("Wallet counters")
struct WalletCounterTests {

    private func fresh() -> ProgressStore {
        let p = ProgressStore.shared
        p.resetWallets()
        return p
    }

    @Test("earning and spending are exact to the second")
    func exactToTheSecond() {
        let p = fresh()
        p.creditEarned(seconds: 29 * 60 + 40)
        #expect(p.earnedSecondsAvailable == 29 * 60 + 40)
        p.debitEarned(seconds: 40)
        #expect(p.earnedSecondsAvailable == 29 * 60)
    }

    @Test("a device that is BEHIND can never reduce the wallet")
    func staleDeviceCannotDestroyMinutes() {
        // The exact shape of the bug that cost real children real minutes: one
        // device credits 120, another still holds nothing, and they sync.
        var ahead = ProgressSnapshot()
        ahead.earnedSecondsIn = 120 * 60
        ahead.earnedSecondsOut = 0
        ahead.revision = 5

        var behind = ProgressSnapshot()
        behind.earnedSecondsIn = 0          // never saw the credit
        behind.earnedSecondsOut = 0
        behind.revision = 99                // …and is "newer" by generation

        // The stale copy wins the revision comparison and STILL cannot win here.
        let merged = ProgressSnapshot.ratchetMerged(local: behind, remote: ahead)
        #expect(merged.earnedSecondsAvailable == 120 * 60)
    }

    @Test("a parent taking minutes away survives a sync with a stale device")
    func deliberateRemovalSurvives() {
        var afterRemoval = ProgressSnapshot()
        afterRemoval.earnedSecondsIn = 120 * 60
        afterRemoval.earnedSecondsOut = 10 * 60     // parent removed 10
        afterRemoval.revision = 5

        var stale = ProgressSnapshot()
        stale.earnedSecondsIn = 120 * 60
        stale.earnedSecondsOut = 0                  // has not seen the removal
        stale.revision = 99

        let merged = ProgressSnapshot.ratchetMerged(local: stale, remote: afterRemoval)
        #expect(merged.earnedSecondsAvailable == 110 * 60)   // the removal holds
    }

    @Test("the two pockets never leak into each other")
    func pocketsAreSeparate() {
        let p = fresh()
        p.creditGift(seconds: 45)
        #expect(p.giftSecondsAvailable == 45)
        #expect(p.earnedSecondsAvailable == 0)
        p.creditEarned(seconds: 5 * 60)
        #expect(p.giftSecondsAvailable == 45)
    }

    @Test("spending is bounded by what the child actually has")
    func cannotOverspend() {
        let p = fresh()
        p.creditGift(seconds: 100)
        p.debitGift(seconds: 999)
        #expect(p.giftSecondsAvailable == 0)
        #expect(p.giftSecondsOut == 100)      // never more than went in
    }

    @Test("a full open-and-refund round trip conserves time exactly")
    func roundTripConserves() {
        let p = fresh()
        p.creditGift(seconds: 30 * 60)
        for _ in 0..<10 {
            let before = p.giftSecondsAvailable
            p.debitGift(seconds: before)          // open the whole thing
            #expect(p.giftSecondsAvailable == 0)
            p.creditGift(seconds: before - 70)    // stop after 70 seconds of play
        }
        #expect(p.giftSecondsAvailable == 30 * 60 - 700)
    }

    @Test("merging is per-counter max, so neither side loses its own progress")
    func mergeTakesMaxPerCounter() {
        var a = ProgressSnapshot()
        a.earnedSecondsIn = 500; a.earnedSecondsOut = 100; a.revision = 1
        var b = ProgressSnapshot()
        b.earnedSecondsIn = 300; b.earnedSecondsOut = 250; b.revision = 2
        let m = ProgressSnapshot.ratchetMerged(local: a, remote: b)
        #expect(m.earnedSecondsIn == 500)
        #expect(m.earnedSecondsOut == 250)
    }

    @Test("a counter a build has never written cannot erase one that has")
    func nilNeverErases() {
        var written = ProgressSnapshot()
        written.giftSecondsIn = 600
        let blank = ProgressSnapshot()          // older build: nil counters
        #expect(ProgressSnapshot.ratchetMerged(local: blank, remote: written).giftSecondsAvailable == 600)
        #expect(ProgressSnapshot.ratchetMerged(local: written, remote: blank).giftSecondsAvailable == 600)
    }
}
