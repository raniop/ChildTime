package com.rani.tofy.data

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.MetadataChanges
import com.google.firebase.firestore.Source
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.tasks.await

/** Everything the parent home needs, live. */
data class FamilyState(
    val loading: Boolean = true,
    val household: Household? = null,
    val children: List<Child> = emptyList(),
    val progress: Map<String, Progress> = emptyMap(),
    val leases: Map<String, Lease> = emptyMap(),
    val devices: List<ChildDevice> = emptyList(),
    val error: String? = null,
    /** The first SERVER children snapshot has arrived — before it, "no children" means "not loaded yet". */
    val childrenLoaded: Boolean = false,
    /** The household doc came from the SERVER at least once (not a cold cache). */
    val householdFromServer: Boolean = false,
    /** A live listener failed — the screen says "not connected" and it re-attaches. */
    val linkProblem: String? = null,
) {
    /** The family's order (households.childOrder), then oldest first — same as iOS. */
    val orderedChildren: List<Child>
        get() {
            val order = household?.childOrder ?: emptyList()
            return children.sortedWith(compareBy<Child>({ order.indexOf(it.id).let { i -> if (i < 0) Int.MAX_VALUE else i } }, { it.createdAt }))
        }

    fun devicesOf(childID: String): List<ChildDevice> =
        devices.filter { it.childID == childID && !it.removed && !it.isParentDevice }
}

/**
 * Live listeners on the household the signed-in parent belongs to. Mirrors
 * HouseholdManager's listeners: the household doc, `children` and `childDevices`
 * queried by householdID, and each child's `state/current` + `state/window`.
 */
object FamilyRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private val _state = MutableStateFlow(FamilyState())
    val state: StateFlow<FamilyState> = _state

    private var uid: String? = null
    private val regs = mutableListOf<ListenerRegistration>()
    private val childRegs = mutableMapOf<String, List<ListenerRegistration>>()

    /** False when no family could be resolved — AccountRepository retries. */
    suspend fun start(uid: String): Boolean {
        if (this.uid == uid && _state.value.household != null) return true
        stop()
        this.uid = uid
        _state.value = FamilyState(loading = true)
        val hid = try { resolveHousehold(uid) } catch (e: Exception) {
            _state.value = FamilyState(loading = false, error = e.message); return false
        }
        if (hid == null) { _state.value = FamilyState(loading = false); return false }
        listen(hid)
        return true
    }

    // 🔌 A Firestore listener that errors is DEAD for good. These used to ignore
    // the error, so the dashboard froze on its last numbers. Now: say so,
    // re-assert membership and re-attach with a back-off.
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var relistenJob: Job? = null
    private var listenerFailures = 0
    /** The family we're listening to — kept here, not read from `state.household`,
     *  which is still null when the very first snapshot fails (then nothing could
     *  ever re-attach, and "נסו שוב" was a dead button). */
    private var listeningHid: String? = null
    /** Which listeners are failing right now — the banner clears only when ALL are back. */
    private val failing = mutableSetOf<String>()

    private fun listenerFailed(hid: String, msg: String?, which: String = "household") {
        failing += which
        _state.update { it.copy(linkProblem = msg ?: "error", loading = false) }
        listenerFailures += 1
        val wait = (minOf(60.0, 3.0 * Math.pow(2.0, (minOf(listenerFailures - 1, 5)).toDouble())) * 1000).toLong()
        relistenJob?.cancel()
        relistenJob = scope.launch {
            delay(wait)
            if (listeningHid != hid) return@launch
            reassertMembership(hid)
            regs.forEach { it.remove() }; regs.clear()
            childRegs.values.flatten().forEach { it.remove() }; childRegs.clear()
            listen(hid)
        }
    }

    private fun listenerHealthy(which: String = "household") {
        failing -= which
        if (failing.isNotEmpty()) return
        if (listenerFailures == 0 && _state.value.linkProblem == null) return
        listenerFailures = 0
        relistenJob?.cancel(); relistenJob = null
        _state.update { it.copy(linkProblem = null) }
    }

    /** Back in the app: re-attach only if something is actually broken. */
    fun retryIfBroken() { if (_state.value.linkProblem != null) retryNow() }

    /** "נסו שוב" on the banner. */
    fun retryNow() {
        val hid = listeningHid ?: return
        listenerFailures = 0
        relistenJob?.cancel()
        scope.launch {
            reassertMembership(hid)
            regs.forEach { it.remove() }; regs.clear()
            childRegs.values.flatten().forEach { it.remove() }; childRegs.clear()
            listen(hid)
        }
    }

    fun stop() {
        relistenJob?.cancel(); relistenJob = null
        listeningHid = null
        failing.clear()
        listenerFailures = 0
        regs.forEach { it.remove() }; regs.clear()
        childRegs.values.flatten().forEach { it.remove() }; childRegs.clear()
        uid = null
        _state.value = FamilyState()
    }

    val householdID: String? get() = _state.value.household?.id

    /** The household that lists this uid; prefers the one on parents/{uid}. */
    private suspend fun resolveHousehold(uid: String): String? {
        val parent = db.collection("parents").document(uid).get().await()
        val preferred = (parent.get("householdIDs") as? List<*>)?.filterIsInstance<String>().orEmpty()
        for (hid in preferred) {
            val ok = runCatching { db.collection("households").document(hid).get().await() }.getOrNull()
            if (ok?.exists() == true && (ok.get("parentUIDs") as? List<*>)?.contains(uid) == true) return hid
        }
        val query = db.collection("households").whereArrayContains("parentUIDs", uid)
        var q = query.get().await()
        if (q.isEmpty && q.metadata.isFromCache) q = query.get(Source.SERVER).await()
        return q.documents.firstOrNull()?.id
    }

    private fun listen(hid: String) {
        listeningHid = hid
        failing.clear()
        // INCLUDE metadata changes: a server CONFIRMING the cached doc (no data
        // change) is otherwise silent, so `householdFromServer` never turned true
        // and the PIN gate waited forever on "מתחברים".
        regs += db.collection("households").document(hid).addSnapshotListener(MetadataChanges.INCLUDE) { doc, err ->
            if (err != null) { listenerFailed(hid, err.message, "household"); return@addSnapshotListener }
            listenerHealthy("household")
            val d = doc?.data ?: return@addSnapshotListener
            val server = doc.metadata.isFromCache.not()
            _state.update { it.copy(household = Household.from(hid, d), loading = false,
                householdFromServer = it.householdFromServer || server) }
        }
        regs += db.collection("children").whereEqualTo("householdID", hid).addSnapshotListener(MetadataChanges.INCLUDE) { snap, err ->
            if (err != null) { listenerFailed(hid, err.message, "children"); return@addSnapshotListener }
            listenerHealthy("children")
            snap ?: return@addSnapshotListener
            val kids = snap.documents.mapNotNull { doc -> doc.data?.let { Child.from(doc.id, it) } }
            _state.update { it.copy(children = kids, childrenLoaded = it.childrenLoaded || !snap.metadata.isFromCache || kids.isNotEmpty()) }
            syncChildListeners(kids.map { it.id }.toSet())
        }
        regs += db.collection("childDevices").whereEqualTo("householdID", hid).addSnapshotListener { snap, err ->
            if (err != null) { listenerFailed(hid, err.message, "devices"); return@addSnapshotListener }
            listenerHealthy("devices")
            snap ?: return@addSnapshotListener
            _state.update { s -> s.copy(devices = snap.documents.mapNotNull { d -> d.data?.let { ChildDevice.from(d.id, it) } }) }
        }
    }

    private fun syncChildListeners(ids: Set<String>) {
        (childRegs.keys - ids).forEach { gone ->
            childRegs.remove(gone)?.forEach { it.remove() }
            failing -= "progress:$gone"   // a deleted child's failed listener can't hold the banner up
        }
        (ids - childRegs.keys).forEach { id ->
            val state = db.collection("children").document(id).collection("state")
            childRegs[id] = listOf(
                state.document("current").addSnapshotListener { doc, err ->
                    // An error is NOT "zero progress" — keep the last numbers and heal.
                    if (err != null) { listeningHid?.let { listenerFailed(it, err.message, "progress:$id") }; return@addSnapshotListener }
                    listenerHealthy("progress:$id")
                    val p = doc?.data?.let { Progress.from(it) } ?: Progress.EMPTY
                    _state.update { it.copy(progress = it.progress + (id to p)) }
                },
                state.document("window").addSnapshotListener { doc, _ ->
                    val l = doc?.data?.let { Lease.from(it) } ?: return@addSnapshotListener
                    _state.update { it.copy(leases = it.leases + (id to l)) }
                },
            )
        }
    }

    /** Re-add our uid to parentUIDs — the rules let anyone add ONLY themselves. */
    suspend fun reassertMembership(forHousehold: String? = null) {
        val u = uid ?: return; val hid = forHousehold ?: householdID ?: return
        runCatching { db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(u)).await() }
    }
}
