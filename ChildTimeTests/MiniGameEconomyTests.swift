//
//  MiniGameEconomyTests.swift
//  ChildTimeTests
//
//  🎮 The reward economy of the twelve mini-games, end to end.
//
//  Rani saw an end card reading "⭐ +0" and asked for proof that ⭐ stars,
//  💎 diamonds and ⏱ earned minutes really land, from every game, in all three
//  modes (plain · ⚡ surprise · earn-from-a-chooser). These tests drive the
//  SHARED machinery the games call — `MiniGameLedger.record` per answer and
//  `MiniGameReward.grant` at the end of a round — with each game's own
//  parameters, and assert the deltas in `ProgressStore`.
//

import Testing
import Foundation
@testable import ChildTime

// MARK: - Harness

/// A virtual clock, so a round can be replayed at any pace without waiting for
/// the anti-farm token bucket to refill in real time.
@MainActor
private final class FakeClock {
    private(set) var now = Date(timeIntervalSince1970: 1_800_000_000)
    func tick(_ seconds: Double) { now = now.addingTimeInterval(seconds) }
    var reader: () -> Date { { [self] in now } }
}

/// One game's end-of-round reward parameters, exactly as its view passes them.
private struct GameSpec {
    let key: String        // the day-gate key `MiniGameReward` stores under
    let title: String      // parent-facing Hebrew (no niqqud)
    let starsPer: Int
    let diamondsPer: Int
    let cap: Int
    /// Items in a typical full round, and what the view counts as `correct`.
    let items: Int
}

@MainActor
private enum Economy {
    static let specs: [GameSpec] = [
        .init(key: "pairs",      title: "זוגות",           starsPer: 2, diamondsPer: 2, cap: 6,  items: 6),
        .init(key: "balloon",    title: "בלונים",          starsPer: 1, diamondsPer: 1, cap: 15, items: 15),
        .init(key: "word",       title: "בניית מילים",     starsPer: 2, diamondsPer: 2, cap: WordSets.wordCount, items: WordSets.wordCount),
        .init(key: "crush",      title: "ריסוק מספרים",    starsPer: 2, diamondsPer: 1, cap: 10, items: 10),
        .init(key: "wordsearch", title: "תפזורת",          starsPer: 2, diamondsPer: 2, cap: WordSearch.wordCount, items: WordSearch.wordCount),
        .init(key: "lightning",  title: "נכון או לא",      starsPer: 1, diamondsPer: 1, cap: 15, items: 15),
        .init(key: "sort",       title: "מיון לסלים",      starsPer: 1, diamondsPer: 1, cap: SortSets.roundItems, items: SortSets.roundItems),
        .init(key: "pattern",    title: "מה הבא בתור",     starsPer: 2, diamondsPer: 1, cap: PatternGen.roundCount, items: PatternGen.roundCount),
        .init(key: "2048",       title: "2048",            starsPer: 1, diamondsPer: 1, cap: 12, items: 8),
        .init(key: "vault",      title: "הכספת",           starsPer: 2, diamondsPer: 1, cap: 10, items: 8),
        .init(key: "grocery",    title: "המכולת",          starsPer: 2, diamondsPer: 1, cap: 6,  items: 6),
        .init(key: "balance",    title: "מאזניים",         starsPer: 2, diamondsPer: 1, cap: BalanceGen.roundCount, items: BalanceGen.roundCount),
    ]

    static func dayKey(_ game: String) -> String {
        "minigame.full.\(game).\(ProfileStore.shared.activeID?.uuidString ?? "none")"
    }

