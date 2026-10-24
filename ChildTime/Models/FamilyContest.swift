import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🏆 The weekly family contest (Rani, 2026-10-24).
///
/// - 🫙 The family jar: every correct answer of every child fills ONE jar.
///   At ⅓, ⅔ and full, every child gets 10, 20, then 30 minutes.
/// - 👑 The champion: each child against THEIR OWN goal (percent), so the
///   little one can win. At the week's end: reaching your goal pays 10
///   minutes, the champion another 20. Nobody "loses".
/// - One child: the jar is the child's own goal, and the parents add to it
///   with family tasks. Instead of siblings, the child races last week.
///
/// The goal is dynamic: what the child REALLY answered correctly in the last
/// weeks, plus 10% ("אם ילד עשה שבוע 600 תשובות… שבוע הבא שיהיה יותר").
///
/// Stored per child in `children/{id}/memory/contest` (covered by the
/// existing children/{id}/{sub=**} rule — no deploy):
///
///     week: "2026-10-25"  (the Sunday)   goal: 660   boost: 40   paid: [0, 1]
///     prev: { week, goal, boost, paid }  settled: "2026-10-18"
///
/// A child's prizes are credited only on a device where THAT child is bound,
/// after a transaction on their doc marks the stage paid, so two devices of
/// the same child never pay twice.
enum FamilyContest {
    /// Minutes for every child at each jar stage (Rani: "10 20 30").
    static let stagePrizes = [10, 20, 30]
    static let goalPrize = 10
    static let championPrize = 20
    static let minGoal = 70
    /// Family tasks a parent can add to a one-child jar.
    static let boostPerTask = 20

    // MARK: Weeks (Sunday → Saturday, the device's calendar)

    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        c.firstWeekday = 1
        return c
    }

    static func weekStart(_ d: Date = Date()) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: d)?.start ?? calendar.startOfDay(for: d)
    }

    static func weekKey(_ d: Date = Date()) -> String { LearningHistoryStore.dayKey(weekStart(d)) }

    static func previousWeekStart(_ d: Date = Date()) -> Date {
        calendar.date(byAdding: .day, value: -7, to: weekStart(d)) ?? weekStart(d)
    }

    static func dayKeys(from start: Date) -> [String] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }.map(LearningHistoryStore.dayKey)
    }

    static func correct(_ history: [DailyStat], weekFrom start: Date) -> Int {
        let keys = Set(dayKeys(from: start))
        return history.filter { keys.contains($0.date) }.reduce(0) { $0 + $1.correct }
    }

    /// Days left including today (Saturday → 1).
    static func daysLeft(_ now: Date = Date()) -> Int {
        let start = weekStart(now)
        let today = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0
        return max(1, 7 - today)
    }

    // MARK: The goal

    /// Next week's goal from the child's real answers: a strong week raises it
    /// (+10%); a weak week (ill, a trip) only pulls it toward the average, so
    /// it never jumps out of reach. `recentDailyAverage` is for a child with
    /// no full week yet.
    static func goal(lastWeek: Int, weekBefore: Int, recentDailyAverage: Double = 0) -> Int {
        let base: Double
        if lastWeek == 0 && weekBefore == 0 {
            base = recentDailyAverage * 7
        } else if lastWeek >= weekBefore {
            base = Double(lastWeek)
        } else {
            base = Double(lastWeek + weekBefore) / 2
        }
        return max(minGoal, round10(base * 1.1))
    }

    static func goal(from history: [DailyStat], now: Date = Date()) -> Int {
        let last = previousWeekStart(now)
        let before = calendar.date(byAdding: .day, value: -7, to: last) ?? last
        let recent = history.filter { $0.date >= LearningHistoryStore.dayKey(before) && $0.date < weekKey(now) && $0.correct > 0 }
        let avg = recent.isEmpty ? 0 : Double(recent.reduce(0) { $0 + $1.correct }) / Double(recent.count)
        return goal(lastWeek: correct(history, weekFrom: last), weekBefore: correct(history, weekFrom: before),
                    recentDailyAverage: avg)
    }

    static func round10(_ x: Double) -> Int { Int((x / 10).rounded()) * 10 }

    // MARK: The jar

    /// ⅓, ⅔ and full, in round tens; the last is exactly the target.
    static func stages(target: Int) -> [Int] {
        guard target > 0 else { return [0, 0, 0] }
        return [round10(Double(target) / 3), round10(Double(target) * 2 / 3), target]
    }

    static func reached(_ filled: Int, target: Int) -> [Int] {
        stages(target: target).enumerated().filter { filled >= $0.element && $0.element > 0 }.map(\.offset)
    }

    // MARK: Standings

    struct Standing: Equatable {
        let childID: UUID
        let goal: Int
        let done: Int
        var fraction: Double { goal > 0 ? Double(done) / Double(goal) : 0 }
        var percent: Int { Int((fraction * 100).rounded()) }
        var reachedGoal: Bool { done >= goal && goal > 0 }
    }

    /// Everyone sharing the top percent (ties share the crown). Nobody leads
    /// before anyone has answered.
    static func champions(_ s: [Standing]) -> Set<UUID> {
        guard let best = s.map(\.fraction).max(), best > 0 else { return [] }
        return Set(s.filter { abs($0.fraction - best) < 0.0001 }.map(\.childID))
    }

    /// What one child is owed at the week's end.
    static func endPrize(_ me: Standing, all: [Standing], lastWeekDone: Int) -> Int {
        var minutes = me.reachedGoal ? goalPrize : 0
        if all.count > 1 {
            if champions(all).contains(me.childID) { minutes += championPrize }
        } else if me.done > lastWeekDone && me.done > 0 {
            minutes += championPrize   // one child: beat last week's self
        }
        return minutes
    }
}

