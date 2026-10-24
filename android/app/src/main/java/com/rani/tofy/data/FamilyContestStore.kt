package com.rani.tofy.data

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.time.LocalDate

/**
 * 🏆 What the contest screens show, for the whole family, and the one place its
 * prizes are paid (iOS FamilyContestStore). Prizes are credited only where the
 * child really plays — their own device, or Kid Mode for that child — after a
 * transaction on their doc marked the stage paid, so two devices of the same
 * child never pay twice.
 */
object FamilyContestStore {
    data class Row(val child: Child, val standing: FamilyContest.Standing) { val id: String get() = child.id }

    /** The week's end, for the child whose device this is (shown once). */
    data class Celebration(
        val week: String, val championIDs: List<String>, val iWasChampion: Boolean, val reachedGoal: Boolean,
        val jarFull: Boolean, val minutes: Int, val single: Boolean,
    )

    data class State(
        val rows: List<Row> = emptyList(),
        val boost: Int = 0,
        val lastWeekDone: Map<String, Int> = emptyMap(),
        val celebration: Celebration? = null,
        /** The child this device plays as (null on a parent's phone). */
        val boundID: String? = null,
    ) {
        val single: Boolean get() = rows.size == 1
        val target: Int get() = rows.sumOf { it.standing.goal }
        val filled: Int get() = rows.sumOf { it.standing.done } + boost
        val stages: List<Int> get() = FamilyContest.stages(target)
        val champions: Set<String> get() = if (rows.size > 1) FamilyContest.champions(rows.map { it.standing }) else emptySet()
        val isActive: Boolean get() = rows.isNotEmpty() && target > 0
        val me: Row? get() = rows.firstOrNull { it.id == boundID }
        val fillFraction: Double get() = if (target > 0) filled.toDouble() / target else 0.0
        val stageFractions: List<Double> get() = if (target > 0) stages.map { it.toDouble() / target } else emptyList()

        /** "עוד 380 תשובות, וכולם מקבלים 30 דקות" — the next line on the jar. */
        fun nextLine(parent: Boolean): String {
            if (target <= 0) return ""
            val i = stages.indexOfFirst { filled < it }
            if (i < 0) return if (parent) tr("הצנצנת מלאה! 🎉") else tr("הַצִּנְצֶנֶת מְלֵאָה! 🎉")
            val left = stages[i] - filled
            val m = FamilyContest.stagePrize(i)
            return when {
                !parent && !single -> tr("עוֹד %lld תְּשׁוּבוֹת נְכוֹנוֹת בְּיַחַד, וְכֻלָּם מְקַבְּלִים %lld דַּקּוֹת!", left, m)
                !parent -> tr("עוֹד %lld תְּשׁוּבוֹת נְכוֹנוֹת, וּמְקַבְּלִים %lld דַּקּוֹת!", left, m)
                !single -> tr("עוד %lld תשובות נכונות, וכל הילדים מקבלים %lld דקות", left, m)
                else -> {
                    val kid = rows.first().child
                    val name = MistakeLog.strip(kid.name)
                    if (kid.isGirl) tr("עוד %lld תשובות נכונות, ו%@ מקבלת %lld דקות", left, name, m)
                    else tr("עוד %lld תשובות נכונות, ו%@ מקבל %lld דקות", left, name, m)
                }
            }
        }

        fun daysLeftLine(parent: Boolean): String {
            val n = FamilyContest.daysLeft()
            if (n == 1) return if (parent) tr("יום אחרון") else tr("יוֹם אַחֲרוֹן! ⏳")
            return if (parent) tr("נשארו %lld ימים", n) else tr("נִשְׁאֲרוּ %lld יָמִים ⏳", n)
        }
    }

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state

    private var family: List<Child> = emptyList()
    private val records = mutableMapOf<String, ContestRecord>()
    private var lastRefresh = 0L
    private var refreshing = false
    private val childCache = mutableMapOf<String, Child>()

    private val db get() = FirebaseFirestore.getInstance()
    private val cloudOK: Boolean get() = FirebaseAuth.getInstance().currentUser != null
    private fun ref(id: String): DocumentReference = db.collection("children").document(id).collection("memory").document("contest")

    /** The child this device plays as — never the first run's made-up child. */
    private val bound: String? get() = KidSession.boundChildID?.takeIf { !KidSession.localOnly }

    /** Prizes only where the child really plays: their own device, or Kid Mode for them (both bind KidSession). */
    private fun playsHere(child: String): Boolean = bound == child

    // ── history ──────────────────────────────────────────────────────────────

