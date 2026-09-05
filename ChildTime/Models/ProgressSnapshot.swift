import Foundation

/// A serializable snapshot of everything the active profile has accumulated.
/// Used to:
///   • Partition progress per profile (each profile has its own snapshot
///     stored under `progressSnapshot.<profileID>` in UserDefaults).
///   • Sync to Firestore for remote viewing / parental reset.
///   • Reset a single profile without touching others.
struct ProgressSnapshot: Codable, Equatable {
    var pendingMinutes: Int = 0
    var totalCorrect: Int = 0
    var totalAnswered: Int = 0
    var unlockEndsAt: Date? = nil
    var stars: Int = 0
    /// 💎 spendable shop wallet (was the dormant "gems" slot). Older snapshots
    /// that lack the key decode as 0 — correct, since no real diamonds existed
    /// before this currency split.
    var diamonds: Int = 0
    var xp: Int = 0
    var currentStreak: Int = 0
    var dayStreak: Int = 0
    var lastSessionDate: Date? = nil
    var lastDailyChestDate: Date? = nil
    var lastDailyChallengeDate: Date? = nil
    var unlockedWorlds: [String] = ["numbers_kingdom"]
    var worldProgress: [String: Int] = [:]
    var topicAccuracy: [String: Double] = [:]
    var topicAnswered: [String: Int] = [:]
    var topicCorrect: [String: Int] = [:]
    var batchCounter: Int = 0
    var wrongStreak: Int = 0
    var totalScore: Int = 0
    var minutesEarnedToday: Int = 0
    /// Minutes ALREADY OPENED today, against the parent's daily screen-time cap.
    /// Was device-local, which made the cap worth `cap × number of devices` (open
    /// 60 on the iPad, then 60 more on the iPhone) and reset it on any reinstall.
    /// Now synced and merged as a max within the same `dailyEarnedDate` day.
    var minutesUnlockedToday: Int = 0
    var dailyEarnedDate: Date? = nil
    /// Questions answered / correct TODAY — synced so the parent's dashboard
    /// shows today's activity even though the full learning history is local.
    var answeredToday: Int = 0
    var correctToday: Int = 0
    /// Bonus minutes banked for tomorrow (≤30). Optional so older snapshots that
    /// lack the key still decode cleanly — read back as `?? 0`.
    var carryOverMinutes: Int? = nil
    /// Longest-ever streak of correct answers (synced so the parent can see it).
    var bestStreak: Int = 0
    /// Fractional progress (seconds) toward the next play-minutes bonus.
    var cycleSeconds: Double = 0

    // MARK: - Smart Learning Feed signals (per-topic)
    /// Rolling average response time per topic, in milliseconds.
    var topicResponseMs: [String: Double] = [:]
    /// Learned affinity per topic, 0...1 — drives the explore/exploit engine.
    var topicAffinity: [String: Double] = [:]
    /// How many questions of each topic the child has been served (novelty signal).
    var topicExposure: [String: Int] = [:]
    /// Times the child abandoned a topic (replaced a question / quit mid-topic).
    var topicAbandon: [String: Int] = [:]
    /// Adaptive difficulty engine state per topic: a CONTINUOUS level
    /// (0 = easy … 2 = hard) that floats around the parent's chosen base as the
    /// child performs. Optional so snapshots written by older app versions
    /// (which lack the key) still decode cleanly — read it back as `?? [:]`.
    var topicAdaptiveLevel: [String: Double]? = nil
    var hourlyAnswered: [Int]? = nil
    var hourlyCorrect: [Int]? = nil

