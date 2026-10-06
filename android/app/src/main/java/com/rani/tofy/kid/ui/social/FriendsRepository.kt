package com.rani.tofy.kid.ui.social

import android.content.Context
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.firebase.firestore.AggregateSource
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.Query
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.data.Doc
import com.rani.tofy.data.bool
import com.rani.tofy.data.int
import com.rani.tofy.data.nowSecs
import com.rani.tofy.data.secs
import com.rani.tofy.data.str
import com.rani.tofy.data.strList
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/**
 * friendCards/{childID} — FriendsManager.swift's FriendCard. A child's PUBLIC
 * mini-card: first name, character, stars, friend code. Nothing else.
 */
data class FriendCard(
    val id: String,
    val name: String,
    val character3DID: String?,
    val stars: Int,
    val code: String,
    val ownerUID: String = "",
    val friendIDs: List<String> = emptyList(),
    val hiddenIDs: List<String> = emptyList(),
    val updatedAt: Double = 0.0,
    val demo: Boolean = false,
    /** nil = Hebrew (older cards). */
    val language: String? = null,
) {
    val displayName: String get() = publicName(name)

    companion object {
        /** 🔒 FriendCard.publicName — the first word only; a surname never leaves the family. */
        fun publicName(name: String): String = name.trim().split(Regex("\\s+")).firstOrNull().orEmpty()

        /** The tolerant iOS decode: any missing field falls back (only `id` is required). */
        fun from(d: Doc?): FriendCard? {
            if (d.isNullOrEmpty()) return null
            val id = d.str("id") ?: return null
            return FriendCard(
                id = id, name = d.str("name") ?: "", character3DID = d.str("character3DID"),
                stars = d.int("stars") ?: 0, code = d.str("code") ?: "", ownerUID = d.str("ownerUID") ?: "",
                friendIDs = d.strList("friendIDs") ?: emptyList(), hiddenIDs = d.strList("hiddenIDs") ?: emptyList(),
                updatedAt = d.secs("updatedAt") ?: 0.0, demo = d.bool("demo") ?: false, language = d.str("language"),
            )
        }
    }
}

/** friendCards/{toID}/requests/{fromID} — one pending request per sender. */
data class FriendRequest(
    val id: String,
    val fromID: String,
    val name: String,
    val character3DID: String?,
    val stars: Int,
    val requesterUID: String,
    val createdAt: Double,
) {
    val displayName: String get() = FriendCard.publicName(name)

    companion object {
        fun from(d: Doc?): FriendRequest? {
            if (d.isNullOrEmpty()) return null
            val from = d.str("fromID") ?: ""
            return FriendRequest(d.str("id") ?: from, from, d.str("name") ?: "", d.str("character3DID"),
                d.int("stars") ?: 0, d.str("requesterUID") ?: "", d.secs("createdAt") ?: 0.0)
        }
    }
}

/** FriendLink.swift — the https link in the QR, and pulling a bare code back out of anything scanned. */
object FriendLink {
    const val HOST = "tofyapp.com"
    fun url(code: String) = "https://$HOST/friend?f=${Uri.encode(code)}"
    fun code(scanned: String): String {
        val s = scanned.trim()
        val u = runCatching { Uri.parse(s) }.getOrNull()
        if (u != null && !u.scheme.isNullOrEmpty()) u.getQueryParameter("f")?.takeIf { it.isNotEmpty() }?.let { return it }
        return s
    }
}

/**
 * FriendsManager.swift — the kid friends leaderboard. Each child keeps a public
 * friendCards/{childID}; friendship is mutual-by-union (A lists B → both see
 * each other); removal hides the edge on the remover's side. Every device writes
 * ONLY its own card (+ request docs it sends), exactly like iOS.
 */
