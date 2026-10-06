package com.rani.tofy.data

/** households/{hid} — mirrors Household.swift. */
data class Household(
    val id: String,
    val parentUIDs: List<String>,
    val childIDs: List<String>,
    val createdBy: String,
    val familyName: String?,
    val parentNames: Map<String, String>,
    val childOrder: List<String>?,
    val parentPinHash: String?,
    val premiumUntil: Double?,
    val premiumSource: String?,
    val giftUntil: Double?,
    val choresMoneyEnabled: Boolean?,
    val ownedPacks: List<String>,
    /** 📍 The family's fixed places (FamilyPlace.kt). */
    val places: List<FamilyPlace> = emptyList(),
) {
    val isPremium: Boolean get() = (premiumUntil ?: 0.0) > nowSecs()

    companion object {
        fun from(id: String, d: Doc) = Household(
            id = id,
            parentUIDs = d.strList("parentUIDs") ?: emptyList(),
            childIDs = d.strList("childIDs") ?: emptyList(),
            createdBy = d.str("createdBy") ?: "",
            familyName = d.str("familyName")?.takeIf { it.isNotBlank() },
            parentNames = d.map("parentNames")?.mapNotNull { (k, v) -> (v as? String)?.let { k to it } }?.toMap() ?: emptyMap(),
            childOrder = d.strList("childOrder"),
            parentPinHash = d.str("parentPinHash"),
            premiumUntil = d.secs("premiumUntil"),
            premiumSource = d.str("premiumSource"),
            giftUntil = d.secs("giftUntil"),
            choresMoneyEnabled = d.bool("choresMoneyEnabled"),
            ownedPacks = d.strList("ownedPacks") ?: emptyList(),
            places = FamilyPlace.list(d["places"]),
        )
    }
}

/** children/{childUUID} — mirrors ChildRecord.swift (the fields the parent app uses). */
data class Child(
    val id: String,
    val householdID: String,
    val name: String,
    val age: Int,
    val gender: String?,
    val avatarPresetID: String,
    val character3DID: String?,
    val grade: Int?,
    val photoBase64: String?,
    val dailyCapMinutes: Int?,
    val difficultyByTopic: Map<String, String>,
    val enabledTopics: List<String>?,
    val language: String?,
    val playPIN: String?,
    val onlyRegularQuestions: Boolean,
    /** 🏫🌙 School time + bedtime (QuietHours.kt); null = never set. */
    val quietHours: QuietHours?,
    val packs: List<String>,
    val createdAt: Double,
    val raw: Doc,
) {
    val isGirl: Boolean get() = gender == "girl"

    /** Profile.effectiveGrade: the set grade auto-advanced each September, else from the age bracket. */
    val effectiveGrade: Int
        get() {
            val g = grade
            if (g != null && g in -1..12) {
                val advance = maxOf(0, schoolYear() - (raw.int("gradeSchoolYear") ?: schoolYear()))
                return minOf(12, g + advance)
            }
            return when (age) { 4 -> 0; 6 -> 1; 8 -> 3; else -> 5 }
        }

    companion object {
        fun from(id: String, d: Doc) = Child(
            id = id,
            householdID = d.str("householdID") ?: "",
            name = d.str("name") ?: "",
            age = d.int("age") ?: 8,
            gender = d.str("gender"),
            avatarPresetID = d.str("avatarPresetID") ?: "fox",
            character3DID = d.str("character3DID"),
            grade = d.int("grade"),
            photoBase64 = d.str("photoData"),
            dailyCapMinutes = d.int("dailyCapMinutes"),
            difficultyByTopic = d.map("difficultyByTopic")?.mapNotNull { (k, v) -> (v as? String)?.let { k to it } }?.toMap() ?: emptyMap(),
            enabledTopics = d.strList("enabledTopics"),
            language = d.str("language"),
            playPIN = d.str("playPIN"),
            onlyRegularQuestions = d.bool("onlyRegularQuestions") ?: false,
            quietHours = QuietHours.from(d.map("quietHours")),
            packs = d.strList("packs") ?: emptyList(),
            createdAt = d.secs("createdAt") ?: 0.0,
            raw = d,
        )
    }
}