    // MARK: - Time economy progression
    /// Questions answered since the last free Lucky Wheel spin.
    var wheelProgressCount: Int = 0
    /// Minutes deducted by the most recent mistake, refundable by a clean
    /// correct answer on the next question (Risk & Recovery loop).
    var recoveryPot: Int = 0
    /// Characters this child has bought (ids from Character3DCatalog). Synced so
    /// the kid's collection follows them — e.g. into Kid Mode on a parent's phone.
    var ownedCharacterIDs: [String] = []
    /// 💝 Minutes a PARENT gave (the "+10" buttons) — a separate pocket from the
    /// earned wallet `pendingMinutes`, so "you earned 30" and "mom gave 10" never
    /// blur together. Not subject to the child's daily cap (a parent's gift is the
    /// parent's decision). Opened as a fixed `manual` window, like a remote grant.
    /// LWW like pendingMinutes. Optional so older snapshots decode (nil → 0).
    var parentGiftMinutes: Int? = nil

    /// Sub-minute play time the child still owns (0…59). The wallets are whole
    /// minutes, so a window closed at 38:50 used to refund 38 and silently drop
    /// the 50 seconds — a real loss on every hand-off between devices. Carried
    /// here so a transfer resumes at the exact second it left off. LWW with the
    /// snapshot: the lease transactions write it together with the pocket it was
    /// split from, so the two can never disagree. Optional → old builds decode.
    var secondsCarry: Int? = nil

    /// Which pocket `secondsCarry` belongs to. Only one window exists family-wide,
    /// so a single carry is enough — but it has to be attributable, or the seconds
    /// show up on the wrong button and get spent from the wrong wallet.
    var carryIsGift: Bool? = nil

    // MARK: - 💰 The wallets, as counters that only ever go UP
    //
    // A balance stored as a NUMBER cannot be merged safely. When two devices
    // disagree, "60" and "0" are equally valid and the winner simply REPLACES the
    // loser — and nothing distinguishes "the child spent it all" from "I am a
    // stale device that never saw them earn it". That is how real children lost
    // real minutes: a lagging copy overwrote a full wallet with an empty one.
    //
    // So the balance is not stored at all. Each pocket keeps two lifetime totals,
    // both monotonic, both merged by `max`: a device that is behind holds SMALLER
    // numbers and therefore always loses. There is no write anywhere that lowers a
    // total, so minutes cannot be destroyed by accident — while a parent taking
    // minutes away still works, because that is an INCREASE to the "out" counter.
    //
    // Counted in SECONDS, which also retires the whole `secondsCarry` mechanism:
    // nothing is ever rounded to a minute, so nothing has to be carried.
    var earnedSecondsIn: Int? = nil
    var earnedSecondsOut: Int? = nil
    var giftSecondsIn: Int? = nil
    var giftSecondsOut: Int? = nil

    /// Keep the legacy minute fields in step with the counters. They are no longer
    /// the truth, but the parent dashboard and any device on an older build still
    /// read them, so every write that moves a counter refreshes them.
    mutating func syncWalletMirrors() {
        pendingMinutes = max(0, (earnedSecondsIn ?? 0) - (earnedSecondsOut ?? 0)) / 60
        parentGiftMinutes = max(0, (giftSecondsIn ?? 0) - (giftSecondsOut ?? 0)) / 60
    }

    var earnedSecondsAvailable: Int { max(0, (earnedSecondsIn ?? 0) - (earnedSecondsOut ?? 0)) }
    var giftSecondsAvailable: Int { max(0, (giftSecondsIn ?? 0) - (giftSecondsOut ?? 0)) }

