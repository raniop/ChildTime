package com.rani.tofy.ui.home

import com.rani.tofy.data.Child
import com.rani.tofy.data.ChildDevice
import com.rani.tofy.data.FamilyState
import com.rani.tofy.data.nowSecs

/** An open play window — liveWindow() in ParentDashboardView.swift. */
data class LiveWindow(val secondsLeft: Int, val device: ChildDevice?, val isGift: Boolean)

/** The lease first (server-stamped, can't lag), then the device row's report. */
fun FamilyState.liveWindow(child: Child, now: Double = nowSecs()): LiveWindow? {
    val rows = devicesOf(child.id)
    leases[child.id]?.let { l ->
        if (l.isHeld && !l.isExpired(now)) {
            val left = l.remainingSeconds(now)
            if (left > 0) return LiveWindow(left, rows.firstOrNull { it.deviceID == l.ownerDeviceID } ?: rows.firstOrNull(), l.kind != "earned")
        }
    }
    rows.mapNotNull { d -> d.windowEndsAt?.let { e -> (e - now).toInt().takeIf { it > 0 }?.let { LiveWindow(it, d, d.windowIsManual == true) } } }
        .maxByOrNull { it.secondsLeft }?.let { return it }
    return null
}

/** In Tofy right now — a device heartbeat within 45 s. */
fun FamilyState.isInAppNow(child: Child, now: Double = nowSecs()) = devicesOf(child.id).any { now - it.lastSeenAt < 45 }

fun FamilyState.hasDevice(child: Child) = devicesOf(child.id).isNotEmpty()

fun formatTime(seconds: Int): String = "%d:%02d".format(seconds / 60, seconds % 60)
