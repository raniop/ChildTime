//
//  ChildTimeTests.swift
//  ChildTimeTests
//
//  Created by Rani Ophir on 27/05/2026.
//

import Testing
@testable import ChildTime

struct ChildTimeTests {

    @Test func example() async throws {}

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