    /// Parent-triggered "throw away your cached copy of this child" stamp.
    ///
    /// Rides the snapshot rather than the command doc on purpose: a device that
    /// merely CACHES this child (a sibling's device, a shared iPad) never consumes
    /// their commands, but it does listen to this document — and it is exactly the
    /// device whose cache needs clearing. See `ProgressVault.purgeCache`.
    var purgeCacheAt: Double? = nil
    /// 💝 Gift minutes the parents GAVE today (any device) + the day it refers
    /// to — enforces the daily cap "no more than until midnight". LWW.
    var giftGivenToday: Int? = nil
    var giftGivenDate: Date? = nil
    /// 🧹 Reset generation. A wipe writes a blank state with a HIGHER resetEpoch;
    /// in ratchetMerged the higher-epoch side wins WHOLESALE (no max-merge), so a
    /// second device holding stale full progress can't ratchet it back over the
    /// reset. Optional-safe: older snapshots decode as 0.
    /// 🎡 Daily bonus stamps that grant REAL minutes. They used to live only in
    /// device-local defaults, so the comeback wheel and the 10-minute variety
    /// bonus were each claimable once per device per day. Synced and merged with
    /// `laterDate`, exactly like the daily chest.
    var lastComebackWheelAt: Date? = nil
    var varietyBonusDate: Date? = nil
    var resetEpoch: Int = 0
    /// Bumped each time the device writes the snapshot — Firestore listeners
    /// use this to skip echoes of their own writes.
    var revision: Int = 0
    var lastModifiedAt: Date = .now
    var deviceID: String = ProgressSnapshot.thisDeviceID

    static var blank: ProgressSnapshot {
        ProgressSnapshot()
    }

    /// Stable per-install identifier so we can tell whose write a remote
    /// snapshot represents.
    static let thisDeviceID: String = {
        let key = "progress.deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: key)
        return new
    }()
}

// MARK: - Resilient decoding
//
// CRITICAL: Swift's *synthesized* Decodable throws `keyNotFound` for any missing
// non-optional key — which would discard the ENTIRE snapshot (stars and all)
// when an old payload lacks a newer key. (That's exactly what renaming `gems` →
// `diamonds` did, wiping accumulated progress.) So we decode DEFENSIVELY: start
// from all-defaults, then overwrite only the keys that are actually present — a
// missing/renamed/bad field can never nuke the rest. `diamonds` also falls back
// to the legacy `gems` key. Kept in an extension so the memberwise `init()` (used
// by `captureSnapshot`/`blank`) is still synthesized.
extension ProgressSnapshot {
    enum CodingKeys: String, CodingKey {
        case pendingMinutes, totalCorrect, totalAnswered, unlockEndsAt, stars, diamonds, xp
        case currentStreak, dayStreak, lastSessionDate, lastDailyChestDate, lastDailyChallengeDate
        case unlockedWorlds, worldProgress, topicAccuracy, topicAnswered, topicCorrect
        case batchCounter, wrongStreak, totalScore, minutesEarnedToday, minutesUnlockedToday, dailyEarnedDate
        case answeredToday, correctToday, carryOverMinutes, bestStreak, cycleSeconds
        case topicResponseMs, topicAffinity, topicExposure, topicAbandon, topicAdaptiveLevel
        case hourlyAnswered, hourlyCorrect
        case wheelProgressCount, recoveryPot, ownedCharacterIDs, parentGiftMinutes, giftGivenToday, giftGivenDate
        case secondsCarry, carryIsGift, purgeCacheAt
        case earnedSecondsIn, earnedSecondsOut, giftSecondsIn, giftSecondsOut
        case lastComebackWheelAt, varietyBonusDate
        case resetEpoch
        case revision, lastModifiedAt, deviceID
    }
    private enum LegacyCodingKeys: String, CodingKey { case gems }

