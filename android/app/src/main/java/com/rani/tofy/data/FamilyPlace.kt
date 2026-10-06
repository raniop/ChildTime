package com.rani.tofy.data

import java.util.UUID
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/*
 * 📍 A fixed place the parents marked (home, school, a club) — the twin of
 * iOS FamilyPlace.swift. Lives on the household: households/{id}.places, a
 * list of { id, name, emoji, lat, lng, radius, alerts: { childID: { arrive, leave } } }.
 */
data class PlaceAlert(val arrive: Boolean, val leave: Boolean)

data class FamilyPlace(
    val id: String = UUID.randomUUID().toString().uppercase(),
    val name: String,
    val emoji: String = "📍",
    val lat: Double,
    val lng: Double,
    /** Meters. */
    val radius: Double = 200.0,
    val alerts: Map<String, PlaceAlert> = emptyMap(),
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id, "name" to name, "emoji" to emoji, "lat" to lat, "lng" to lng, "radius" to radius,
        "alerts" to alerts.mapValues { (_, a) -> mapOf("arrive" to a.arrive, "leave" to a.leave) },
    )

    fun contains(lat: Double, lng: Double) = meters(lat, lng, this.lat, this.lng) <= radius

    companion object {
        val RADII = listOf(100.0, 200.0, 400.0)

        /** Great-circle distance in meters (haversine). */
        fun meters(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
            val r = 6_371_000.0
            val dLat = Math.toRadians(lat2 - lat1); val dLng = Math.toRadians(lng2 - lng1)
            val a = sin(dLat / 2) * sin(dLat / 2) +
                cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2)
            return 2 * r * atan2(sqrt(a), sqrt(1 - a))
        }

        /** The place a point is in — the nearest centre when fences overlap. */
        fun at(lat: Double, lng: Double, places: List<FamilyPlace>): FamilyPlace? =
            places.filter { it.contains(lat, lng) }.minByOrNull { meters(lat, lng, it.lat, it.lng) }

        fun from(d: Doc?): FamilyPlace? {
            d ?: return null
            val id = d.str("id") ?: return null
            return FamilyPlace(
                id = id, name = d.str("name") ?: "", emoji = d.str("emoji") ?: "📍",
                lat = d.dbl("lat") ?: return null, lng = d.dbl("lng") ?: return null,
                radius = d.dbl("radius") ?: 200.0,
                alerts = d.map("alerts")?.mapNotNull { (k, v) ->
                    @Suppress("UNCHECKED_CAST") val m = v as? Map<String, Any?> ?: return@mapNotNull null
                    k to PlaceAlert(m.bool("arrive") ?: false, m.bool("leave") ?: false)
                }?.toMap() ?: emptyMap(),
            )
        }

        @Suppress("UNCHECKED_CAST")
        fun list(raw: Any?): List<FamilyPlace> =
            (raw as? List<*>)?.mapNotNull { from(it as? Map<String, Any?>) } ?: emptyList()
    }
}

/** The child's last fix as the parent reads it (children/{id}/location/current). */
data class ChildLocationFix(
    val lat: Double?, val lng: Double?, val accuracy: Double, val at: Double,
    val battery: Double?, val placeID: String?, val placeSince: Double?, val permission: String?,
) {
    val hasFix: Boolean get() = lat != null && lng != null
}