    /// A clean slate: zeroed progress, known parent settings, and no game's
    /// once-a-day full grant used up.
    static func reset(capEnabled: Bool = false, cap: Int = 120) {
        let s = ParentSettings.shared
        s.batchAnswers = 10
        s.batchMinutes = 4
        s.minutesPerCorrectAnswer = 1
        s.penaltyEnabled = true
        s.dailyCapEnabled = capEnabled
        s.maxMinutesPerDay = cap
        // The cap is per-CHILD first (ChildRecord) and only then the device
        // global, so the harness has to pin the child's own value too.
        if var profile = ProfileStore.shared.active {
            profile.dailyCapMinutes = capEnabled ? cap : nil
            ProfileStore.shared.update(profile)
        }
        ProgressStore.shared.resetAll()
        for g in specs { UserDefaults.standard.removeObject(forKey: dayKey(g.key)) }
        // 🌈 The topic-balance day counters live outside the snapshot, so
        // `resetAll` leaves them — and 30 answers in one topic put every later
        // answer on HALF rate, which quietly halved every number measured here.
        let suffix = ProfileStore.shared.activeID.map { ".\($0.uuidString)" } ?? ""
        AppGroup.defaults.removeObject(forKey: "topicAnsweredToday" + suffix)
        AppGroup.defaults.removeObject(forKey: "topicAnsweredDate" + suffix)
        // …and the once-a-day variety bonus is stamped as used, so it can't drop
        // surprise minutes into the middle of a measurement.
        AppGroup.defaults.set(Date(), forKey: "varietyBonusDate" + suffix)
        // ⏱ …and no seconds a previous test's round left for its end card.
        _ = MiniGameLedger.takeRoundSeconds()
    }

    static func session(_ clock: FakeClock) -> MiniGameEarnSession {
        MiniGameEarnSession(world: Worlds.all[0], clock: clock.reader)
    }

    /// ⭐ + 💎 a run of `n` correct answers pays in earn mode, from a zero streak:
    /// the same combo ladder a regular question climbs.
    static func runnerPayout(_ n: Int) -> (stars: Int, diamonds: Int) {
        var stars = 0, diamonds = 0
        for streak in 1...max(1, n) where n > 0 {
            stars += RewardEngine.starsForCorrect(combo: streak, isSuperQuestion: false, isMysteryPortal: false)
            diamonds += RewardEngine.diamondsForCorrect(combo: streak, isSuperQuestion: false, isMysteryPortal: false)
        }
        return (stars, diamonds)
    }
}

/// What one scripted round moved in the wallet.
private struct Delta {
    var stars = 0, diamonds = 0, minutes = 0, answered = 0, correct = 0
    var cycle: Double = 0
    /// ⏱ Earned-wallet seconds — right answers pay straight in now.
    var seconds = 0
}

@MainActor
private func measure(_ body: () -> Void) -> Delta {
    let p = ProgressStore.shared
    let before = Delta(stars: p.stars, diamonds: p.diamonds, minutes: p.pendingMinutes,
                       answered: p.answeredToday, correct: p.correctToday, cycle: p.cycleSeconds,
                       seconds: p.earnedSecondsAvailable)
    body()
    return Delta(stars: p.stars - before.stars,
                 diamonds: p.diamonds - before.diamonds,
                 minutes: p.pendingMinutes - before.minutes,
                 answered: p.answeredToday - before.answered,
                 correct: p.correctToday - before.correct,
                 cycle: p.cycleSeconds - before.cycle,
                 seconds: p.earnedSecondsAvailable - before.seconds)
}

// MARK: - The suites
//
// They all drive the same `ProgressStore.shared`, and Swift Testing runs suites
// in parallel by default — which crossed their wallets and made the numbers
// nonsense. One serialized parent suite makes every test run on its own.

@MainActor
@Suite(.serialized)
struct MiniGameEconomy {

// MARK: - 1. The end-of-round grant

@MainActor
@Suite(.serialized)
struct MiniGameGrantTests {

    /// Every game's first finished round of the day pays the full per-item
    /// amount ×3 (the day's big prize), and the wallet gains EXACTLY what the
    /// end card shows.
    @Test func fullGrantMatchesTheCard() {
        for g in Economy.specs {
            Economy.reset()
            let d = measure {
                let grant = MiniGameReward.grant(game: g.key, correct: g.items, starsPer: g.starsPer,
                                                 diamondsPer: g.diamondsPer, cap: g.cap)
                #expect(grant.full, "\(g.key): the first round of the day must pay in full")
                #expect(grant.stars == min(g.items, g.cap) * g.starsPer * 3)
                #expect(grant.diamonds == min(g.items, g.cap) * g.diamondsPer * 3)
            }
            #expect(d.stars == min(g.items, g.cap) * g.starsPer * 3, "\(g.key): ⭐ written ≠ ⭐ shown")
            #expect(d.diamonds == min(g.items, g.cap) * g.diamondsPer * 3, "\(g.key): 💎 written ≠ 💎 shown")
            #expect(d.minutes == 0, "\(g.key): a round must never pay minutes at the end")
        }
    }