    init(from decoder: Decoder) throws {
        self.init()  // seed every field with its default
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else { return }

        if let v = (try? c.decodeIfPresent(Int.self, forKey: .pendingMinutes)) ?? nil { pendingMinutes = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .totalCorrect)) ?? nil { totalCorrect = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .totalAnswered)) ?? nil { totalAnswered = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .unlockEndsAt)) ?? nil { unlockEndsAt = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .stars)) ?? nil { stars = v }
        // diamonds: prefer the new key, else recover the legacy "gems" value.
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .diamonds)) ?? nil {
            diamonds = v
        } else if let legacy = try? decoder.container(keyedBy: LegacyCodingKeys.self),
                  let g = (try? legacy.decodeIfPresent(Int.self, forKey: .gems)) ?? nil {
            diamonds = g
        }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .xp)) ?? nil { xp = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .currentStreak)) ?? nil { currentStreak = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .dayStreak)) ?? nil { dayStreak = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .lastSessionDate)) ?? nil { lastSessionDate = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .lastDailyChestDate)) ?? nil { lastDailyChestDate = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .lastDailyChallengeDate)) ?? nil { lastDailyChallengeDate = v }
        if let v = (try? c.decodeIfPresent([String].self, forKey: .unlockedWorlds)) ?? nil { unlockedWorlds = v }
        if let v = (try? c.decodeIfPresent([String: Int].self, forKey: .worldProgress)) ?? nil { worldProgress = v }
        if let v = (try? c.decodeIfPresent([String: Double].self, forKey: .topicAccuracy)) ?? nil { topicAccuracy = v }
        if let v = (try? c.decodeIfPresent([String: Int].self, forKey: .topicAnswered)) ?? nil { topicAnswered = v }
        if let v = (try? c.decodeIfPresent([String: Int].self, forKey: .topicCorrect)) ?? nil { topicCorrect = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .batchCounter)) ?? nil { batchCounter = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .wrongStreak)) ?? nil { wrongStreak = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .totalScore)) ?? nil { totalScore = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .minutesEarnedToday)) ?? nil { minutesEarnedToday = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .minutesUnlockedToday)) ?? nil { minutesUnlockedToday = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .dailyEarnedDate)) ?? nil { dailyEarnedDate = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .answeredToday)) ?? nil { answeredToday = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .correctToday)) ?? nil { correctToday = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .carryOverMinutes)) ?? nil { carryOverMinutes = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .bestStreak)) ?? nil { bestStreak = v }
        if let v = (try? c.decodeIfPresent(Double.self, forKey: .cycleSeconds)) ?? nil { cycleSeconds = v }
        if let v = (try? c.decodeIfPresent([String: Double].self, forKey: .topicResponseMs)) ?? nil { topicResponseMs = v }
        if let v = (try? c.decodeIfPresent([String: Double].self, forKey: .topicAffinity)) ?? nil { topicAffinity = v }
        if let v = (try? c.decodeIfPresent([String: Int].self, forKey: .topicExposure)) ?? nil { topicExposure = v }
        if let v = (try? c.decodeIfPresent([String: Int].self, forKey: .topicAbandon)) ?? nil { topicAbandon = v }
        if let v = (try? c.decodeIfPresent([String: Double].self, forKey: .topicAdaptiveLevel)) ?? nil { topicAdaptiveLevel = v }
        if let v = (try? c.decodeIfPresent([Int].self, forKey: .hourlyAnswered)) ?? nil { hourlyAnswered = v }
        if let v = (try? c.decodeIfPresent([Int].self, forKey: .hourlyCorrect)) ?? nil { hourlyCorrect = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .wheelProgressCount)) ?? nil { wheelProgressCount = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .recoveryPot)) ?? nil { recoveryPot = v }
        if let v = (try? c.decodeIfPresent([String].self, forKey: .ownedCharacterIDs)) ?? nil { ownedCharacterIDs = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .parentGiftMinutes)) ?? nil { parentGiftMinutes = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .secondsCarry)) ?? nil { secondsCarry = v }
        if let v = (try? c.decodeIfPresent(Bool.self, forKey: .carryIsGift)) ?? nil { carryIsGift = v }
        if let v = (try? c.decodeIfPresent(Double.self, forKey: .purgeCacheAt)) ?? nil { purgeCacheAt = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .earnedSecondsIn)) ?? nil { earnedSecondsIn = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .earnedSecondsOut)) ?? nil { earnedSecondsOut = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .giftSecondsIn)) ?? nil { giftSecondsIn = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .giftSecondsOut)) ?? nil { giftSecondsOut = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .giftGivenToday)) ?? nil { giftGivenToday = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .giftGivenDate)) ?? nil { giftGivenDate = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .lastComebackWheelAt)) ?? nil { lastComebackWheelAt = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .varietyBonusDate)) ?? nil { varietyBonusDate = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .resetEpoch)) ?? nil { resetEpoch = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .revision)) ?? nil { revision = v }
        if let v = (try? c.decodeIfPresent(Date.self, forKey: .lastModifiedAt)) ?? nil { lastModifiedAt = v }
        if let v = (try? c.decodeIfPresent(String.self, forKey: .deviceID)) ?? nil { deviceID = v }
    }
}

