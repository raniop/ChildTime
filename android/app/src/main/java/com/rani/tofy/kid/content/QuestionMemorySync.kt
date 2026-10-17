package com.rani.tofy.kid.content

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.kid.core.FirstRun
import com.rani.tofy.kid.core.KidSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 🔁 QuestionMemorySync.swift — shares [QuestionMemory] between a child's
 * devices (Rani, 2026-10-17): a question asked on the iPad isn't asked again on
 * the Android phone, and the other way round.
 *
 * One document per child, `children/{id}/memory/questions`:
 *
 *     t: { <topic>: { <fingerprint>: <seconds since 1970>, … }, … }
 *     coverage: { <topic>: { seen, pool, at } }   — for the founder dashboard's
 *                                                  "running out of questions"
 *
 * Each device adds the questions it asked as a merge, field by field, so two
 * devices writing at once never erase each other; reading takes the later time
 * per question. Writes are gathered for a few seconds and sent together.
 * Only for the child this device is bound to, signed in, never in the first
 * run (`KidSession.localOnly`) — the same gates KidSync writes under. Tests
 * never install it.
 */
object QuestionMemorySync : QuestionMemoryCloud {
    private val lock = Any()
    private var pending: MutableMap<String, MutableMap<String, Double>> = mutableMapOf()
    private var pendingCoverage: MutableMap<String, Map<String, Any>> = mutableMapOf()
    private var pendingChild: String? = null
    private var flushScheduled = false
    /** A denied read/write (a profile that isn't a cloud child) — stop trying for this child until restart. */
    private val refused = HashSet<String>()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private fun allowed(child: String): Boolean =
        !KidSession.localOnly && KidSession.boundChildID == child && child != FirstRun.CHILD_ID &&
            FirebaseAuth.getInstance().currentUser != null &&
            synchronized(lock) { child !in refused }

    private fun ref(child: String): DocumentReference =
        FirebaseFirestore.getInstance().collection("children").document(child)
            .collection("memory").document("questions")

    private fun denied(child: String, e: Exception?) {
        if ((e as? FirebaseFirestoreException)?.code == FirebaseFirestoreException.Code.PERMISSION_DENIED) {
            synchronized(lock) { refused.add(child) }
        }
    }

    override fun pull(child: String, merge: (Map<String, Map<String, Double>>) -> Unit) {
        if (!runCatching { allowed(child) }.getOrDefault(false)) return
        ref(child).get()
            .addOnSuccessListener { snap ->
                val t = snap.get("t") as? Map<*, *> ?: return@addOnSuccessListener
                val remote = t.entries.mapNotNull { (topic, value) ->
                    val entries = (value as? Map<*, *>)?.entries
                        ?.mapNotNull { (fp, at) -> (fp as? String)?.let { k -> (at as? Number)?.let { k to it.toDouble() } } }
                        ?.toMap() ?: return@mapNotNull null
                    (topic as? String)?.let { it to entries }
                }.toMap()
                // Off the main thread: merging rewrites the saved memory.
                if (remote.isNotEmpty()) scope.launch { merge(remote) }
            }
            .addOnFailureListener { denied(child, it) }
    }

    override fun push(child: String, topic: String, fingerprint: String, at: Double) {
        if (!runCatching { allowed(child) }.getOrDefault(false)) return
        val schedule = synchronized(lock) {
            if (pendingChild != child) { pending = mutableMapOf(); pendingCoverage = mutableMapOf(); pendingChild = child }
            pending.getOrPut(topic) { mutableMapOf() }[fingerprint] = at
            val first = !flushScheduled
            flushScheduled = true
            first
        }
        if (schedule) scope.launch { delay(5_000); flush() }
    }

    override fun coverage(child: String, topic: String, seen: Int, pool: Int, at: Double) {
        if (!runCatching { allowed(child) }.getOrDefault(false)) return
        synchronized(lock) {
            if (pendingChild != child && pendingChild != null) return
            pendingChild = child
            pendingCoverage[topic] = mapOf("seen" to seen, "pool" to pool, "at" to at)
        }
    }

    private fun flush() {
        val (child, batch, cover) = synchronized(lock) {
            val out = Triple(pendingChild, pending, pendingCoverage)
            pending = mutableMapOf(); pendingCoverage = mutableMapOf(); flushScheduled = false
            out
        }
        if (child == null || batch.isEmpty()) return
        val fields = hashMapOf<String, Any>("t" to batch)
        if (cover.isNotEmpty()) fields["coverage"] = cover
        runCatching { ref(child).set(fields, SetOptions.merge()).addOnFailureListener { denied(child, it) } }
    }
}
