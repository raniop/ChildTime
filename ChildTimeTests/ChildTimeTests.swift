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
