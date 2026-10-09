import Testing
import Foundation
@testable import ChildTime

/// 🔌 Eli, 9.10: a parent phone that lost the family for three days, a reset
/// that did nothing, "today" numbers from another day, and a new child that
/// inherited the previous child's wallet. One test per guarantee.
@MainActor
@Suite("Family link & child safety", .serialized)
struct FamilyLinkTests {

    // MARK: - The family load keeps retrying

    @Test func retryBacksOffAndNeverStops() {
        #expect(HouseholdManager.retryDelay(attempt: 1) == 3)
        #expect(HouseholdManager.retryDelay(attempt: 2) == 6)
        #expect(HouseholdManager.retryDelay(attempt: 3) == 12)
        #expect(HouseholdManager.retryDelay(attempt: 5) == 48)
        #expect(HouseholdManager.retryDelay(attempt: 6) == 60)
        #expect(HouseholdManager.retryDelay(attempt: 500) == 60)   // capped, still retrying
        #expect(HouseholdManager.retryDelay(attempt: 0) == 3)
    }

    // MARK: - While disconnected, nothing may create family data

    @Test func disconnectedBlocksFamilyWritesAndSaysSo() {
        let h = HouseholdManager.shared
        guard h.household == nil else { return }   // only meaningful without a family
        HouseholdManager.testsActAsSignedInParent = true
        defer {
            HouseholdManager.testsActAsSignedInParent = false
            h.setLinkProblemForTesting(nil)
            h.setLoadingForTesting(false)
            h.needsFamilyChoice = false
        }

        // A brand-new parent choosing new-vs-join has no family ON PURPOSE.
        h.setLinkProblemForTesting(nil)
        h.needsFamilyChoice = true
        #expect(h.familyNotLoaded == false)
        #expect(h.familyLinkBroken == false)
        #expect(h.refuseIfDisconnected() == false)
        h.needsFamilyChoice = false

        // Family still on its way (first seconds): writes blocked, no alarm yet.
        h.setLoadingForTesting(true)
        #expect(h.familyNotLoaded == true)
        #expect(h.familyLinkBroken == false)
        #expect(h.refuseIfDisconnected() == true)

        // Loading over and still nothing (a slow/hung load): that IS broken.
        h.setLoadingForTesting(false)
        #expect(h.familyLinkBroken == true)

        // A real failure: blocked, and the parent is told.
        h.setLinkProblemForTesting("The Internet connection appears to be offline.")
        #expect(h.familyLinkBroken == true)
        #expect(h.refuseIfDisconnected() == true)
        #expect(h.connectionNotice == true)
    }

    /// Outside a signed-in parent session (child devices, tests, demos) none of
    /// this may ever block anything.
    @Test func childDevicesAreNeverBlocked() {
        let h = HouseholdManager.shared
        guard h.household == nil else { return }
        HouseholdManager.testsActAsSignedInParent = false
        h.setLinkProblemForTesting("boom")
        defer { h.setLinkProblemForTesting(nil) }
        #expect(h.familyLinkBroken == false)
        #expect(h.familyNotLoaded == false)
        #expect(h.refuseIfDisconnected() == false)
    }

    // MARK: - "Today" means today

    @Test func countersFromAnotherDayShowAsZero() {
        var s = ProgressSnapshot.blank
        s.answeredToday = 5; s.correctToday = 3; s.minutesEarnedToday = 8
        s.minutesUnlockedToday = 20; s.returnedTodayMinutes = 4
        s.hourlyAnswered = Array(repeating: 1, count: 24)
        s.stars = 64; s.totalAnswered = 5

        s.dailyEarnedDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())
        let old = s.todayCountersForDisplay()
        #expect(old.answeredToday == 0 && old.correctToday == 0 && old.minutesEarnedToday == 0)
        #expect(old.minutesUnlockedToday == 0 && old.returnedTodayMinutes == 0 && old.hourlyAnswered == nil)
        #expect(old.stars == 64 && old.totalAnswered == 5)   // lifetime numbers untouched

        s.dailyEarnedDate = Calendar.current.startOfDay(for: Date())
        let today = s.todayCountersForDisplay()
        #expect(today.answeredToday == 5 && today.correctToday == 3 && today.minutesEarnedToday == 8)

