import Testing
import Foundation
@testable import ChildTime

/// 🎬 The demo tour (Rani, 2026-10-12): a made-up family a parent looks around
/// in before signing up. Its whole promise is that nothing of it reaches the
/// cloud and nothing of it is left on the phone — one test per guarantee.
///
/// ⚠️ Runs ON ITS OWN, never with the other suites: while a tour is on, the
/// whole process is in demo mode (that is the feature), and suites running
/// beside it saw "no cloud, no activity log, every family write refused" —
/// eight unrelated failures the first time. So it is skipped unless asked for:
///
///     TEST_RUNNER_DEMO_TOUR_TESTS=1 xcodebuild test-without-building … \
///         -only-testing:ChildTimeTests/DemoTourTests
@MainActor
@Suite("Demo tour", .serialized, .enabled(if: ProcessInfo.processInfo.environment["DEMO_TOUR_TESTS"] != nil))
struct DemoTourTests {

    /// The tour starts only on a device with no family at all, so these tests
    /// are only meaningful on such a host (the same rule the app follows).
    private var hostIsBlank: Bool {
        ProfileStore.shared.profiles.isEmpty
            && HouseholdManager.shared.household == nil
            && AuthManager.shared.userID == nil
            && ParentSettings.shared.joinedChildID == nil
            && ParentSettings.shared.deviceRole == .unset
    }

    /// A child's numbers as the parent's home reads them: the active child's
    /// live ones, every other child's saved slot.
    private func card(for id: UUID) -> ProgressSnapshot? {
        ProgressVault.shared.allSnapshots(for: ProfileStore.shared.profiles).first { $0.profile.id == id }?.snapshot
    }

    private func leftoverKeys(for ids: [UUID]) -> [String] {
        let marks = ids.map(\.uuidString)
        return [UserDefaults.standard, AppGroup.defaults].flatMap { store in
            store.dictionaryRepresentation().keys.filter { key in marks.contains(where: key.contains) }
        }
    }

    @Test func startsOnlyWhereThereIsNoFamily() throws {
        try #require(hostIsBlank && !DemoTour.isOn, "needs a simulator with no family on it and no tour in progress — reinstall the app first")
        #expect(DemoTour.canStart)
        // A single child on the device — a real family's, for all the tour
        // knows — and it must not start, nor touch that child.
        let mine = Profile(name: "אורי", gender: .boy, age: .grade1, grade: 2)
        ProfileStore.shared.add(mine)
        defer { ProfileStore.shared.purgeDemoProfile(mine.id); ProgressStore.shared.resetAll() }
        #expect(DemoTour.canStart == false)
        DemoTour.shared.start()
        #expect(DemoTour.isOn == false)
        #expect(ProfileStore.shared.profiles.map(\.id) == [mine.id])
    }

    @Test func theTourIsAFamilyOfThreeAndEverythingAboutItIsLocal() throws {
        try #require(hostIsBlank && !DemoTour.isOn, "needs a simulator with no family on it and no tour in progress — reinstall the app first")
        DemoTour.shared.start()
        defer { DemoTour.shared.end(signUp: false) }

        #expect(DemoTour.isOn)
        #expect(DemoTour.shared.active)
        // Rani: גן חובה, כיתה א׳, כיתה ו׳ — each with a character of their own.
        #expect(ProfileStore.shared.profiles.map(\.grade) == [0, 1, 6])
        #expect(Set(ProfileStore.shared.profiles.compactMap(\.character3DID)).count == 3)
        #expect(HouseholdManager.shared.familyNameShown == DemoTour.familyName)

        // The three lines of defence.
        #expect(AuthManager.shared.userID == nil)           // 1. no account
        #expect(HouseholdManager.shared.household == nil)
        #expect(HouseholdManager.skipsCloudSync)            // 2. the kill switch
        #expect(AppInfo.isDemoRun)                          //    …and its quiet
        #expect(DemoTour.canStart == false)                 //    (never twice)

        // Everything is open, nothing is sold.
        #expect(SubscriptionManager.shared.isPremium)

        // Every child has a day on the card and a month behind it.
        for p in ProfileStore.shared.profiles {
            #expect((card(for: p.id)?.answeredToday ?? 0) > 0)
            #expect(LearningHistoryStore.shared.history(for: p.id).count > 20)
        }
    }

    @Test func todayInTheReportAddsUpToTheCard() throws {
        try #require(hostIsBlank && !DemoTour.isOn, "needs a simulator with no family on it and no tour in progress — reinstall the app first")
        DemoTour.shared.start()
        defer { DemoTour.shared.end(signUp: false) }
        let today = LearningHistoryStore.dayKey(Date())
        for p in ProfileStore.shared.profiles {
            let card = try #require(card(for: p.id))
            let day = LearningHistoryStore.shared.history(for: p.id).first { $0.date == today }
            #expect(day?.questionsAnswered == card.answeredToday)
            #expect(day?.correct == card.correctToday)
            #expect(day?.perTopic.values.reduce(0) { $0 + $1.answered } == card.answeredToday)
        }
    }