    /// The replay rule: the second finished round of the same day pays the plain
    /// per-item amount (×1, a third of the day's big prize) — never zeroed.
    @Test func replayIsCappedNotZeroed() {
        for g in Economy.specs {
            Economy.reset()
            _ = MiniGameReward.grant(game: g.key, correct: g.items, starsPer: g.starsPer,
                                     diamondsPer: g.diamondsPer, cap: g.cap)
            let d = measure {
                let again = MiniGameReward.grant(game: g.key, correct: g.items, starsPer: g.starsPer,
                                                 diamondsPer: g.diamondsPer, cap: g.cap)
                #expect(!again.full)
                #expect(again.stars == min(g.items, g.cap) * g.starsPer, "\(g.key): replay pays ×1 ⭐")
                #expect(again.diamonds == min(g.items, g.cap) * g.diamondsPer, "\(g.key): replay pays ×1 💎")
            }
            #expect(d.stars > 0, "\(g.key): a successful replay must never pay 0 ⭐")
            #expect(d.diamonds > 0, "\(g.key): a successful replay must never pay 0 💎")
        }
    }

    /// ⚡ A surprise round always pays the full amount, doubled — even twice in
    /// a row, because the 12–15 real questions before it are the gate.
    @Test func surpriseAlwaysDoubles() {
        for g in Economy.specs {
            Economy.reset()
            for round in 1...2 {
                let d = measure {
                    let grant = MiniGameReward.grant(game: g.key, correct: g.items, starsPer: g.starsPer,
                                                     diamondsPer: g.diamondsPer, cap: g.cap, surprise: true)
                    #expect(grant.full && grant.doubled, "\(g.key): surprise round \(round)")
                    #expect(grant.stars == min(g.items, g.cap) * g.starsPer * 2)
                }
                #expect(d.stars == min(g.items, g.cap) * g.starsPer * 2, "\(g.key): surprise ⭐ round \(round)")
                #expect(d.diamonds == min(g.items, g.cap) * g.diamondsPer * 2, "\(g.key): surprise 💎 round \(round)")
            }
        }
    }

    /// A round with nothing solved still ends on a prize (3 ⭐ · 2 💎, Rani
    /// 2026-10-05: never an empty card) — and must NOT burn the day's full
    /// grant, so the next real round still pays in full.
    @Test func emptyRoundKeepsTheDaysFullGrant() {
        for g in Economy.specs {
            Economy.reset()
            let empty = MiniGameReward.grant(game: g.key, correct: 0, starsPer: g.starsPer,
                                             diamondsPer: g.diamondsPer, cap: g.cap)
            #expect(empty.stars == 3 && empty.diamonds == 2, "\(g.key): an empty round still pays 3 ⭐ · 2 💎")
            let real = MiniGameReward.grant(game: g.key, correct: g.items, starsPer: g.starsPer,
                                            diamondsPer: g.diamondsPer, cap: g.cap)
            #expect(real.full, "\(g.key): an empty round must not spend the day's full grant")
            #expect(real.stars == min(g.items, g.cap) * g.starsPer * 3)
        }
    }

    /// The cap is a ceiling on the ITEMS counted, never a reason to pay nothing.
    @Test func overCapIsClampedNotZeroed() {
        for g in Economy.specs {
            Economy.reset()
            let grant = MiniGameReward.grant(game: g.key, correct: g.cap + 50, starsPer: g.starsPer,
                                             diamondsPer: g.diamondsPer, cap: g.cap)
            #expect(grant.stars == g.cap * g.starsPer * 3, "\(g.key): over-cap ⭐ (the day's first round, ×3)")
            #expect(grant.diamonds == g.cap * g.diamondsPer * 3, "\(g.key): over-cap 💎 (the day's first round, ×3)")
        }
    }
}

// MARK: - 2. Per-answer crediting in earn mode

@MainActor
@Suite(.serialized)
struct MiniGameEarnTests {

