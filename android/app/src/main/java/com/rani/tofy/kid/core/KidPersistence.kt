package com.rani.tofy.kid.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.longOrNull

/*
 * Local persistence of one child's engine state (iOS keeps it in UserDefaults /
 * ProgressVault). Pure JSON — no Android types — so it is unit-testable.
 *
 * PUBLIC API
 *   KidPersistence.encode(snapshot, local): String
 *   KidPersistence.decode(json): Pair<ProgressSnapshot, LocalPlayState>?   (null on garbage)
 * The snapshot part reuses the Firestore codec, so it stays resilient to
 * missing/renamed keys exactly like the cloud copy.
 */
object KidPersistence {
    private val json = Json { ignoreUnknownKeys = true }

    fun encode(snapshot: ProgressSnapshot, local: LocalPlayState): String {
        val root = mapOf(
            "v" to 1,
            "snapshot" to snapshot.toFirestore(),
            "local" to mapOf(
                "baseRevision" to local.baseRevision,
                "unlockEndsAt" to local.unlockEndsAt,
                "unlockIsManual" to local.unlockIsManual,
                "unlockGrantedSeconds" to local.unlockGrantedSeconds,
                "unlockStartedAt" to local.unlockStartedAt,
                "unlockStartedUptime" to local.unlockStartedUptime,
                "unlockKind" to local.unlockKind,
                "activeLeaseID" to local.activeLeaseID,
                "manualPausedSeconds" to local.manualPausedSeconds,
                "pendingBonusWheel" to local.pendingBonusWheel,
                "topicAnsweredToday" to local.topicAnsweredToday,
                "topicAnsweredDate" to local.topicAnsweredDate,
                "bonusQuestionServedAt" to local.bonusQuestionServedAt,
                "ownedCosmetics" to local.ownedCosmetics.toList(),
                "equippedCosmetic" to local.equippedCosmetic,
            ),
        )
        return toJson(root).toString()
    }

    @Suppress("UNCHECKED_CAST")
    fun decode(text: String): Pair<ProgressSnapshot, LocalPlayState>? {
        val root = runCatching { fromJson(json.parseToJsonElement(text)) as? Map<String, Any?> }.getOrNull() ?: return null
        val snap = (root["snapshot"] as? Map<String, Any?>)?.let { ProgressSnapshot.fromFirestore(it) } ?: return null
        val l = root["local"] as? Map<String, Any?> ?: emptyMap()
        fun int(k: String) = (l[k] as? Number)?.toInt()
        fun dbl(k: String) = (l[k] as? Number)?.toDouble()
        val local = LocalPlayState(
            baseRevision = int("baseRevision") ?: 0,
            unlockEndsAt = dbl("unlockEndsAt"),
            unlockIsManual = l["unlockIsManual"] as? Boolean ?: false,
            unlockGrantedSeconds = int("unlockGrantedSeconds") ?: 0,
            unlockStartedAt = dbl("unlockStartedAt"),
            unlockStartedUptime = dbl("unlockStartedUptime") ?: 0.0,
            unlockKind = l["unlockKind"] as? String ?: "earned",
            activeLeaseID = l["activeLeaseID"] as? String,
            manualPausedSeconds = int("manualPausedSeconds") ?: 0,
            pendingBonusWheel = l["pendingBonusWheel"] as? Boolean ?: false,
            topicAnsweredToday = (l["topicAnsweredToday"] as? Map<String, Any?>)
                ?.mapNotNull { (k, v) -> (v as? Number)?.let { k to it.toInt() } }?.toMap() ?: emptyMap(),
            topicAnsweredDate = dbl("topicAnsweredDate"),
            bonusQuestionServedAt = dbl("bonusQuestionServedAt"),
            ownedCosmetics = (l["ownedCosmetics"] as? List<*>)?.filterIsInstance<String>()?.toSet() ?: emptySet(),
            equippedCosmetic = l["equippedCosmetic"] as? String,
        )
        return snap to local
    }

    internal fun toJson(v: Any?): JsonElement = when (v) {
        null -> JsonNull
        is Boolean -> JsonPrimitive(v)
        is Number -> JsonPrimitive(v)
        is String -> JsonPrimitive(v)
        is Map<*, *> -> JsonObject(v.entries.associate { it.key.toString() to toJson(it.value) })
        is Iterable<*> -> JsonArray(v.map { toJson(it) })
        else -> JsonPrimitive(v.toString())
    }

    internal fun fromJson(e: JsonElement): Any? = when (e) {
        is JsonNull -> null
        is JsonPrimitive -> if (e.isString) e.content else e.booleanOrNull ?: e.longOrNull ?: e.doubleOrNull
        is JsonObject -> e.mapValues { fromJson(it.value) }
        is JsonArray -> e.map { fromJson(it) }
    }
}