    @Test func leavingTheTourLeavesNothingBehind() throws {
        try #require(hostIsBlank && !DemoTour.isOn, "needs a simulator with no family on it and no tour in progress — reinstall the app first")
        DemoTour.shared.start()
        let ids = ProfileStore.shared.profiles.map(\.id)
        #expect(ids.count == 3)
        #expect(!leftoverKeys(for: ids).isEmpty)            // they WERE saved…

        DemoTour.shared.end(signUp: false)

        #expect(DemoTour.isOn == false)
        #expect(DemoTour.shared.active == false)
        #expect(ProfileStore.shared.profiles.isEmpty)
        #expect(ProfileStore.shared.activeID == nil)
        // The mark a later sign-in would upload a "created here" child by.
        #expect(ids.allSatisfy { !ProfileStore.shared.wasCreatedHere($0) })
        #expect(leftoverKeys(for: ids).isEmpty)             // …and now are not
        #expect(ProgressStore.shared.stars == 0)
        #expect(ProgressStore.shared.answeredToday == 0)
        #expect(ids.allSatisfy { HouseholdManager.shared.devicesByChild[$0.uuidString] == nil })
        #expect(HouseholdManager.skipsCloudSync)            // (tests themselves never sync)
        #expect(HouseholdManager.shared.familyNameShown != DemoTour.familyName)
        // Out is just out: the first screen does not go on to sign-up.
        #expect(DemoTour.consumeSignUpNext() == false)
        // …and the tour can be opened again.
        #expect(DemoTour.canStart)
    }

    @Test func signingUpFromTheTourLeadsOnExactlyOnce() throws {
        try #require(hostIsBlank && !DemoTour.isOn, "needs a simulator with no family on it and no tour in progress — reinstall the app first")
        DemoTour.shared.start()
        DemoTour.shared.end(signUp: true)
        #expect(ProfileStore.shared.profiles.isEmpty)
        #expect(DemoTour.consumeSignUpNext())
        #expect(DemoTour.consumeSignUpNext() == false)
    }

    @Test func whatOnlyARealFamilyCanDoOpensTheInvitation() async throws {
        try #require(hostIsBlank && !DemoTour.isOn, "needs a simulator with no family on it and no tour in progress — reinstall the app first")
        #expect(DemoTour.refuse() == false)                  // outside the tour: nothing
        DemoTour.shared.start()
        defer { DemoTour.shared.end(signUp: false) }
        #expect(HouseholdManager.shared.refuseIfDisconnected())
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(DemoTour.shared.invite == .closed)
        #expect(HouseholdManager.shared.connectionNotice == false)   // not the "disconnected" alert
    }

    @Test func aGiftInTheTourLandsOnThisPhone() async throws {
        try #require(hostIsBlank && !DemoTour.isOn, "needs a simulator with no family on it and no tour in progress — reinstall the app first")
        DemoTour.shared.start()
        defer { DemoTour.shared.end(signUp: false) }
        guard let child = ProfileStore.shared.profiles.first else { Issue.record("no child"); return }
        let before = ProgressVault.shared.snapshot(for: child.id).giftMinutesShown

        RemoteSyncManager.shared.giftChildMinutes(childID: child.id, minutes: 30)
        #expect(RemoteSyncManager.shared.giftSendTracker[child.id]?.reachedCloud == false)   // "sending…"
        try? await Task.sleep(nanoseconds: 2_600_000_000)

        #expect(RemoteSyncManager.shared.giftSendTracker[child.id]?.applied == true)
        #expect(ProfileStore.shared.activeID == child.id)
        #expect(ProgressStore.shared.captureSnapshot().giftMinutesShown == before + 30)
    }

    @Test func aCrashHalfWayOutIsFinishedAtTheNextLaunch() throws {
        try #require(hostIsBlank && !DemoTour.isOn, "needs a simulator with no family on it and no tour in progress — reinstall the app first")
        // The state such a crash leaves: the flag already off, the children
        // (and the list naming them) still here.
        let orphan = Profile(name: "דנה", gender: .girl, age: .older, grade: 6)
        ProfileStore.shared.add(orphan)
        UserDefaults.standard.set([orphan.id.uuidString], forKey: "demoTour.childIDs")

        DemoTour.finishInterruptedExitIfNeeded()

        #expect(ProfileStore.shared.profiles.isEmpty)
        #expect(!ProfileStore.shared.wasCreatedHere(orphan.id))
        #expect(UserDefaults.standard.stringArray(forKey: "demoTour.childIDs") == nil)
    }
}