    /// A correct answer in earn mode walks the runner's own path: ⭐ and 💎 on
    /// the combo ladder, and its seconds straight into the wallet. 10 answers
    /// at the default 4 min / 10 answers = 4 min.
    @Test func tenCorrectAnswersPayOneBatch() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        let d = measure {
            for _ in 0..<10 {
                clock.tick(6)   // the pace the token bucket allows
                MiniGameLedger.record(correct: true, topic: .math, responseMs: 3_000,
                                      earn: earn, surprise: false)
            }
        }
        let expected = Economy.runnerPayout(10)
        #expect(d.minutes == 4, "10 correct answers must pay the parent's 4 minutes")
        #expect(d.seconds == 240)
        #expect(d.stars == expected.stars, "⭐ per answer must match the runner's ladder")
        // 💎 double on Fri/Sat and for the topic of the day (GameEvent) — the test
        // failed every weekend until it allowed for that.
        let eventMult = GameEvent.current()?.diamondMultiplier(for: .math) ?? 1
        #expect(d.diamonds == expected.diamonds * eventMult,
                "💎 per answer must match the runner's ladder: got \(d.diamonds), want \(expected.diamonds * eventMult)")
        #expect(d.answered == 10)
        #expect(d.correct == 10)
    }

    /// A plain round (no earn session) pays no minutes and no ⭐/💎 per answer —
    /// the round's own end grant is the whole reward — but every answer still
    /// shows up in the parent's reports.
    @Test func plainModePaysOnlyAtTheEnd() {
        Economy.reset()
        let d = measure {
            for _ in 0..<10 {
                MiniGameLedger.record(correct: true, topic: .math, earn: nil, surprise: false)
            }
        }
        #expect(d.minutes == 0)
        #expect(d.stars == 0)
        #expect(d.diamonds == 0)
        #expect(d.answered == 10, "a plain round's answers must still reach the parent's reports")
        #expect(d.correct == 10)
    }

    /// ⚡ A surprise round from an EARNING session pays each right answer's
    /// seconds (Rani, 2026-10-06), so its end card shows ⏱ like every round.
    @Test func surpriseAnswersPaySecondsInAnEarningSession() {
        Economy.reset()
        MiniGameLedger.surpriseEarnsTime = true
        defer { MiniGameLedger.surpriseEarnsTime = false }
        let p = ProgressStore.shared
        let d = measure {
            for _ in 0..<3 { MiniGameLedger.record(correct: true, topic: .math, earn: nil, surprise: true) }
            MiniGameLedger.record(correct: false, topic: .math, earn: nil, surprise: true)
        }
        #expect(d.seconds == 3 * p.secondsPerCorrect, "each right answer pays its seconds; a miss costs nothing")
        let g = MiniGameReward.grant(game: "vault", correct: 3, starsPer: 2, diamondsPer: 1, cap: 4, surprise: true)
        #expect(g.seconds == 3 * p.secondsPerCorrect, "the end card's ⏱ chip")
        #expect(d.answered == 4)
    }

    /// ⚡ …and outside an earning session (Free Learning) it pays no time at all.
    @Test func surpriseAnswersPayNoMinutes() {
        Economy.reset()
        MiniGameLedger.surpriseEarnsTime = false
        let clock = FakeClock()
        let earn = Economy.session(clock)
        let d = measure {
            for _ in 0..<12 {
                clock.tick(6)
                MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: true)
            }
        }
        #expect(d.minutes == 0)
        #expect(d.seconds == 0, "a surprise answer outside an earning session pays no time")
        #expect(d.answered == 12)
    }

    /// A miss costs half a step, taken off the NEXT right answer — never out of
    /// the wallet, so the number the child sees never drops.
    @Test func aMissCostsHalfAStepAndNoBankedMinutes() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        let p = ProgressStore.shared
        for _ in 0..<5 { clock.tick(6); MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false) }
        let walletBefore = p.earnedSecondsAvailable
        MiniGameLedger.record(correct: false, topic: .math, earn: earn, surprise: false)
        #expect(p.earnedSecondsAvailable == walletBefore, "a miss must never take from the wallet")
        clock.tick(6)
        MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false)
        #expect(p.earnedSecondsAvailable - walletBefore == p.secondsPerCorrect / 2,
                "the next right answer pays half — the miss's half step")
    }

    /// ⏱ The daily cap bites to the second; past it the seconds bank for
    /// tomorrow a minute at a time; a run of misses owes half a step in all.
    @Test func perAnswerPayHonoursTheCapAndOwesOnlyOnce() {
        Economy.reset(capEnabled: true, cap: 1)
        let p = ProgressStore.shared
        let ctx = ProgressStore.AnswerContext(topic: .math, combo: 0, isSuperQuestion: false, isMysteryPortal: false)
        func right() { _ = p.recordCorrect(ctx, minutesPerCorrect: 1) }
        let base = p.earnedSecondsAvailable
        right(); right()
        #expect(p.earnedSecondsAvailable - base == 48)
        #expect(!p.atDailyCap)
        right()
        #expect(p.lastPaidSeconds == 12, "only what fits under a 1-minute cap")
        #expect(p.earnedSecondsAvailable - base == 60)
        #expect(p.atDailyCap)
        for _ in 0..<4 { right() }
        #expect(p.lastPaidSeconds == 0)
        #expect(p.earnedSecondsAvailable - base == 60)
        #expect(p.carryOverMinutes == 1, "108 s past the cap bank one minute for tomorrow")

        Economy.reset()
        _ = p.recordWrong(topic: .math, minutesPerCorrect: 1)
        #expect(p.chargeHint() == 0, "a hint after a miss owes nothing more")
        for _ in 0..<3 { #expect(p.recordWrong(topic: .math, minutesPerCorrect: 1) == 0) }
        right()
        #expect(p.lastPaidSeconds == 12)
        right()
        #expect(p.lastPaidSeconds == 24)
    }

    /// 🔁 No double-crediting: a retried answer pays once, and the miss before
    /// it is recorded once.
    @Test func aRetriedAnswerPaysOnce() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        let d = measure {
            MiniGameLedger.record(correct: false, topic: .math, earn: earn, surprise: false)
            clock.tick(6)
            MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false, retry: true)
        }
        #expect(d.answered == 2, "the miss and the retry are two answers, exactly as in the runner")
        #expect(d.correct == 1)
        #expect(d.stars == RewardEngine.starsForCorrect(combo: 1, isSuperQuestion: false, isMysteryPortal: false))
    }

    /// 🔁 …and a retried answer must NOT also refund the recovery pot — that is
    /// the reward for a CLEAN answer after a mistake.
    @Test func aRetriedAnswerDoesNotClaimTheRecoveryPot() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        let p = ProgressStore.shared
        MiniGameLedger.record(correct: false, topic: .math, earn: earn, surprise: false)
        let pot = p.recoveryPot
        clock.tick(6)
        MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false, retry: true)
        #expect(p.recoveryPot == pot, "a retry must leave the pot where it is")
    }
}