/** children/{id}/state/current — the subset of ProgressSnapshot the parent shows. Dates here are Apple-reference (see Fields.kt). */
data class Progress(
    val answeredToday: Int,
    val correctToday: Int,
    val minutesEarnedToday: Int,
    val dailyEarnedDate: Double?,
    val stars: Int,
    val diamonds: Int,
    val dayStreak: Int,
    val totalAnswered: Int,
    val totalCorrect: Int,
    val earnedSecondsAvailable: Int,
    val giftSecondsAvailable: Int,
    val topicAccuracy: Map<String, Double>,
    val topicAnswered: Map<String, Int>,
    val lastModifiedAt: Double?,
) {
    companion object {
        val EMPTY = Progress(0, 0, 0, null, 0, 0, 0, 0, 0, 0, 0, emptyMap(), emptyMap(), null)

        fun from(d: Doc): Progress {
            // "Today" counters only mean today if the child's device rolled them
            // today — a child who didn't open Tofy keeps yesterday's numbers.
            val day = d.appleSecs("dailyEarnedDate")   // Apple reference date — see Fields.kt
            val today = day != null && isToday(day)
            fun ti(k: String) = if (today) d.int(k) ?: 0 else 0
            return Progress(
                answeredToday = ti("answeredToday"),
                correctToday = ti("correctToday"),
                minutesEarnedToday = ti("minutesEarnedToday"),
                dailyEarnedDate = day,
                stars = d.int("stars") ?: 0,
                diamonds = d.int("diamonds") ?: 0,
                dayStreak = d.int("dayStreak") ?: 0,
                totalAnswered = d.int("totalAnswered") ?: 0,
                totalCorrect = d.int("totalCorrect") ?: 0,
                earnedSecondsAvailable = maxOf(0, (d.int("earnedSecondsIn") ?: 0) - (d.int("earnedSecondsOut") ?: 0)),
                giftSecondsAvailable = maxOf(0, (d.int("giftSecondsIn") ?: 0) - (d.int("giftSecondsOut") ?: 0)),
                topicAccuracy = d.map("topicAccuracy")?.mapNotNull { (k, v) -> (v as? Number)?.let { k to it.toDouble() } }?.toMap() ?: emptyMap(),
                topicAnswered = d.map("topicAnswered")?.mapNotNull { (k, v) -> (v as? Number)?.let { k to it.toInt() } }?.toMap() ?: emptyMap(),
                lastModifiedAt = d.appleSecs("lastModifiedAt"),
            )
        }
    }
}

/** childDevices/{childID}_{installID} — mirrors ChildDevice.swift. */
data class ChildDevice(
    val id: String,
    val childID: String,
    val householdID: String,
    val deviceID: String,
    val name: String,
    val kind: String,
    val lastSeenAt: Double,
    val role: String?,
    val removed: Boolean,
    val shieldAuthorized: Boolean?,
    val windowEndsAt: Double?,
    val windowIsManual: Boolean?,
    val appVersion: String?,
    val raw: Doc,
) {
    val isParentDevice: Boolean get() = role == "parent"

    companion object {
        fun from(id: String, d: Doc) = ChildDevice(
            id = id,
            childID = d.str("childID") ?: "",
            householdID = d.str("householdID") ?: "",
            deviceID = d.str("deviceID") ?: "",
            name = d.str("name") ?: "",
            kind = d.str("kind") ?: "other",
            lastSeenAt = d.secs("lastSeenAt") ?: 0.0,
            role = d.str("role"),
            removed = d.bool("removed") ?: false,
            shieldAuthorized = d.bool("shieldAuthorized"),
            windowEndsAt = d.secs("windowEndsAt"),
            windowIsManual = d.bool("windowIsManual"),
            appVersion = d.str("appVersion"),
            raw = d,
        )
    }
}

/** children/{id}/state/window — mirrors PlayWindowLease.swift. */
data class Lease(
    val state: String,
    val leaseID: String?,
    val ownerDeviceID: String?,
    val kind: String,
    val grantedSeconds: Int,
    val startedAt: Double?,
) {
    val isHeld: Boolean get() = state != "idle" && leaseID != null

    fun remainingSeconds(now: Double = nowSecs()): Int {
        val s = startedAt ?: return 0
        return maxOf(0, grantedSeconds - (now - s).toInt())
    }

    fun isExpired(now: Double = nowSecs()): Boolean {
        val s = startedAt ?: return true
        return !isHeld || now - s > grantedSeconds + 120
    }

    companion object {
        fun from(d: Doc) = Lease(
            state = d.str("state") ?: "idle",
            leaseID = d.str("leaseID"),
            ownerDeviceID = d.str("ownerDeviceID"),
            kind = d.str("kind") ?: "earned",
            grantedSeconds = d.int("grantedSeconds") ?: 0,
            startedAt = d.secs("startedAt"),
        )
    }
}

fun isToday(epochSecs: Double): Boolean {
    val cal = java.util.Calendar.getInstance()
    val todayY = cal.get(java.util.Calendar.YEAR); val todayD = cal.get(java.util.Calendar.DAY_OF_YEAR)
    cal.timeInMillis = (epochSecs * 1000).toLong()
    return cal.get(java.util.Calendar.YEAR) == todayY && cal.get(java.util.Calendar.DAY_OF_YEAR) == todayD
}

/** Profile.schoolYear: the school year starts in September. */
fun schoolYear(): Int {
    val c = java.util.Calendar.getInstance()
    val y = c.get(java.util.Calendar.YEAR)
    return if (c.get(java.util.Calendar.MONTH) + 1 >= 9) y else y - 1
}