    /**
     * A child's days: the cloud's, and for the child bound here this device's own
     * live copy too (day by day, the larger count) — the cloud never overwrites it.
     */
    private fun history(id: String): List<ContestDay> {
        val cloud = ChildReportRepository.history.value[id].orEmpty().map { ContestDay(it.date, it.questionsAnswered, it.correct) }
        if (id != bound) return cloud
        val local = com.rani.tofy.kid.ui.play.LearningHistoryRecorder.contestDays(id)
        return (cloud + local).groupBy { it.date }.map { (d, l) -> ContestDay(d, l.maxOf { it.answered }, l.maxOf { it.correct }) }
    }

    /** The children taking part: anyone who played in the last four weeks, and always the child bound here. */
    private fun participants(): List<Child> {
        val cutoff = LocalDate.now().minusDays(28).toString()
        return family.filter { c -> c.id == bound || history(c.id).any { it.date >= cutoff && it.answered > 0 } }
    }

    /**
     * The kid side's family: the household's children (a child device has no
     * family listener), read once and cached. A parent's phone passes its own.
     */
    suspend fun familyOf(self: Child): List<Child> {
        val known = FamilyRepository.state.value.children
        if (known.any { it.id == self.id }) return known
        childCache[self.id] = self
        val hid = self.householdID.takeIf { it.isNotEmpty() } ?: return listOf(self)
        val ids = runCatching { (db.collection("households").document(hid).get().await().get("childIDs") as? List<*>)?.filterIsInstance<String>() }
            .getOrNull() ?: return listOf(self)
        for (id in ids) if (id != self.id && id !in childCache) {
            runCatching { db.collection("children").document(id).get().await() }.getOrNull()?.data?.let { childCache[id] = Child.from(id, it) }
        }
        return ids.mapNotNull { if (it == self.id) self else childCache[it] }.ifEmpty { listOf(self) }
    }

    // ── refresh ──────────────────────────────────────────────────────────────

    /** Pull what's needed, roll the week, pay what is owed. Runs at most once a minute unless [force]. */
    suspend fun refresh(family: List<Child>, force: Boolean = false) {
        if (KidSession.localOnly || refreshing) return
        this.family = family
        if (!force && System.currentTimeMillis() - lastRefresh < 60_000) { recompute(); return }
        refreshing = true
        try {
            lastRefresh = System.currentTimeMillis()
            recompute()   // what is already known shows at once; the cloud follows
            // Bounded: a read that never answers (no network) must not freeze the jar.
            for (c in family) withTimeoutOrNull(8_000) { ChildReportRepository.refreshHistory(c.id) }
            val kids = participants()
            for (c in kids) withTimeoutOrNull(8_000) { loadAndRoll(c) }?.let { records[c.id] = it }
            recompute()
            val me = bound
            if (me != null && kids.any { it.id == me } && playsHere(me)) {
                payStages(me)
                settleLastWeek(me)
            }
        } finally { refreshing = false }
    }

    fun recompute() {
        if (KidSession.localOnly) return
        val start = FamilyContest.weekStart()
        val prevStart = FamilyContest.previousWeekStart()
        val key = FamilyContest.weekKey()
        val kids = participants()
        val rows = kids.map { c ->
            val h = history(c.id)
            val goal = records[c.id]?.current?.takeIf { it.week == key }?.goal ?: FamilyContest.goal(h)
            Row(c, FamilyContest.Standing(c.id, goal, FamilyContest.correct(h, start)))
        }.sortedByDescending { it.standing.fraction }
        val boost = if (kids.size == 1) records[kids[0].id]?.current?.takeIf { it.week == key }?.boost ?: 0 else 0
        val lastDone = kids.associate { it.id to FamilyContest.correct(history(it.id), prevStart) }
        _state.update { it.copy(rows = rows, boost = boost, lastWeekDone = lastDone, boundID = bound) }
    }

    fun dismissCelebration() { _state.update { it.copy(celebration = null) } }

    // ── cloud ────────────────────────────────────────────────────────────────

    /** The child's record for this week — created or rolled when it's older. */
    private suspend fun loadAndRoll(c: Child): ContestRecord? {
        if (!cloudOK) return null
        val key = FamilyContest.weekKey()
        val prevKey = FamilyContest.previousWeekStart().toString()
        val goal = FamilyContest.goal(history(c.id))
        val r = ref(c.id)
        return runCatching {
            db.runTransaction { tx ->
                val old = ContestRecord.from(tx.get(r).data)
                if (old != null && old.current.week == key) return@runTransaction old
                val new = (old ?: ContestRecord(ContestRecord.Week("", goal, 0, emptyList()))).rolled(key, prevKey, goal)
                tx.set(r, new.toMap())
                new
            }.await()
        }.getOrNull()
    }