// MARK: - 3. The anti-farm token bucket

@MainActor
@Suite(.serialized)
struct MiniGameTokenBucketTests {

    /// The bucket's shape: 3 credits at the start, one more every 6 s, 4 banked
    /// at most.
    @Test func bucketShape() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        #expect(earn.takeCredit() && earn.takeCredit() && earn.takeCredit(), "3 credits at the start")
        #expect(!earn.takeCredit(), "the 4th instant answer must not be credited")
        clock.tick(6)
        #expect(earn.takeCredit(), "one credit back after 6 s")
        clock.tick(600)
        var banked = 0
        while earn.takeCredit() { banked += 1 }
        #expect(banked == 4, "at most 4 credits may be banked, got \(banked)")
    }

    /// 🌟 The bucket withholds MINUTES ONLY. An answer beyond the pace still
    /// counts in the parent's reports AND still pays its ⭐/💎 — a child racing
    /// through a board must never see their stars stop dead.
    @Test func bucketWithholdsMinutesOnly() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        // Burn the 3 starting credits.
        for _ in 0..<3 { MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false) }
        let d = measure {
            for _ in 0..<8 {
                MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false)
            }
        }
        #expect(d.answered == 8, "an uncredited answer must still reach the reports")
        #expect(d.correct == 8)
        #expect(d.cycle == 0, "an uncredited answer must not move the bonus cycle")
        #expect(d.minutes == 0)
        #expect(d.stars > 0, "an uncredited answer must still pay ⭐")
        #expect(d.diamonds > 0, "an uncredited answer must still pay 💎")
    }

    /// And the child is told something: the overlay flashes on every credited
    /// AND uncredited correct answer, so answering right is never silent.
    @Test func everyCorrectAnswerFlashesSomething() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        for i in 0..<8 {
            MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false)
            #expect(earn.flashID == i + 1, "answer \(i + 1) said nothing to the child")
        }
    }
}