        s.dailyEarnedDate = nil
        #expect(s.todayCountersForDisplay().answeredToday == 0)
    }

    // MARK: - A new child starts at zero

    @Test func newChildNeverInheritsAnotherChildsWallet() {
        let store = ProfileStore.shared
        let progress = ProgressStore.shared
        let before = store.profiles.map(\.id)
        let previousActive = store.activeID

        // A child with real numbers is live in the store …
        let a = Profile(name: "בדיקה א", gender: .girl, age: .grade1)
        store.add(a)
        store.setActive(a)
        progress.applyChestReward(ChestReward(stars: 40, diamonds: 12, minutes: 9))
        #expect(progress.stars >= 40)

        // … and the active slot empties while her numbers are still live in the
        // store (Eli's exact state after deleting both אורית).
        store.signOutCurrentProfile()
        #expect(store.activeID == nil)
        #expect(progress.stars >= 40)

        // … and a new child is created.
        let b = Profile(name: "בדיקה ב", gender: .girl, age: .grade1)
        store.add(b)
        #expect(store.activeID == b.id)
        #expect(progress.holdsData(for: b.id))
        #expect(progress.stars == 0)
        #expect(progress.diamonds == 0)
        #expect(progress.pendingMinutes == 0)
        // Whatever is active, B's own saved slot starts blank.
        let slot = ProgressVault.shared.snapshot(for: b.id)
        #expect(slot.stars == 0 && slot.pendingMinutes == 0 && slot.revision == 0)

        // Clean up: back to how the test found it.
        store.removeLocalOnly(a.id)
        store.removeLocalOnly(b.id)
        if let prev = previousActive, store.profiles.contains(where: { $0.id == prev }) { store.setActiveID(prev) }
        #expect(store.profiles.map(\.id) == before)
    }

    // MARK: - Stage 1: one child's numbers never land on another

    /// Removing the active child hands the store to the next one THROUGH the
    /// vault — never a bare `activeID =` with the removed child's numbers live.
    @Test func removingActiveChildLoadsTheNextChildsOwnNumbers() {
        let store = ProfileStore.shared
        let progress = ProgressStore.shared
        let before = store.profiles.map(\.id)
        let previousActive = store.activeID

        let b = Profile(name: "בדיקה ב2", gender: .boy, age: .grade1)
        store.add(b)                                   // B: blank slot
        let a = Profile(name: "בדיקה א2", gender: .girl, age: .grade1)
        store.add(a)
        store.setActive(a)
        progress.applyChestReward(ChestReward(stars: 70, diamonds: 15, minutes: 12))
        #expect(progress.stars >= 70)

        // Put B first so the fallback picks B, then remove A.
        store.signOutCurrentProfile()
        store.setActive(a)
        store.removeLocalOnly(a.id)
        if let now = store.activeID {
            #expect(progress.holdsData(for: now))      // store and active id agree
            let slot = ProgressVault.shared.snapshot(for: now)
            #expect(progress.stars == slot.stars)      // the newcomer's OWN numbers
            #expect(progress.pendingMinutes == slot.pendingMinutes)
            if now == b.id { #expect(progress.stars == 0 && progress.pendingMinutes == 0) }
        }

        store.removeLocalOnly(b.id)
        if let prev = previousActive, store.profiles.contains(where: { $0.id == prev }) { store.setActiveID(prev) }
        #expect(store.profiles.map(\.id) == before)
    }

    /// An offline refund for a child who is no longer live goes into THEIR saved
    /// slot — never into the live store of whoever replaced them.
    @Test func offlineRefundForAnotherChildCreditsTheirSlot() {
        let vault = ProgressVault.shared
        let progress = ProgressStore.shared
        let other = UUID()
        vault.write(.blank, for: other)
        let liveEarned = progress.earnedSecondsIn
        let liveGift = progress.giftSecondsIn

        vault.creditRefund(seconds: 300, gift: false, to: other)
        vault.creditRefund(seconds: 120, gift: true, to: other)

        let slot = vault.snapshot(for: other)
        #expect(slot.earnedSecondsIn == 300)
        #expect(slot.giftSecondsIn == 120)
        #expect(slot.returnedTodayMinutes == 5)
        #expect(progress.earnedSecondsIn == liveEarned)   // live store untouched
        #expect(progress.giftSecondsIn == liveGift)
        vault.purgeCache(for: other)
    }

    // MARK: - Round 2: a reset really zeroes the wallet

    @Test func resetZeroesMinutesAndGiftPocket() {
        let progress = ProgressStore.shared
        progress.applyChestReward(ChestReward(stars: 10, diamonds: 2, minutes: 25))
        progress.addParentGiftMinutes(30)
        #expect(progress.pendingMinutes > 0)
        #expect(progress.parentGiftMinutes > 0)

        progress.resetAll()

        #expect(progress.pendingMinutes == 0)
        #expect(progress.parentGiftMinutes == 0)
        #expect(progress.earnedSecondsIn == 0 && progress.giftSecondsIn == 0)
        #expect(progress.captureSnapshot().pendingMinutes == 0)   // and so does what gets uploaded
    }

    /// A snapshot from a NEWER reset epoch (someone else's reset) replaces the
    /// wallet instead of being max-merged with the old one.
    @Test func newerResetEpochReplacesTheWallet() {
        let progress = ProgressStore.shared
        progress.applyChestReward(ChestReward(stars: 5, diamonds: 1, minutes: 18))
        #expect(progress.pendingMinutes >= 18)
        var wiped = ProgressSnapshot.blank
        wiped.resetEpoch = progress.resetEpoch + 1
        wiped.revision = progress.revision + 1
        progress.apply(wiped)
        #expect(progress.pendingMinutes == 0)
        #expect(progress.earnedSecondsIn == 0)
    }
}