// MARK: - The stored record

struct ContestRecord: Equatable {
    struct Week: Equatable { var week: String; var goal: Int; var boost: Int; var paid: [Int] }
    var current: Week
    var prev: Week?
    var settled: String?

    init(current: Week, prev: Week? = nil, settled: String? = nil) {
        self.current = current; self.prev = prev; self.settled = settled
    }

    init?(_ d: [String: Any]) {
        guard let w = Self.week(d) else { return nil }
        current = w
        prev = (d["prev"] as? [String: Any]).flatMap(Self.week)
        settled = d["settled"] as? String
    }

    private static func week(_ d: [String: Any]) -> Week? {
        guard let w = d["week"] as? String else { return nil }
        return Week(week: w, goal: (d["goal"] as? NSNumber)?.intValue ?? FamilyContest.minGoal,
                    boost: (d["boost"] as? NSNumber)?.intValue ?? 0,
                    paid: (d["paid"] as? [NSNumber])?.map(\.intValue) ?? [])
    }

    private static func dict(_ w: Week) -> [String: Any] {
        ["week": w.week, "goal": w.goal, "boost": w.boost, "paid": w.paid]
    }

    var data: [String: Any] {
        var d = Self.dict(current)
        d["prev"] = prev.map(Self.dict) ?? NSNull()
        d["settled"] = settled ?? NSNull()
        return d
    }

    /// The record moved into `weekKey`: the old current becomes `prev` only
    /// when it was the week just before (a skipped week settles nothing).
    func rolled(to weekKey: String, prevKey: String, goal: Int) -> ContestRecord {
        guard current.week != weekKey else { return self }
        let newPrev = current.week == prevKey ? current : (prev?.week == prevKey ? prev : nil)
        return ContestRecord(current: Week(week: weekKey, goal: goal, boost: 0, paid: []), prev: newPrev, settled: settled)
    }
}

// MARK: - The live store

/// What the screens show, for the whole family, and the one place prizes are paid.
@MainActor
final class FamilyContestStore: ObservableObject {
    static let shared = FamilyContestStore()

    struct Row: Identifiable, Equatable {
        let profile: Profile
        let standing: FamilyContest.Standing
        var id: UUID { profile.id }
    }

    /// The week's end, for the child whose device this is (shown once).
    struct Celebration: Identifiable, Equatable {
        let week: String
        let championIDs: [UUID]
        let iWasChampion: Bool
        let reachedGoal: Bool
        let jarFull: Bool
        let minutes: Int
        let single: Bool
        var id: String { week }
    }

