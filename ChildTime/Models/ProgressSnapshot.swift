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

    // MARK: - Time economy progression
    /// Questions answered since the last free Lucky Wheel spin.
    var wheelProgressCount: Int = 0
    /// Minutes deducted by the most recent mistake, refundable by a clean
    /// correct answer on the next question (Risk & Recovery loop).
    var recoveryPot: Int = 0
    /// Characters this child has bought (ids from Character3DCatalog). Synced so
    /// the kid's collection follows them — e.g. into Kid Mode on a parent's phone.
    var ownedCharacterIDs: [String] = []
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
        case batchCounter, wrongStreak, totalScore, minutesEarnedToday, dailyEarnedDate
        case answeredToday, correctToday, carryOverMinutes, bestStreak, cycleSeconds
        case topicResponseMs, topicAffinity, topicExposure, topicAbandon, topicAdaptiveLevel
        case wheelProgressCount, recoveryPot, ownedCharacterIDs
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
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .wheelProgressCount)) ?? nil { wheelProgressCount = v }
        if let v = (try? c.decodeIfPresent(Int.self, forKey: .recoveryPot)) ?? nil { recoveryPot = v }
        if let v = (try? c.decodeIfPresent([String].self, forKey: .ownedCharacterIDs)) ?? nil { ownedCharacterIDs = v }
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
    static func ratchetMerged(local: ProgressSnapshot, remote: ProgressSnapshot) -> ProgressSnapshot {
        let remoteWins = remote.revision > local.revision ||
            (remote.revision == local.revision && remote.lastModifiedAt > local.lastModifiedAt)
        var m = remoteWins ? remote : local
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
        m.lastSessionDate = laterDate(local.lastSessionDate, remote.lastSessionDate)
        m.lastDailyChestDate = laterDate(local.lastDailyChestDate, remote.lastDailyChestDate)
        m.lastDailyChallengeDate = laterDate(local.lastDailyChallengeDate, remote.lastDailyChallengeDate)
        return m
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
