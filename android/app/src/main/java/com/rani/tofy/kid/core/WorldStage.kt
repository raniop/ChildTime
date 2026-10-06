package com.rani.tofy.kid.core

/**
 * 🏆 World tiers — the numbers of ProgressStore's "World tiers" (iOS, 2026-10-06).
 *
 * Each world is walked three times — ⭐ bronze, ⭐⭐ silver, ⭐⭐⭐ gold — ten rooms
 * each, the boss in the tenth. Beating it completes the tier (+100 💎) and opens
 * the next one a grade higher; after gold the world is "champion" and simply
 * stays playable. Stored as ONE growing number per world in
 * `ProgressSnapshot.worldStage` (tier × 10 + room) so the cross-device max-merge
 * can never undo a tier. Pure — the engine, the kid's screens and the parent's
 * page (reading the raw synced doc) all read a world the same way.
 */
object WorldStage {
    const val TIER_COUNT = 3
    /** worldStage value of a world finished through gold. */
    const val CHAMPION = TIER_COUNT * 10
    const val TIER_COMPLETE_DIAMONDS = 100
    const val FIRST_VISIT_DIAMONDS = 20

    /** tier × 10 + room. Legacy kids (rooms only) read as bronze at their room. */
    fun stage(worldStage: Map<String, Int>, worldProgress: Map<String, Int>, worldID: String): Int =
        minOf(CHAMPION, maxOf(worldStage[worldID] ?: 0, worldProgress[worldID] ?: 0))

    /** Played in this world at all (a worldStage key, or any legacy room). */
    fun visited(worldStage: Map<String, Int>, worldProgress: Map<String, Int>, worldID: String): Boolean =
        worldStage.containsKey(worldID) || (worldProgress[worldID] ?: 0) > 0

    /** 0 = ⭐ bronze, 1 = ⭐⭐ silver, 2 = ⭐⭐⭐ gold, 3 = champion. */
    fun tier(stage: Int): Int = stage / 10

    /** Room index 0…9 within the tier (a champion sits in the last room, so the boss stays there to replay). */
    fun room(stage: Int): Int = if (stage >= CHAMPION) 9 else stage % 10

    /** 👑 ProgressStore.totalCrowns: tiers done across every world (each world counts up to three). */
    fun totalCrowns(worldStage: Map<String, Int>, worldProgress: Map<String, Int>): Int =
        worldStage.keys.sumOf { minOf(tier(stage(worldStage, worldProgress, it)), TIER_COUNT) }

    /** Grades added to a world's questions: one per tier, at most two. */
    fun gradeOffset(stage: Int): Int = minOf(tier(stage), TIER_COUNT - 1)
}