    @Published private(set) var rows: [Row] = []
    @Published private(set) var boost = 0
    @Published private(set) var lastWeekDone: [UUID: Int] = [:]
    @Published var celebration: Celebration?

    var single: Bool { rows.count == 1 }
    var target: Int { rows.reduce(0) { $0 + $1.standing.goal } }
    var filled: Int { rows.reduce(0) { $0 + $1.standing.done } + boost }
    var stages: [Int] { FamilyContest.stages(target: target) }
    var champions: Set<UUID> { rows.count > 1 ? FamilyContest.champions(rows.map(\.standing)) : [] }
    var isActive: Bool { !rows.isEmpty && target > 0 && !DemoTour.isOn }
    /// The child this device plays as, when they take part.
    var me: Row? { rows.first { $0.id == ProgressVault.shared.boundProfileID } }
    var fillFraction: Double { target > 0 ? Double(filled) / Double(target) : 0 }
    var stageFractions: [Double] { target > 0 ? stages.map { Double($0) / Double(target) } : [] }

    /// "עוד 380 תשובות, וכולם מקבלים 30 דקות" — the next line on the jar.
    func nextLine(parent: Bool) -> String {
        guard target > 0 else { return "" }
        guard let i = stages.firstIndex(where: { filled < $0 }) else {
            return parent ? tr("הצנצנת מלאה! 🎉") : tr("הַצִּנְצֶנֶת מְלֵאָה! 🎉")
        }
        let left = stages[i] - filled, m = FamilyContest.stagePrizes[min(i, 2)]
        switch (parent, single) {
        case (false, false): return tr("עוֹד \(left) תְּשׁוּבוֹת נְכוֹנוֹת בְּיַחַד, וְכֻלָּם מְקַבְּלִים \(m) דַּקּוֹת!")
        case (false, true): return tr("עוֹד \(left) תְּשׁוּבוֹת נְכוֹנוֹת, וּמְקַבְּלִים \(m) דַּקּוֹת!")
        case (true, false): return tr("עוד \(left) תשובות נכונות, וכל הילדים מקבלים \(m) דקות")
        case (true, true):
            let kid = rows.first?.profile
            let name = Question.stripNiqqud(kid?.name ?? "")
            return kid?.gender == .girl ? tr("עוד \(left) תשובות נכונות, ו\(name) מקבלת \(m) דקות")
                                        : tr("עוד \(left) תשובות נכונות, ו\(name) מקבל \(m) דקות")
        }
    }

    func daysLeftLine(parent: Bool) -> String {
        let n = FamilyContest.daysLeft()
        if n == 1 { return parent ? tr("יום אחרון") : tr("יוֹם אַחֲרוֹן! ⏳") }
        return parent ? tr("נשארו \(n) ימים") : tr("נִשְׁאֲרוּ \(n) יָמִים ⏳")
    }

    private var records: [UUID: ContestRecord] = [:]
    private var lastRefresh: Date = .distantPast
    private var refreshing = false

    private init() {}

    /// The children taking part: anyone who played in the last four weeks,
    /// and always the child bound to this device.
    private func participants() -> [Profile] {
        let cutoff = LearningHistoryStore.dayKey(Date().addingTimeInterval(-28 * 86_400))
        let bound = ProgressVault.shared.boundProfileID
        return ProfileStore.shared.profiles.filter { p in
            p.id == bound || LearningHistoryStore.shared.history(for: p.id).contains { $0.date >= cutoff && $0.questionsAnswered > 0 }
        }
    }

