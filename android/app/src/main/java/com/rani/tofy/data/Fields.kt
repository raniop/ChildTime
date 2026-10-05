package com.rani.tofy.data

import com.google.firebase.Timestamp

/**
 * iOS writes every model through JSONEncoder → JSONSerialization, so Firestore
 * holds Codable property names as keys, Dates as epoch-seconds Doubles and Data
 * as base64 strings. Server-written fields may still be real Timestamps — read
 * both, always WRITE plain numbers (the iOS decoder chokes on a Timestamp).
 */
typealias Doc = Map<String, Any?>

fun Doc.str(k: String): String? = this[k] as? String
fun Doc.int(k: String): Int? = (this[k] as? Number)?.toInt()
fun Doc.dbl(k: String): Double? = (this[k] as? Number)?.toDouble()
fun Doc.bool(k: String): Boolean? = this[k] as? Boolean

/** Epoch seconds, whether stored as a number or a Firestore Timestamp. */
fun Doc.secs(k: String): Double? = when (val v = this[k]) {
    is Number -> v.toDouble()
    is Timestamp -> v.seconds + v.nanoseconds / 1e9
    else -> null
}

@Suppress("UNCHECKED_CAST")
fun Doc.strList(k: String): List<String>? = (this[k] as? List<*>)?.filterIsInstance<String>()

@Suppress("UNCHECKED_CAST")
fun Doc.map(k: String): Doc? = this[k] as? Map<String, Any?>

fun nowSecs(): Double = System.currentTimeMillis() / 1000.0

/**
 * children/{id}/state/current is the ONE document iOS encodes with a plain
 * JSONEncoder (ProgressSnapshot.toFirestore) — so its Dates are seconds since
 * 2001-01-01 (Apple's reference date), NOT unix. Read and write them through
 * these, or an Android write lands decades in the future and wins every
 * last-write-wins merge on every iOS device.
 */
const val APPLE_EPOCH_OFFSET = 978307200.0

/** A state/current Date field, as unix seconds. */
fun Doc.appleSecs(k: String): Double? = dbl(k)?.plus(APPLE_EPOCH_OFFSET)

/** "Now" in state/current's own Date encoding. */
fun nowAppleSecs(): Double = nowSecs() - APPLE_EPOCH_OFFSET
