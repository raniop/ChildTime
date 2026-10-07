package com.rani.tofy.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Port of FamilyPlaceTests.swift — fences, nearest wins, the Firestore shape both ways. */
class FamilyPlaceTest {
    private val school = FamilyPlace(id = "s", name = "בית הספר", emoji = "🏫", lat = 32.0800, lng = 34.7800, radius = 200.0)
    private val home = FamilyPlace(id = "h", name = "הבית", emoji = "🏠", lat = 32.0815, lng = 34.7800, radius = 200.0)

    @Test fun distanceIsInMeters() {
        assertEquals(111.0, FamilyPlace.meters(32.0800, 34.78, 32.0810, 34.78), 2.0)
    }

    @Test fun insideAndOutside() {
        assertTrue(school.contains(32.0805, 34.7800))
        assertFalse(school.contains(32.0830, 34.7800))
    }

    @Test fun overlappingPlacesPickTheNearest() {
        assertEquals("h", FamilyPlace.at(32.0811, 34.7800, listOf(school, home))?.id)
        assertNull(FamilyPlace.at(32.1, 34.9, listOf(school, home)))
    }

    @Test fun indoorFixStillCountsAsHome() {
        val home50 = FamilyPlace(id = "h", name = "הבית", lat = 32.0800, lng = 34.7800, radius = 50.0)
        assertNull(FamilyPlace.at(32.0807, 34.7800, listOf(home50)))
        assertEquals("h", FamilyPlace.at(32.0807, 34.7800, listOf(home50), 40.0)?.id)
        assertNull(FamilyPlace.at(32.0830, 34.7800, listOf(home50), 500.0))
    }

    @Test fun firestoreRoundTrip() {
        val p = school.copy(alerts = mapOf("kid" to PlaceAlert(arrive = true, leave = false)))
        assertEquals(listOf(p), FamilyPlace.list(listOf(p.toMap())))
        assertEquals(emptyList<FamilyPlace>(), FamilyPlace.list(null))
    }
}
