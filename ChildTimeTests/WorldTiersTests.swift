//
//  WorldTiersTests.swift
//  ChildTimeTests
//
//  🏆 World tiers (Rani, 2026-10-06: "10/10 and then nothing"). Each world is
//  walked three times — bronze, silver, gold — and stored as ONE growing number
//  per world (tier × 10 + room), so a second device's max-merge can never undo
//  a tier. These pin the rules and, above all, the cross-device merge.
//

import Testing
import Foundation
@testable import ChildTime

// Nested in the serialized economy suite: both drive `ProgressStore.shared`.
extension MiniGameEconomy {

@MainActor
@Suite struct WorldTiers {
    let world = "tiers_test_world"

    private func fresh() -> ProgressStore {
        ProgressStore.shared.resetAll()
        return ProgressStore.shared
    }

    @Test func tenRoundsReachTheBossAndStop() {
        let p = fresh()
        #expect(p.progress(in: world) == 0)
        #expect(p.worldTier(in: world) == 0)
        for _ in 0..<20 { p.advanceRoom(in: world) }
        #expect(p.progress(in: world) == 9)          // room 10 — the boss room
        #expect(p.stage(in: world) == 9)
        #expect(p.worldProgress[world] == 9)         // legacy counter unchanged
    }

    @Test func oneRoundIsOneRoom() {
        let p = fresh()
        p.advanceRoom(in: world)
        #expect(p.stage(in: world) == 1)
        #expect(p.progress(in: world) == 1)
        for _ in 0..<7 { p.advanceRoom(in: world) }
        #expect(p.progress(in: world) == 8)          // 8 rounds: still before the boss
        p.advanceRoom(in: world)
        #expect(p.progress(in: world) == 9)          // the 9th round opens the boss room
    }

    @Test func beatingTheBossCompletesTheTierOnce() {
        let p = fresh()
        for _ in 0..<9 { p.advanceRoom(in: world) }
        let before = p.diamonds
        #expect(p.completeTier(in: world) == 0)      // bronze done
        #expect(p.diamonds == before + ProgressStore.tierCompleteDiamonds)
        #expect(p.worldTier(in: world) == 1)         // silver
        #expect(p.progress(in: world) == 0)          // back to room 1
        #expect(p.tierGradeOffset(in: world) == 1)
        // A replay in room 1 completes nothing and pays nothing.
        #expect(p.completeTier(in: world) == nil)
        #expect(p.diamonds == before + ProgressStore.tierCompleteDiamonds)
    }

    @Test func goldThenChampionStaysPlayable() {
        let p = fresh()
        for tier in 0..<ProgressStore.worldTierCount {
            for _ in 0..<9 { p.advanceRoom(in: world) }
            #expect(p.completeTier(in: world) == tier)
        }
        #expect(p.worldTier(in: world) == 3)         // champion
        #expect(p.stage(in: world) == ProgressStore.championStage)
        #expect(p.progress(in: world) == 9)          // boss stays to replay
        #expect(p.tierGradeOffset(in: world) == 2)   // never more than two grades up
        p.advanceRoom(in: world)
        #expect(p.stage(in: world) == ProgressStore.championStage)
        #expect(p.completeTier(in: world) == nil)
        #expect(p.totalCrowns == 3)
        #expect(p.championWorlds == 1)
    }

    @Test func firstVisitPaysOnce() {
        let p = fresh()
        #expect(!p.hasVisited(world))
        let before = p.diamonds
        #expect(p.markVisited(world) == ProgressStore.firstVisitDiamonds)
        #expect(p.hasVisited(world))
        #expect(p.markVisited(world) == 0)
        #expect(p.diamonds == before + ProgressStore.firstVisitDiamonds)
    }

    @Test func legacyRoomsReadAsBronze() {
        // A kid who reached 10/10 before tiers existed: only worldProgress.
        var s = ProgressSnapshot()
        s.worldProgress = [world: 9]
        let p = fresh()
        p.apply(s)
        #expect(p.stage(in: world) == 9)
        #expect(p.hasVisited(world))
        #expect(p.completeTier(in: world) == 0)      // the boss is right there
        #expect(p.worldTier(in: world) == 1)
    }

    // MARK: Cross-device

    @Test func mergeNeverUndoesATier() {
        // Device A finished bronze and is in silver room 2 (stage 11); device B
        // still holds bronze room 10 (stage 9). Max-merge keeps silver.
        var a = ProgressSnapshot(); a.worldStage = [world: 11]; a.worldProgress = [world: 9]
        var b = ProgressSnapshot(); b.worldStage = [world: 9];  b.worldProgress = [world: 9]
        let m = ProgressSnapshot.ratchetMerged(local: b, remote: a)
        #expect(m.worldStage[world] == 11)
        // …and a world only one side visited survives the merge.
        var c = ProgressSnapshot(); c.worldStage = ["other": 0]
        let m2 = ProgressSnapshot.ratchetMerged(local: m, remote: c)
        #expect(m2.worldStage["other"] == 0)
        #expect(m2.worldStage[world] == 11)
    }

    @Test func worldStageSurvivesFirestoreRoundTrip() throws {
        var s = ProgressSnapshot()
        s.worldStage = [world: 23, "other": 0]
        let raw = try #require(ProgressSnapshot.toFirestore(s))
        let back = try #require(ProgressSnapshot.fromFirestore(raw))
        #expect(back.worldStage == s.worldStage)
        // An old snapshot without the key decodes to "no tiers", not a failure.
        var old = raw; old.removeValue(forKey: "worldStage")
        #expect(ProgressSnapshot.fromFirestore(old)?.worldStage == [:])
    }
}

}