// MARK: - Conflict-free merge (shared by the device-side merge AND merge-on-upload)
extension ProgressSnapshot {
    /// Pure ratchet-merge of two snapshots of the SAME profile. Monotonic
    /// accumulators take the **max** (so neither side's earnings are lost), owned
    /// sets union, "latest" dates take the later, and the remaining LWW/spendable
    /// fields come from the (revision, lastModifiedAt) winner. Version metadata is
    /// left as the winner's — callers finalize `revision` as needed.
    /// `max` over two optionals, staying nil only when BOTH are nil — so a build
    /// that has never written a counter cannot erase one that has.
    static func maxOpt(_ a: Int?, _ b: Int?) -> Int? {
        guard let a else { return b }
        guard let b else { return a }
        return max(a, b)
    }

    static func ratchetMerged(local: ProgressSnapshot, remote: ProgressSnapshot) -> ProgressSnapshot {
        // 🧹 A reset (higher resetEpoch) wins WHOLESALE — never max-merge across
        // a wipe, or a stale device would resurrect the old progress.
        if remote.resetEpoch != local.resetEpoch {
            return remote.resetEpoch > local.resetEpoch ? remote : local
        }
        // TOTAL order: generation first (causality), then recency among concurrent
        // writes at the same generation, then a stable id so BOTH sides always
        // agree on the winner. Previously two snapshots that tied on
        // (revision, lastModifiedAt) each considered the OTHER the loser, so both
        // thought they were ahead and re-uploaded. A bad device clock can now only
        // decide between genuinely concurrent edits — it can never override a
        // causally later one.
        let remoteWins: Bool
        if remote.revision != local.revision {
            remoteWins = remote.revision > local.revision
        } else if remote.lastModifiedAt != local.lastModifiedAt {
            remoteWins = remote.lastModifiedAt > local.lastModifiedAt
        } else {
            remoteWins = remote.deviceID > local.deviceID
        }
        var m = remoteWins ? remote : local
        // 💰 The wallet counters: max on every one. This is the whole point — a
        // device that is behind can never lower another's, in either direction.
        m.earnedSecondsIn  = Self.maxOpt(local.earnedSecondsIn,  remote.earnedSecondsIn)
        m.earnedSecondsOut = Self.maxOpt(local.earnedSecondsOut, remote.earnedSecondsOut)
        m.giftSecondsIn    = Self.maxOpt(local.giftSecondsIn,    remote.giftSecondsIn)
        m.giftSecondsOut   = Self.maxOpt(local.giftSecondsOut,   remote.giftSecondsOut)
        m.stars         = max(local.stars, remote.stars)
        // 💎 diamonds are a SPENDABLE wallet — they go DOWN when the child buys in
        // the shop. Max-merging them (like the never-decreasing ⭐ rank) made every
        // purchase un-spendable: the spend was never written to Firestore and got
        // reverted on the next pull. So diamonds are LWW — they take the (revision,
        // lastModifiedAt) winner's value, already in `m`. (Same as pendingMinutes.)
        m.xp            = max(local.xp, remote.xp)
        m.totalScore    = max(local.totalScore, remote.totalScore)
        m.totalCorrect  = max(local.totalCorrect, remote.totalCorrect)
        m.totalAnswered = max(local.totalAnswered, remote.totalAnswered)
        m.bestStreak    = max(local.bestStreak, remote.bestStreak)
        m.topicAnswered = mergeMaxInt(local.topicAnswered, remote.topicAnswered)
        m.topicCorrect  = mergeMaxInt(local.topicCorrect, remote.topicCorrect)
        m.topicExposure = mergeMaxInt(local.topicExposure, remote.topicExposure)
        m.topicAbandon  = mergeMaxInt(local.topicAbandon, remote.topicAbandon)
        m.worldProgress = mergeMaxInt(local.worldProgress, remote.worldProgress)
        m.unlockedWorlds = Array(Set(local.unlockedWorlds).union(remote.unlockedWorlds))
        m.ownedCharacterIDs = Array(Set(local.ownedCharacterIDs).union(remote.ownedCharacterIDs))
        // `dayStreak` is only meaningful PAIRED with `lastSessionDate` (the day it was
        // last bumped). Merge them as a unit: take the streak from whichever device
        // played most recently, so a stale (revision) winner can't drop/desync it.
        // A genuine >1-day gap still resets the streak in registerSessionToday() on
        // the next play, since lastSessionDate keeps the later date.
        if (remote.lastSessionDate ?? .distantPast) > (local.lastSessionDate ?? .distantPast) {
            m.dayStreak = remote.dayStreak
        } else {
            m.dayStreak = local.dayStreak
        }
        // `minutesEarnedToday` is a same-DAY counter paired with `dailyEarnedDate`.
        // Merge them as a unit and NEVER let the date move backward — a stale remote
        // (or a device in another timezone) pushing an older date would otherwise
        // trigger a false mid-day "new day" rollover on the child: it re-releases
        // banked carry-over into the wallet and flips `minutesUnlockedToday` to 0,
        // making the "open X minutes" number jump around. Same day → keep the larger
        // earned count; otherwise take the later-dated side.
        // …but a FUTURE-dated day is never legitimate (a peer whose clock was moved
        // forward). Adopting it froze both daily caps family-wide, so clamp each
        // side to at most today before comparing.
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        func sane(_ d: Date?) -> Date? {
            guard let d else { return nil }
            return cal.startOfDay(for: d) > todayStart ? nil : d
        }
        let localDay = sane(local.dailyEarnedDate)
        let remoteDay = sane(remote.dailyEarnedDate)
        let lDay = localDay ?? .distantPast
        let rDay = remoteDay ?? .distantPast
        if Calendar.current.isDate(lDay, inSameDayAs: rDay) {
            m.dailyEarnedDate = localDay ?? remoteDay
            m.minutesEarnedToday = max(local.minutesEarnedToday, remote.minutesEarnedToday)
            // MAX, never the winner's value: the daily cap must count what BOTH
            // devices already opened today, or two devices are worth two caps.
            m.minutesUnlockedToday = max(local.minutesUnlockedToday, remote.minutesUnlockedToday)
        } else if rDay > lDay {
            m.dailyEarnedDate = remoteDay
            m.minutesEarnedToday = remote.minutesEarnedToday
            m.minutesUnlockedToday = remote.minutesUnlockedToday
        } else {
            m.dailyEarnedDate = localDay
            m.minutesEarnedToday = local.minutesEarnedToday
            m.minutesUnlockedToday = local.minutesUnlockedToday
        }
        m.lastSessionDate = laterDate(local.lastSessionDate, remote.lastSessionDate)
        m.lastDailyChestDate = laterDate(local.lastDailyChestDate, remote.lastDailyChestDate)
        m.lastDailyChallengeDate = laterDate(local.lastDailyChallengeDate, remote.lastDailyChallengeDate)
        m.lastComebackWheelAt = laterDate(local.lastComebackWheelAt, remote.lastComebackWheelAt)
        m.varietyBonusDate = laterDate(local.varietyBonusDate, remote.varietyBonusDate)
        m.hourlyAnswered = mergeHourly(local.hourlyAnswered, remote.hourlyAnswered)
        m.hourlyCorrect  = mergeHourly(local.hourlyCorrect, remote.hourlyCorrect)
        return m
    }