// MARK: - 4. The daily cap

@MainActor
@Suite(.serialized)
struct MiniGameDailyCapTests {

    /// At the parent's daily ceiling, minutes stop — ⭐ and 💎 keep coming, the
    /// overflow banks for tomorrow, and the session knows to say so.
    @Test func atTheCapStarsKeepComingAndTheChildIsTold() {
        Economy.reset(capEnabled: true, cap: 4)
        let clock = FakeClock()
        let earn = Economy.session(clock)
        let p = ProgressStore.shared
        // The first batch fills the 4-minute ceiling exactly.
        for _ in 0..<10 { clock.tick(6); MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false) }
        #expect(p.minutesEarnedToday == 4)
        #expect(p.atDailyCap, "the ceiling must be reached")
        #expect(earn.capReached, "the session must know the ceiling was reached")

        let d = measure {
            for _ in 0..<10 { clock.tick(6); MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false) }
        }
        #expect(d.stars > 0, "⭐ must keep working past the daily ceiling")
        #expect(d.diamonds > 0, "💎 must keep working past the daily ceiling")
        #expect(d.minutes == 0, "no more playable minutes past the ceiling")
        #expect(p.carryOverMinutes == 4, "the batch earned past the ceiling banks for tomorrow")
        #expect(d.answered == 10)
    }
}

// MARK: - 5. Persistence

@MainActor
@Suite(.serialized)
struct MiniGameEconomyPersistenceTests {

    /// ⭐/💎 and the earned minutes survive a relaunch, and travel in the synced
    /// snapshot the same way a regular question's rewards do.
    @Test func roundSurvivesRelaunchAndSyncs() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        let p = ProgressStore.shared
        for _ in 0..<10 { clock.tick(6); MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false) }
        MiniGameReward.grant(game: "pairs", correct: 6, starsPer: 2, diamondsPer: 2, cap: 6)

        let snap = p.captureSnapshot()
        #expect(snap.stars == p.stars, "⭐ must be in the synced snapshot")
        #expect(snap.diamonds == p.diamonds, "💎 must be in the synced snapshot")
        #expect(snap.minutesEarnedToday == p.minutesEarnedToday)
        #expect(snap.cycleSeconds == p.cycleSeconds)
        #expect(snap.earnedSecondsIn == p.earnedSecondsIn)
        #expect(snap.pendingMinutes == p.earnedSecondsAvailable / 60)
        // The LWW invariant: a capture must carry the REAL version, never `.now`.
        #expect(snap.revision == p.revision)
        #expect(snap.lastModifiedAt == p.lastModifiedAt)

        // The relaunch: a fresh store reads the same numbers back from disk.
        let stars = p.stars, diamonds = p.diamonds, minutes = p.pendingMinutes
        #expect(AppGroup.defaults.integer(forKey: "stars") == stars)
        #expect(AppGroup.defaults.integer(forKey: "diamonds") == diamonds)
        #expect(AppGroup.defaults.integer(forKey: "pendingMinutes") == minutes)
    }
}

// MARK: - 6. The whole table — what a round pays, game by game, mode by mode

@MainActor
@Suite(.serialized)
struct MiniGameEconomyTableTests {

