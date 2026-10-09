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
        defer { h.setLinkProblemForTesting(nil) }

        h.setLinkProblemForTesting(nil)
        #expect(h.familyLinkBroken == false)
        #expect(h.refuseIfDisconnected() == false)     // a brand-new parent may create
        #expect(h.connectionNotice == false)

        h.setLinkProblemForTesting("The Internet connection appears to be offline.")
        #expect(h.familyLinkBroken == true)
        #expect(h.refuseIfDisconnected() == true)      // blocked …
        #expect(h.connectionNotice == true)            // … and the parent is told
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

        // … she is removed (Eli deleted both אורית) and the active slot empties …
        store.removeLocalOnly(a.id)
        store.signOutCurrentProfile()          // no active child — Eli's exact state
        #expect(store.activeID == nil)
        #expect(progress.stars >= 40)          // A's numbers are still live in the store

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
        store.removeLocalOnly(b.id)
        if let prev = previousActive, store.profiles.contains(where: { $0.id == prev }) { store.setActiveID(prev) }
        #expect(store.profiles.map(\.id) == before)
    }
}