    /// Element-wise max of two 24-slot hour-bucket arrays (monotonic counters).
    private static func mergeHourly(_ a: [Int]?, _ b: [Int]?) -> [Int]? {
        guard let a, a.count == 24 else { return b }
        guard let b, b.count == 24 else { return a }
        return (0..<24).map { Swift.max(a[$0], b[$0]) }
    }

    /// Parent-only "Focus" insight: the time-of-day band where the child answers
    /// most accurately, once there's enough data. nil until then.
    var focusInsight: (title: String, detail: String)? {
        guard let ans = hourlyAnswered, let cor = hourlyCorrect,
              ans.count == 24, cor.count == 24 else { return nil }
        guard ans.reduce(0, +) >= 25 else { return nil }   // need enough signal
        // Bands: morning 6–11, noon 12–16, evening 17–21, night 22–05.
        let bands: [(name: String, hours: [Int])] = [
            ("בַּבֹּקֶר", Array(6...11)),
            ("אַחַר הַצָּהֳרַיִם", Array(12...16)),
            ("בָּעֶרֶב", Array(17...21)),
            ("בַּלַּיְלָה", [22, 23, 0, 1, 2, 3, 4, 5]),
        ]
        var best: (name: String, acc: Double, vol: Int)? = nil
        for b in bands {
            let vol = b.hours.reduce(0) { $0 + ans[$1] }
            guard vol >= 5 else { continue }
            let correct = b.hours.reduce(0) { $0 + cor[$1] }
            let acc = Double(correct) / Double(vol)
            if best == nil || acc > best!.acc { best = (b.name, acc, vol) }
        }
        guard let best else { return nil }
        return (title: "שְׁעוֹת הַשִּׂיא: \(best.name)",
                detail: "\(best.name) הַהַצְלָחָה הֲכִי גְּבוֹהָה — \(Int((best.acc * 100).rounded()))%. כְּדַאי לְתַזְמֵן לְמִידָה לַשָּׁעוֹת הָאֵלֶּה.")
    }