    /// A full, clean round of every game in every mode. Nothing a child
    /// finished may ever pay 0 ⭐, and the three modes must differ in exactly
    /// one way: earn mode also pays minutes.
    @Test func everyGameEveryModePaysSomething() {
        var rows: [String] = []
        for g in Economy.specs {
            // plain
            Economy.reset()
            let plain = measure {
                for _ in 0..<g.items { MiniGameLedger.record(correct: true, topic: .math, earn: nil, surprise: false) }
                _ = MiniGameReward.grant(game: g.key, correct: g.items, starsPer: g.starsPer,
                                         diamondsPer: g.diamondsPer, cap: g.cap)
            }
            // ⚡ surprise
            Economy.reset()
            let surprise = measure {
                for _ in 0..<g.items { MiniGameLedger.record(correct: true, topic: .math, earn: nil, surprise: true) }
                _ = MiniGameReward.grant(game: g.key, correct: g.items, starsPer: g.starsPer,
                                         diamondsPer: g.diamondsPer, cap: g.cap, surprise: true)
            }
            // earn
            Economy.reset()
            let clock = FakeClock()
            let earn = Economy.session(clock)
            let earned = measure {
                for _ in 0..<g.items {
                    clock.tick(6)
                    MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false)
                }
                _ = MiniGameReward.grant(game: g.key, correct: g.items, starsPer: g.starsPer,
                                         diamondsPer: g.diamondsPer, cap: g.cap)
            }

            // What the round itself pays, and what the answers inside it paid.
            let perAnswerStars = earned.stars - plain.stars
            let perAnswerDiamonds = earned.diamonds - plain.diamonds
            // Seconds the round earned — straight into the wallet.
            let seconds = Double(earned.seconds)

            #expect(plain.stars > 0, "\(g.key) plain paid 0 ⭐")
            #expect(plain.diamonds > 0, "\(g.key) plain paid 0 💎")
            // `plain` is the day's first round (×3); a surprise round pays ×2 of the per-item rate.
            #expect(surprise.stars * 3 == plain.stars * 2, "\(g.key) surprise must pay ×2 of the per-item ⭐")
            #expect(surprise.diamonds * 3 == plain.diamonds * 2, "\(g.key) surprise must pay ×2 of the per-item 💎")
            #expect(surprise.minutes == 0, "\(g.key) surprise must pay no minutes")
            #expect(perAnswerStars > 0, "\(g.key) earn mode paid no per-answer ⭐")
            #expect(perAnswerDiamonds > 0, "\(g.key) earn mode paid no per-answer 💎")
            // Earn mode pays the runner's own rate per correct answer (24 s at
            // the 4 min / 10 answers default).
            #expect(abs(seconds - Double(g.items * 24)) < 0.5,
                    "\(g.key): \(g.items) correct answers must earn \(g.items * 24) s, got \(seconds)")
            rows.append("| \(g.title) | \(g.items) | ⭐\(plain.stars) 💎\(plain.diamonds) | "
                        + "⭐\(surprise.stars) 💎\(surprise.diamonds) | "
                        + "⭐\(perAnswerStars) 💎\(perAnswerDiamonds) ⏱\(Int(seconds))s |")
        }
        print("ECONOMY-TABLE-BEGIN")
        rows.forEach { print($0) }
        print("ECONOMY-TABLE-END")
    }

    /// 💔 The "+0" case: a round the child SOLVED — every item right, but each
    /// one only on the second try — must never pay 0 ⭐, and must pay minutes
    /// in earn mode. This is what the runner does with a re-asked question.
    @Test func everyItemSolvedAfterAMissStillPays() {
        Economy.reset()
        let clock = FakeClock()
        let earn = Economy.session(clock)
        let d = measure {
            for _ in 0..<6 {
                MiniGameLedger.record(correct: false, topic: .math, earn: earn, surprise: false)
                clock.tick(6)
                MiniGameLedger.record(correct: true, topic: .math, earn: earn, surprise: false, retry: true)
            }
        }
        #expect(d.correct == 6, "six items solved must be six correct answers")
        #expect(d.stars > 0, "a solved-after-a-miss round must never pay 0 ⭐")
        #expect(d.seconds > 0, "a solved-after-a-miss round must pay time")
    }
}
}