    /// Pull what's needed, roll the week, pay what is owed. Cheap to call
    /// often: it runs at most once a minute unless `force`.
    func refresh(force: Bool = false) async {
        guard !DemoTour.isOn, !refreshing else { return }
        guard force || Date().timeIntervalSince(lastRefresh) > 60 else { recompute(); return }
        refreshing = true
        defer { refreshing = false }
        lastRefresh = Date()
        let bound = ProgressVault.shared.boundProfileID
        // Everyone's history from the cloud — except the child who plays HERE:
        // their local copy is the live one and a pull would overwrite today's
        // answers. On a parent phone nobody plays, so all of them.
        for p in ProfileStore.shared.profiles where p.id != bound || !(bound.map(Self.playsHere) ?? false) {
            await LearningHistoryStore.shared.fetchRemoteHistory(for: p.id)
        }
        let kids = participants()
        for p in kids { records[p.id] = await loadAndRoll(p) }
        recompute()
        // Prizes only where the child really plays: their own device, or Kid
        // Mode. A parent phone's copy of a child can be stale, and a credit on
        // a stale wallet would lose to the child's newer one.
        if let bound, kids.contains(where: { $0.id == bound }), Self.playsHere(bound) {
            await payStages(for: bound)
            await settleLastWeek(for: bound)
        }
    }

    func recompute() {
        let start = FamilyContest.weekStart()
        let prevStart = FamilyContest.previousWeekStart()
        let kids = participants()
        let key = FamilyContest.weekKey()
        rows = kids.map { p in
            let h = LearningHistoryStore.shared.history(for: p.id)
            let goal = records[p.id].flatMap { $0.current.week == key ? $0.current.goal : nil } ?? FamilyContest.goal(from: h)
            return Row(profile: p, standing: .init(childID: p.id, goal: goal, done: FamilyContest.correct(h, weekFrom: start)))
        }
        .sorted { $0.standing.fraction > $1.standing.fraction }
        boost = kids.count == 1 ? (records[kids[0].id].map { $0.current.week == key ? $0.current.boost : 0 } ?? 0) : 0
        lastWeekDone = Dictionary(uniqueKeysWithValues: kids.map {
            ($0.id, FamilyContest.correct(LearningHistoryStore.shared.history(for: $0.id), weekFrom: prevStart))
        })
    }

    // MARK: Cloud

    #if canImport(FirebaseFirestore)
    private func ref(_ id: UUID) -> DocumentReference {
        Firestore.firestore().collection("children").document(id.uuidString).collection("memory").document("contest")
    }
    #endif

    private var cloudOK: Bool { !HouseholdManager.skipsCloudSync && AuthManager.shared.isSignedIn }

    /// The child's record for this week — created or rolled when it's older.
    private func loadAndRoll(_ p: Profile) async -> ContestRecord? {
        #if canImport(FirebaseFirestore)
        guard cloudOK else { return nil }
        let key = FamilyContest.weekKey()
        let prevKey = LearningHistoryStore.dayKey(FamilyContest.previousWeekStart())
        let goal = FamilyContest.goal(from: LearningHistoryStore.shared.history(for: p.id))
        let r = ref(p.id)
        let result = try? await Firestore.firestore().runTransaction { tx, _ -> Any? in
            let snap = try? tx.getDocument(r)
            let old = snap?.data().flatMap(ContestRecord.init)
            if let old, old.current.week == key { return old.data }
            let new = (old ?? ContestRecord(current: .init(week: "", goal: goal, boost: 0, paid: [])))
                .rolled(to: key, prevKey: prevKey, goal: goal)
            tx.setData(new.data, forDocument: r)
            return new.data
        }
        return (result as? [String: Any]).flatMap(ContestRecord.init)
        #else
        return nil
        #endif
    }

    /// Mark stages paid on the child's own record; returns the ones THIS call won.
    private func claim(_ child: UUID, week: String, stages want: [Int], settle: String? = nil) async -> [Int]? {
        #if canImport(FirebaseFirestore)
        guard cloudOK else { return nil }
        let r = ref(child)
        let res = try? await Firestore.firestore().runTransaction { tx, _ -> Any? in
            guard let snap = try? tx.getDocument(r), var rec = snap.data().flatMap(ContestRecord.init) else { return nil }
            var won: [Int] = []
            if rec.current.week == week {
                won = want.filter { !rec.current.paid.contains($0) }
                rec.current.paid += won
            } else if var p = rec.prev, p.week == week {
                won = want.filter { !p.paid.contains($0) }
                p.paid += won
                rec.prev = p
            }
            if let settle {
                guard rec.settled != settle else { return ["won": won, "settledNow": false] }
                rec.settled = settle
            }
            tx.setData(rec.data, forDocument: r)
            return ["won": won, "settledNow": settle != nil]
        }
        guard let d = res as? [String: Any] else { return nil }
        if settle != nil, (d["settledNow"] as? Bool) != true { return nil }
        return d["won"] as? [Int]
        #else
        return nil
        #endif
    }