    /** Mark stages paid on the child's own record; returns the ones THIS call won (null = nothing to pay / failed). */
    private suspend fun claim(child: String, week: String, want: List<Int>, settle: String? = null): List<Int>? {
        if (!cloudOK) return null
        val r = ref(child)
        val res = runCatching {
            db.runTransaction { tx ->
                var rec = ContestRecord.from(tx.get(r).data) ?: return@runTransaction null
                var won = emptyList<Int>()
                val p = rec.prev
                if (rec.current.week == week) {
                    won = want.filter { it !in rec.current.paid }
                    rec = rec.copy(current = rec.current.copy(paid = rec.current.paid + won))
                } else if (p != null && p.week == week) {
                    won = want.filter { it !in p.paid }
                    rec = rec.copy(prev = p.copy(paid = p.paid + won))
                }
                if (settle != null) {
                    if (rec.settled == settle) return@runTransaction won to false
                    rec = rec.copy(settled = settle)
                }
                tx.set(r, rec.toMap())
                won to (settle != null)
            }.await()
        }.getOrNull() ?: return null
        if (settle != null && !res.second) return null
        return res.first
    }

    /** The gift wallet (giftSecondsIn), on the device that plays as [child]. */
    private fun credit(child: String, minutes: Int) {
        if (minutes <= 0 || KidSession.boundChildID != child) return
        KidSession.edit { it.creditGift(minutes * 60) }
    }

    /** 🫙 Stages reached this week → minutes for the bound child, once. */
    private suspend fun payStages(child: String) {
        val s = _state.value
        val due = FamilyContest.reached(s.filled, s.target)
        val rec = records[child] ?: return
        if (due.isEmpty() || rec.current.paid.containsAll(due)) return
        val won = claim(child, FamilyContest.weekKey(), due) ?: return
        if (won.isEmpty() || bound != child) return
        credit(child, won.sumOf { FamilyContest.stagePrize(it) })
        records[child] = rec.copy(current = rec.current.copy(paid = rec.current.paid + won))
    }

    /** 🎉 Last week's end: goal + champion (+ any stage not yet paid), once, then the celebration here. */
    private suspend fun settleLastWeek(child: String) {
        val prevStart = FamilyContest.previousWeekStart()
        val prevKey = prevStart.toString()
        val mine = records[child]?.prev ?: return
        if (mine.week != prevKey || records[child]?.settled == prevKey) return
        // Everyone's last-week standing, from their own `prev` goals.
        val before = prevStart.minusDays(7)
        val all = _state.value.rows.mapNotNull { row ->
            val p = records[row.id]?.prev?.takeIf { it.week == prevKey } ?: return@mapNotNull null
            FamilyContest.Standing(row.id, p.goal, FamilyContest.correct(history(row.id), prevStart))
        }
        val me = all.firstOrNull { it.childID == child } ?: return
        val jar = all.sumOf { it.done } + (if (all.size == 1) mine.boost else 0)
        val jarTarget = all.sumOf { it.goal }
        val stagesDue = FamilyContest.reached(jar, jarTarget)
        val beforeDone = FamilyContest.correct(history(child), before)
        val end = FamilyContest.endPrize(me, all, beforeDone)
        val won = claim(child, prevKey, stagesDue, settle = prevKey) ?: return
        if (bound != child) return
        val minutes = end + won.sumOf { FamilyContest.stagePrize(it) }
        credit(child, minutes)
        records[child] = records[child]!!.copy(settled = prevKey)
        val champs = FamilyContest.champions(all)
        _state.update {
            it.copy(celebration = Celebration(
                week = prevKey,
                championIDs = if (all.size > 1) champs.toList() else emptyList(),
                iWasChampion = if (all.size > 1) child in champs else (me.done > beforeDone && me.done > 0),
                reachedGoal = me.reachedGoal,
                jarFull = jar >= jarTarget && jarTarget > 0,
                minutes = minutes,
                single = all.size == 1,
            ))
        }
    }

    /** ➕ A family task on a one-child jar (parent side). */
    suspend fun addFamilyTask(child: String): Boolean {
        if (!cloudOK) return false
        val key = FamilyContest.weekKey()
        val r = ref(child)
        val ok = runCatching {
            db.runTransaction { tx ->
                val rec = ContestRecord.from(tx.get(r).data)?.takeIf { it.current.week == key } ?: return@runTransaction false
                tx.set(r, rec.copy(current = rec.current.copy(boost = rec.current.boost + FamilyContest.BOOST_PER_TASK)).toMap())
                true
            }.await()
        }.getOrDefault(false)
        if (ok) {
            records[child]?.let { records[child] = it.copy(current = it.current.copy(boost = it.current.boost + FamilyContest.BOOST_PER_TASK)) }
            recompute()
        }
        return ok
    }
}