    /// Equal ignoring version metadata (revision/lastModifiedAt/deviceID) and the
    /// nondeterministic order of the set-derived arrays.
    static func sameProgressData(_ a: ProgressSnapshot, _ b: ProgressSnapshot) -> Bool {
        var x = a, y = b
        x.revision = 0;                  y.revision = 0
        x.lastModifiedAt = .distantPast; y.lastModifiedAt = .distantPast
        x.deviceID = "";                 y.deviceID = ""
        x.unlockedWorlds.sort();         y.unlockedWorlds.sort()
        x.ownedCharacterIDs.sort();      y.ownedCharacterIDs.sort()
        return x == y
    }

    static func mergeMaxInt(_ a: [String: Int], _ b: [String: Int]) -> [String: Int] {
        var out = a
        for (k, v) in b { out[k] = max(out[k] ?? 0, v) }
        return out
    }
    static func laterDate(_ a: Date?, _ b: Date?) -> Date? {
        switch (a, b) {
        case let (x?, y?): return max(x, y)
        case let (x?, nil): return x
        case let (nil, y?): return y
        case (nil, nil): return nil
        }
    }
}

// MARK: - Firestore codec
//
// Shared by RemoteSyncManager and the play-window lease, so a snapshot written
// inside a lease transaction is byte-identical to one written by the normal sync.
extension ProgressSnapshot {
    static func toFirestore(_ snap: ProgressSnapshot) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(snap),
              let any = try? JSONSerialization.jsonObject(with: data),
              let dict = any as? [String: Any] else { return nil }
        return dict
    }
    static func fromFirestore(_ raw: [String: Any]) -> ProgressSnapshot? {
        guard let data = try? JSONSerialization.data(withJSONObject: raw),
              let snap = try? JSONDecoder().decode(ProgressSnapshot.self, from: data) else { return nil }
        return snap
    }
}
