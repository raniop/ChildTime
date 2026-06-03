//
//  ChildTimeTests.swift
//  ChildTimeTests
//
//  Created by Rani Ophir on 27/05/2026.
//

import Testing
import Foundation
@testable import ChildTime

struct ChildTimeTests {

    @Test func example() async throws {}

    /// REGRESSION: renaming the snapshot's `gems` field to `diamonds` made old
    /// payloads (which have "gems" / "stars" but NO "diamonds") fail to decode
    /// entirely, wiping ALL accumulated progress. The resilient decoder must keep
    /// every present field — and recover diamonds from the legacy `gems` key.
    @Test func oldSnapshotMissingDiamonds_keepsStars() throws {
        let json: [String: Any] = [
            "stars": 12_345,            // lots of accumulated stars
            "gems": 7,                  // legacy key (pre-diamonds)
            "xp": 88,
            "totalScore": 4_200,
            "ownedCharacterIDs": ["fox", "bear"],
            "revision": 9
            // NOTE: no "diamonds" key — exactly the old-payload shape.
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let snap = try JSONDecoder().decode(ProgressSnapshot.self, from: data)

        #expect(snap.stars == 12_345)                       // NOT wiped
        #expect(snap.diamonds == 7)                         // recovered from "gems"
        #expect(snap.xp == 88)
        #expect(snap.totalScore == 4_200)
        #expect(snap.ownedCharacterIDs == ["fox", "bear"])
        #expect(snap.revision == 9)
    }

    /// An empty / garbage payload must decode to defaults, never throw (which the
    /// vault would treat as `.blank` and overwrite good data with).
    @Test func emptySnapshotJSON_decodesToBlankNotThrow() throws {
        let data = try JSONSerialization.data(withJSONObject: [String: Any]())
        let snap = try JSONDecoder().decode(ProgressSnapshot.self, from: data)
        #expect(snap.stars == 0)
        #expect(snap.diamonds == 0)
    }

    /// End-to-end proof that the character shop works: catalog integrity, every
    /// image actually loads from the bundle, tier/help derivation, and a real
    /// buy (not-enough-stars → fail, enough → deduct + own, double-buy → fail).
    @MainActor @Test func characterShopWorks() throws {
        let all = Character3DCatalog.all

        // 1. Roster integrity.
        #expect(all.count == 48)
        #expect(all.filter { $0.isFree }.count == 4)
        #expect(Set(all.map(\.id)).count == 48)               // no duplicate ids
        #expect(Character3DCatalog.find(nil).id == "fox")     // default fallback
        #expect(Character3DCatalog.find("does_not_exist").id == "fox")

        // 2. Every character's PNG is bundled and decodes (proves all 36 render).
        for c in all {
            #expect(c.uiImage != nil, "missing/!loadable image for \(c.id)")
        }

        // 3. Tier + helper derivation.
        #expect(CharacterTier(priceStars: 0)     == .free)
        #expect(CharacterTier(priceStars: 1500)  == .common)
        #expect(CharacterTier(priceStars: 3500)  == .rare)
        #expect(CharacterTier(priceStars: 7000)  == .epic)
        #expect(CharacterTier(priceStars: 14000) == .legendary)
        #expect(CharacterTier(priceStars: 25000) == .mythic)
        #expect(Character3DCatalog.find("fox").helpLevel == .encourage)
        #expect(CharacterTier(priceStars: 3500).help == .hint)
        #expect(CharacterTier(priceStars: 14000).help == .explain)

        let store = CharacterStore.shared
        let progress = ProgressStore.shared

        // 4. Free characters are always owned.
        #expect(store.owns(Character3DCatalog.find("fox")))

        // 5. Buying with too few diamonds fails; with enough it deducts + grants.
        //    (Stars are rank-only now — purchases burn 💎 diamonds.)
        progress.spendDiamonds(progress.diamonds)             // zero the wallet
        #expect(progress.diamonds == 0)

        guard let target = all.first(where: { !store.owns($0) && $0.priceDiamonds > 0 }) else {
            return  // everything already owned from a prior run — nothing to buy
        }

        #expect(throws: CharacterStore.PurchaseError.self) {
            try store.purchase(target)
        }
        #expect(!store.owns(target))

        progress.addDiamonds(target.priceDiamonds)
        let before = progress.diamonds
        let starsBefore = progress.stars
        let bought = try store.purchase(target)
        #expect(bought.id == target.id)
        #expect(store.owns(target))
        #expect(progress.diamonds == before - target.priceDiamonds)
        // Spending must NOT touch the leaderboard rank.
        #expect(progress.stars == starsBefore)

        // 6. Can't buy the same character twice.
        #expect(throws: CharacterStore.PurchaseError.self) {
            try store.purchase(target)
        }
    }
}