    /// 🫙 Stages reached this week → minutes for the bound child, once.
    private func payStages(for child: UUID) async {
        let due = FamilyContest.reached(filled, target: target)
        guard !due.isEmpty, let rec = records[child], !Set(due).isSubset(of: Set(rec.current.paid)) else { return }
        guard let won = await claim(child, week: FamilyContest.weekKey(), stages: due), !won.isEmpty,
              ProgressVault.shared.boundProfileID == child else { return }
        let minutes = won.reduce(0) { $0 + FamilyContest.stagePrizes[min($1, 2)] }
        ProgressStore.shared.creditGift(seconds: minutes * 60)
        records[child]?.current.paid += won
        Haptic.success()
    }

    /// 🎉 Last week's end: goal + champion (+ any stage not yet paid), once,
    /// then the celebration for this device.
    private func settleLastWeek(for child: UUID) async {
        let prevStart = FamilyContest.previousWeekStart()
        let prevKey = LearningHistoryStore.dayKey(prevStart)
        guard let mine = records[child]?.prev, mine.week == prevKey, records[child]?.settled != prevKey else { return }
        // Everyone's last-week standing, from their own `prev` goals.
        let before = FamilyContest.calendar.date(byAdding: .day, value: -7, to: prevStart) ?? prevStart
        let all: [FamilyContest.Standing] = rows.compactMap { row in
            guard let p = records[row.id]?.prev, p.week == prevKey else { return nil }
            return .init(childID: row.id, goal: p.goal,
                         done: FamilyContest.correct(LearningHistoryStore.shared.history(for: row.id), weekFrom: prevStart))
        }
        guard let me = all.first(where: { $0.childID == child }) else { return }
        let jar = all.reduce(0) { $0 + $1.done } + (all.count == 1 ? mine.boost : 0)
        let jarTarget = all.reduce(0) { $0 + $1.goal }
        let stagesDue = FamilyContest.reached(jar, target: jarTarget)
        let beforeDone = FamilyContest.correct(LearningHistoryStore.shared.history(for: child), weekFrom: before)
        let end = FamilyContest.endPrize(me, all: all, lastWeekDone: beforeDone)
        guard let won = await claim(child, week: prevKey, stages: stagesDue, settle: prevKey),
              ProgressVault.shared.boundProfileID == child else { return }
        let minutes = end + won.reduce(0) { $0 + FamilyContest.stagePrizes[min($1, 2)] }
        if minutes > 0 { ProgressStore.shared.creditGift(seconds: minutes * 60) }
        records[child]?.settled = prevKey
        let champs = FamilyContest.champions(all)
        celebration = Celebration(
            week: prevKey,
            championIDs: all.count > 1 ? Array(champs) : [],
            iWasChampion: all.count > 1 ? champs.contains(child) : (me.done > beforeDone && me.done > 0),
            reachedGoal: me.reachedGoal,
            jarFull: jar >= jarTarget && jarTarget > 0,
            minutes: minutes,
            single: all.count == 1)
    }

    static func playsHere(_ child: UUID) -> Bool {
        if KidModeManager.shared.active { return KidModeManager.shared.childID == child }
        return ParentSettings.shared.deviceRole == .child
    }

    /// ➕ A family task on a one-child jar (parent side).
    func addFamilyTask(for child: UUID) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard cloudOK else { return false }
        let key = FamilyContest.weekKey()
        let r = ref(child)
        let ok = try? await Firestore.firestore().runTransaction { tx, _ -> Any? in
            guard let snap = try? tx.getDocument(r), var rec = snap.data().flatMap(ContestRecord.init),
                  rec.current.week == key else { return false }
            rec.current.boost += FamilyContest.boostPerTask
            tx.setData(rec.data, forDocument: r)
            return true
        }
        if (ok as? Bool) == true {
            records[child]?.current.boost += FamilyContest.boostPerTask
            recompute()
            return true
        }
        return false
        #else
        return false
        #endif
    }
}
