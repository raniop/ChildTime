package com.rani.tofy.data

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
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

    suspend fun start(uid: String) {
        if (this.uid == uid && _state.value.household != null) return
        stop()
        this.uid = uid
        _state.value = FamilyState(loading = true)
        val hid = try { resolveHousehold(uid) } catch (e: Exception) {
            _state.value = FamilyState(loading = false, error = e.message); return
        }
        if (hid == null) { _state.value = FamilyState(loading = false); return }
        listen(hid)
    }

    fun stop() {
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
        val q = db.collection("households").whereArrayContains("parentUIDs", uid).get().await()
        return q.documents.firstOrNull()?.id
    }

    private fun listen(hid: String) {
        regs += db.collection("households").document(hid).addSnapshotListener { doc, err ->
            if (err != null) { _state.update { it.copy(loading = false, error = err.message) }; return@addSnapshotListener }
            val d = doc?.data ?: return@addSnapshotListener
            _state.update { it.copy(household = Household.from(hid, d), loading = false) }
        }
        regs += db.collection("children").whereEqualTo("householdID", hid).addSnapshotListener { snap, _ ->
            snap ?: return@addSnapshotListener
            val kids = snap.documents.mapNotNull { doc -> doc.data?.let { Child.from(doc.id, it) } }
            _state.update { it.copy(children = kids, childrenLoaded = it.childrenLoaded || !snap.metadata.isFromCache || kids.isNotEmpty()) }
            syncChildListeners(kids.map { it.id }.toSet())
        }
        regs += db.collection("childDevices").whereEqualTo("householdID", hid).addSnapshotListener { snap, _ ->
            snap ?: return@addSnapshotListener
            _state.update { s -> s.copy(devices = snap.documents.mapNotNull { d -> d.data?.let { ChildDevice.from(d.id, it) } }) }
        }
    }

    private fun syncChildListeners(ids: Set<String>) {
        (childRegs.keys - ids).forEach { gone -> childRegs.remove(gone)?.forEach { it.remove() } }
        (ids - childRegs.keys).forEach { id ->
            val state = db.collection("children").document(id).collection("state")
            childRegs[id] = listOf(
                state.document("current").addSnapshotListener { doc, _ ->
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
    suspend fun reassertMembership() {
        val u = uid ?: return; val hid = householdID ?: return
        runCatching { db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(u)).await() }
    }
}
