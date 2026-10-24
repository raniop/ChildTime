package com.rani.tofy.ui.home

import com.rani.tofy.data.Progress
import org.junit.Assert.assertEquals
import org.junit.Test

/** 🎮 The child card's wallet: a line each, each only when it is > 0 (Rani, 2026-10-24). */
class WalletLinesTest {
    @Test fun aLineEachOnlyWhenThereIsSomething() {
        assertEquals(emptyList<String>(), walletLines(Progress.EMPTY, girl = true))
        val both = walletLines(Progress.EMPTY.copy(earnedSecondsAvailable = 12 * 60 + 30, giftMinutes = 10), girl = true)
        assertEquals(listOf("🎮 12 דקות שהרוויחה ועוד לא פתחה", "💝 10 דקות מתנה"), both)
        assertEquals(listOf("💝 5 דקות מתנה"), walletLines(Progress.EMPTY.copy(giftMinutes = 5), girl = false))
        assertEquals(listOf("🎮 3 דקות שהרוויח ועוד לא פתח"), walletLines(Progress.EMPTY.copy(earnedSecondsAvailable = 200), girl = false))
    }
}
