package com.rani.tofy.ui.theme

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 📷 Six photos of their own, and how a child's second device follows the set (BackdropTests.swift). */
class BackdropPhotoSetTest {
    @Test fun sixPhotoPlacesAndTheFirstIsTheOldOne() {
        assertEquals(listOf("photo", "photo-2", "photo-3", "photo-4", "photo-5", "photo-6"), BackdropTheme.PHOTOS)
        assertTrue(BackdropTheme.isPhoto("photo") && BackdropTheme.isPhoto("photo-6"))
        assertFalse(BackdropTheme.isPhoto("photo-7") || BackdropTheme.isPhoto("sea") || BackdropTheme.isPhoto(null))
        assertEquals("ABC", BackdropStore.slotKey("ABC", "photo"))
        assertEquals("ABC-3", BackdropStore.slotKey("ABC", "photo-3"))
    }

    @Test fun aSecondDeviceFollowsThePhotoSet() {
        val plan = BackdropStore.photoSetPlan(
            cloud = mapOf("photo" to 100.0, "photo-2" to 300.0, "photo-3" to 50.0, "bogus" to 9.0),
            removed = mapOf("photo-4" to 200.0, "photo-5" to 10.0),
            local = mapOf("photo" to 100.0, "photo-2" to 200.0, "photo-4" to 150.0, "photo-5" to 40.0, "photo-6" to 500.0))
        assertEquals(listOf("photo-3", "photo-2"), plan.fetch.map { it.first })   // missing here, then older here
        assertEquals(listOf("photo-4"), plan.drop)                                // removed after this copy was made
        val untouched = BackdropStore.photoSetPlan(emptyMap(), emptyMap(), mapOf("photo" to 5.0))
        assertTrue(untouched.fetch.isEmpty() && untouched.drop.isEmpty())         // an old build's photo, no index yet
    }
}