@OptIn(FlowPreview::class)
object FriendsRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private fun cards() = db.collection("friendCards")

    /** Me + my friends, stars descending. */
    var leaderboard by mutableStateOf<List<FriendCard>>(emptyList()); private set
    var globalBoard by mutableStateOf<List<FriendCard>>(emptyList()); private set
    var myGlobalRank by mutableStateOf<Int?>(null); private set
    var isLoadingGlobal by mutableStateOf(false); private set
    var myCode by mutableStateOf(""); private set
    var lastError by mutableStateOf<String?>(null)
    /** An incoming friend link waiting for the board (FriendsManager.pendingFriendCode). */
    var pendingFriendCode by mutableStateOf<String?>(null)
    var lastAddedFriend by mutableStateOf<FriendCard?>(null)
    var incomingRequests by mutableStateOf<List<FriendRequest>>(emptyList()); private set
    var outgoingRequestIDs by mutableStateOf<Set<String>>(emptySet()); private set

    private var prefs: android.content.SharedPreferences? = null
    fun init(context: Context) {
        if (prefs == null) prefs = context.applicationContext.getSharedPreferences("tofy.friends", Context.MODE_PRIVATE)
    }

    // MARK: my code

    /** codeForActiveChild: the first 6 UUID bytes → an unambiguous alphabet. Same code every launch. */
    fun codeFor(childID: String?): String {
        val id = childID ?: return ""
        val alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        val hex = id.replace("-", "")
        if (hex.length < 12) return ""
        return buildString {
            for (i in 0 until 12 step 2) append(alphabet[(hex.substring(i, i + 2).toIntOrNull(16) ?: 0) % alphabet.length])
        }
    }

    // MARK: public API

    suspend fun refresh() {
        val id = SocialMe.id ?: return
        myCode = codeFor(id)
        if (!SocialMe.isSignedIn) return
        upsertMyCard(id)
        loadLeaderboard(id)
    }

    /** Add by code (typed, scanned or from a link) — instant, mutual-by-union. */
    suspend fun addFriend(raw: String): Boolean {
        val myID = SocialMe.id ?: run { lastError = tr("אֵין פְּרוֹפִיל פָּעִיל"); return false }
        if (!SocialMe.isSignedIn) { lastError = tr("צָרִיךְ לְהִתְחַבֵּר לְחֶשְׁבּוֹן כְּדֵי לְהוֹסִיף חֲבֵרִים"); return false }
        if (myCode.isEmpty()) myCode = codeFor(myID)
        val code = FriendLink.code(raw).uppercase()
        if (code.isEmpty() || code == myCode) {
            lastError = if (code == myCode) SocialMe.g(tr("זֶה הַקּוֹד שֶׁלְּךָ 🙂"), tr("זֶה הַקּוֹד שֶׁלָּךְ 🙂")) else tr("קוֹד לֹא תָּקִין")
            return false
        }
        return try {
            val snap = cards().whereEqualTo("code", code).limit(1).get().await()
            val card = snap.documents.firstOrNull()?.data?.let { FriendCard.from(it) }
            if (card == null) { lastError = tr("לֹא מָצָאנוּ חָבֵר עִם הַקּוֹד הַזֶּה"); return false }
            if (card.id == myID) { lastError = SocialMe.g(tr("זֶה אַתָּה 🙂"), tr("זוֹ אַתְּ 🙂")); return false }
            cards().document(myID).set(mapOf(
                "ownerUID" to (SocialMe.uid ?: ""),
                "friendIDs" to FieldValue.arrayUnion(card.id),
                "hiddenIDs" to FieldValue.arrayRemove(card.id),
            ), SetOptions.merge()).await()
            lastError = null
            lastAddedFriend = card
            loadLeaderboard(myID)
            true
        } catch (e: Exception) {
            lastError = e.localizedMessage
            false
        }
    }

    /** Remove a friend from THIS child's board (hides the edge on my side). */
    suspend fun removeFriend(friendID: String, forChild: String? = null) {
        val id = forChild ?: SocialMe.id ?: return
        runCatching {
            cards().document(id).set(mapOf(
                "friendIDs" to FieldValue.arrayRemove(friendID),
                "hiddenIDs" to FieldValue.arrayUnion(friendID),
            ), SetOptions.merge()).await()
        }
        if (id == SocialMe.id) loadLeaderboard(id)
    }

    /** A PENDING request to someone found on a board — they accept from their inbox. */
    suspend fun sendRequest(card: FriendCard): Boolean {
        val myID = SocialMe.id ?: run { lastError = tr("אֵין פְּרוֹפִיל פָּעִיל"); return false }
        if (!SocialMe.isSignedIn) { lastError = tr("צָרִיךְ לְהִתְחַבֵּר לְחֶשְׁבּוֹן כְּדֵי לִשְׁלוֹחַ בַּקָּשָׁה"); return false }
        if (card.id == myID) { lastError = SocialMe.g(tr("זֶה אַתָּה 🙂"), tr("זוֹ אַתְּ 🙂")); return false }
        if (isFriend(card.id)) { lastError = tr("אַתֶּם כְּבָר חֲבֵרִים 🙂"); return false }
        // JSONEncoder.firestore(FriendRequest): nil character3DID is omitted, createdAt = epoch seconds.
        val req = mutableMapOf<String, Any>(
            "id" to myID, "fromID" to myID, "name" to FriendCard.publicName(SocialMe.name),
            "stars" to SocialMe.stars, "requesterUID" to (SocialMe.uid ?: ""), "createdAt" to nowSecs(),
        )
        SocialMe.character3DID?.let { req["character3DID"] = it }
        return try {
            cards().document(card.id).collection("requests").document(myID).set(req, SetOptions.merge()).await()
            outgoingRequestIDs = outgoingRequestIDs + card.id
            lastError = null
            true
        } catch (e: Exception) {
            lastError = e.localizedMessage
            false
        }
    }

    suspend fun acceptRequest(req: FriendRequest) {
        val myID = SocialMe.id ?: return
        try {
            cards().document(myID).set(mapOf(
                "ownerUID" to (SocialMe.uid ?: ""),
                "friendIDs" to FieldValue.arrayUnion(req.fromID),
                "hiddenIDs" to FieldValue.arrayRemove(req.fromID),
            ), SetOptions.merge()).await()
            lastAddedFriend = FriendCard(req.fromID, req.name, req.character3DID, req.stars, "")
            runCatching { cards().document(myID).collection("requests").document(req.fromID).delete().await() }
            loadLeaderboard(myID)
            refilterRequests()
        } catch (_: Exception) { }
    }

    /** Just clear the inbox doc — no edge, and the sender isn't told. */
    suspend fun declineRequest(req: FriendRequest) {
        val myID = SocialMe.id ?: return
        runCatching { cards().document(myID).collection("requests").document(req.fromID).delete().await() }
        rawIncoming = rawIncoming.filter { it.fromID != req.fromID }
        refilterRequests()
    }

    suspend fun hasOutgoingRequest(to: String): Boolean {
        val myID = SocialMe.id ?: return false
        if (to in outgoingRequestIDs) return true
        val doc = runCatching { cards().document(to).collection("requests").document(myID).get().await() }.getOrNull()
        if (doc?.exists() == true) { outgoingRequestIDs = outgoingRequestIDs + to; return true }
        return false
    }

    fun isFriend(id: String) = leaderboard.any { it.id == id }

    // MARK: live

    private var myCardReg: ListenerRegistration? = null
    private var inboundReg: ListenerRegistration? = null
    private var requestsReg: ListenerRegistration? = null
    private val friendRegs = HashMap<String, ListenerRegistration>()
    private val cardCache = HashMap<String, FriendCard>()
    private var rawIncoming: List<FriendRequest> = emptyList()
    private var liveUsers = 0

    /** startLive: upsert my card, then listen (my card, who-added-me, my inbox, each friend). Ref-counted for nested sheets. */
    suspend fun startLive() {
        liveUsers++
        val id = SocialMe.id ?: return
        if (!SocialMe.isSignedIn) return
        myCode = codeFor(id)
        upsertMyCard(id)
        beginScoreSync()
        if (liveUsers == 0 || myCardReg != null) return   // the screen already left while we upserted
        myCardReg = cards().document(id).addSnapshotListener { snap, _ ->
            FriendCard.from(snap?.data)?.let { cardCache[id] = it }
            rebuild(id)
        }
        inboundReg = cards().whereArrayContains("friendIDs", id).addSnapshotListener { snap, _ ->
            snap?.documents?.forEach { d -> FriendCard.from(d.data)?.let { cardCache[d.id] = it } }
            rebuild(id)
        }
        requestsReg = cards().document(id).collection("requests").addSnapshotListener { snap, _ ->
            rawIncoming = snap?.documents.orEmpty().mapNotNull { FriendRequest.from(it.data) }.filter { it.fromID != id }
            refilterRequests()
        }
    }

    fun stopLive() {
        liveUsers = maxOf(0, liveUsers - 1)
        if (liveUsers > 0) return
        myCardReg?.remove(); myCardReg = null
        inboundReg?.remove(); inboundReg = null
        requestsReg?.remove(); requestsReg = null
        friendRegs.values.forEach { it.remove() }; friendRegs.clear()
    }

    private fun refilterRequests() {
        val ids = leaderboard.map { it.id }.toSet()
        incomingRequests = rawIncoming.filter { it.fromID !in ids }.sortedByDescending { it.createdAt }
    }

    private fun friendSet(myID: String): Set<String> {
        val me = cardCache[myID] ?: return emptySet()
        val ids = me.friendIDs.toMutableSet()
        for ((fid, c) in cardCache) if (myID in c.friendIDs) ids += fid
        ids -= me.hiddenIDs.toSet(); ids -= myID
        return ids
    }

    private fun rebuild(myID: String) {
        if (cardCache[myID] == null) return
        val ids = friendSet(myID)
        for (fid in ids) if (friendRegs[fid] == null) {
            friendRegs[fid] = cards().document(fid).addSnapshotListener { snap, _ ->
                FriendCard.from(snap?.data)?.let { cardCache[fid] = it; publish(myID) }
            }
        }
        for (fid in friendRegs.keys.toList()) if (fid !in ids) friendRegs.remove(fid)?.remove()
        publish(myID)
    }

    private fun publish(myID: String) {
        val me = cardCache[myID]?.copy(stars = SocialMe.stars) ?: return   // my row = my LIVE local stars
        val out = mutableListOf(me)
        for (fid in friendSet(myID)) cardCache[fid]?.let { out += it }
        leaderboard = out.sortedByDescending { it.stars }
        refilterRequests()
    }

    // MARK: score sync

    private var scoreSync: Job? = null

    /** beginScoreSync: keep my PUBLIC card's stars fresh while I play (debounced 2.5 s; only once a card exists). */
    fun beginScoreSync() {
        if (scoreSync != null) return
        scoreSync = scope.launch {
            KidSession.state.map { it?.snapshot?.stars }.distinctUntilChanged().drop(1).debounce(2500).collect {
                val id = SocialMe.id ?: return@collect
                if (!SocialMe.isSignedIn || !cardExists(id)) return@collect
                upsertMyCard(id)
            }
        }
    }

    private fun cardExists(id: String) = prefs?.getBoolean("friendCard.exists.$id", false) ?: false
    private fun markCardExists(id: String) { prefs?.edit()?.putBoolean("friendCard.exists.$id", true)?.apply() }

    /** Only the card facts — never friendIDs/hiddenIDs (we may not have loaded them). */
    private suspend fun upsertMyCard(id: String) {
        if (!SocialMe.friendsEnabled) return   // the parent switched friends off — publish nothing
        if (myCode.isEmpty()) myCode = codeFor(id)
        val fields = mutableMapOf<String, Any>(
            "id" to id, "name" to FriendCard.publicName(SocialMe.name), "stars" to SocialMe.stars,
            "code" to myCode, "ownerUID" to (SocialMe.uid ?: ""), "updatedAt" to nowSecs(),
            "demo" to false, "language" to SocialMe.language,
        )
        SocialMe.character3DID?.let { fields["character3DID"] = it }
        runCatching {
            cards().document(id).set(fields, SetOptions.merge()).await()
            markCardExists(id)
        }
    }

    private suspend fun loadLeaderboard(myID: String) {
        val me = runCatching { cards().document(myID).get().await() }.getOrNull()?.data?.let { FriendCard.from(it) } ?: return
        val ids = me.friendIDs.toMutableSet()
        runCatching { cards().whereArrayContains("friendIDs", myID).get().await() }.getOrNull()?.documents?.forEach { ids += it.id }
        ids -= me.hiddenIDs.toSet(); ids -= myID
        val out = mutableListOf(me)
        for (fid in ids) runCatching { cards().document(fid).get().await() }.getOrNull()?.data?.let { FriendCard.from(it) }?.let { out += it }
        leaderboard = out.sortedByDescending { it.stars }
    }

    // MARK: global board

    /** One board per language: Hebrew keeps the original query (older cards have no field). */
    private fun languageBase(): Query =
        if (SocialMe.language == "he") cards() else cards().whereEqualTo("language", SocialMe.language)

    suspend fun loadGlobal() {
        if (!SocialMe.isSignedIn) return
        isLoadingGlobal = true
        try {
            SocialMe.id?.let { upsertMyCard(it) }
            val lang = SocialMe.language
            val snap = languageBase().orderBy("stars", Query.Direction.DESCENDING).limit(100).get().await()
            var list = snap.documents.mapNotNull { FriendCard.from(it.data) }.filter { !it.demo && (it.language ?: "he") == lang }
            val myStars = SocialMe.stars
            val id = SocialMe.id
            if (id != null && list.any { it.id == id }) {
                list = list.map { if (it.id == id) it.copy(stars = myStars) else it }.sortedByDescending { it.stars }
            }
            globalBoard = list
            computeMyGlobalRank(myStars)
        } catch (_: Exception) {
        } finally { isLoadingGlobal = false }
    }

    /** (players with strictly more stars) + 1 — a count aggregation, exact even outside the top 100. */
    private suspend fun computeMyGlobalRank(myStars: Int) {
        val id = SocialMe.id ?: run { myGlobalRank = null; return }
        myGlobalRank = try {
            languageBase().whereGreaterThan("stars", myStars).count().get(AggregateSource.SERVER).await().count.toInt() + 1
        } catch (_: Exception) {
            globalBoard.indexOfFirst { it.id == id }.takeIf { it >= 0 }?.plus(1)
        }
    }

    /** friends(ofChild:) — for the PARENT (see + remove): their adds + who added them, minus hidden. */
    suspend fun friendsOf(childID: String): List<FriendCard> {
        val ids = mutableSetOf<String>()
        runCatching { cards().document(childID).get().await() }.getOrNull()?.data?.let { FriendCard.from(it) }?.let {
            ids += it.friendIDs; ids -= it.hiddenIDs.toSet()
        }
        runCatching { cards().whereArrayContains("friendIDs", childID).get().await() }.getOrNull()?.documents?.forEach { ids += it.id }
        ids -= childID
        return ids.mapNotNull { fid -> runCatching { cards().document(fid).get().await() }.getOrNull()?.data?.let { FriendCard.from(it) } }
            .sortedByDescending { it.stars }
    }

    /** One player's public card (the live-game player peek). */
    suspend fun card(id: String): FriendCard? =
        runCatching { cards().document(id).get().await() }.getOrNull()?.data?.let { FriendCard.from(it) }
}
