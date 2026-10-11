import Testing
import Foundation
@testable import ChildTime

/// 🧬 One child's progress must never be written into a sibling's document.
/// (2026-10-10: Yahli's whole state replaced Yoav's — the live store's owner
/// was guessed at launch, and a higher reset epoch wins whole.)
struct ProgressOwnerTests {
    private let yoav = "C3C8CA83-7412-4B78-9E1A-0CC52D18D0F5"
    private let yahli = "69D34DFD-4FBC-4B76-8EA8-9A3CF74CCD9C"

    // MARK: whose data is it, at launch

    @Test func theStoredOwnerIsTheOwnerWhoeverIsActive() {
        // The numbers on disk are Yahli's; the active id already says Yoav.
        let owner = ProgressStore.launchOwner(stored: yahli, tracked: true, activeID: yoav, boundChildID: nil)
        #expect(owner == UUID(uuidString: yahli))
    }

    @Test func aSwitchCutShortLeavesNobodysData() {
        // Owners are tracked, none is stored: the last switch never finished.
        #expect(ProgressStore.launchOwner(stored: nil, tracked: true, activeID: yoav, boundChildID: nil) == nil)
        #expect(ProgressStore.launchOwner(stored: nil, tracked: true, activeID: yoav, boundChildID: yoav) == nil)
    }

    /// An install from before owners were stored: only a device bound to ONE
    /// child may assume its numbers are that child's.
    @Test func anOlderInstallTrustsOnlyABoundChildDevice() {
        #expect(ProgressStore.launchOwner(stored: nil, tracked: false, activeID: yoav, boundChildID: yoav) == UUID(uuidString: yoav))
        // A parent's phone (a cache of several children): unbound until the vault loads the active one.
        #expect(ProgressStore.launchOwner(stored: nil, tracked: false, activeID: yoav, boundChildID: nil) == nil)
        // Bound to one child but another is marked active — not to be trusted either.
        #expect(ProgressStore.launchOwner(stored: nil, tracked: false, activeID: yoav, boundChildID: yahli) == nil)
    }

    // MARK: an upload never raises the cloud's reset epoch

    @Test func dataFromANewerResetThanTheCloudsIsNotThisChilds() {
        var cloud = ProgressSnapshot.blank; cloud.resetEpoch = 1; cloud.stars = 41_642; cloud.revision = 39_488
        var wrong = ProgressSnapshot.blank; wrong.resetEpoch = 2; wrong.stars = 16_064; wrong.revision = 39_457
        #expect(!ProgressSnapshot.uploadMayMerge(local: wrong, remote: cloud))
        // …which is exactly the upload that used to win whole:
        #expect(ProgressSnapshot.ratchetMerged(local: wrong, remote: cloud).stars == 16_064)
    }

    @Test func ordinaryUploadsStillMerge() {
        var cloud = ProgressSnapshot.blank; cloud.resetEpoch = 2; cloud.stars = 100
        var same = ProgressSnapshot.blank; same.resetEpoch = 2; same.stars = 130
        var behind = ProgressSnapshot.blank; behind.resetEpoch = 1; behind.stars = 9_000   // from before a reset
        #expect(ProgressSnapshot.uploadMayMerge(local: same, remote: cloud))
        #expect(ProgressSnapshot.uploadMayMerge(local: behind, remote: cloud))
        // A device behind a reset loses whole — the reset stands.
        #expect(ProgressSnapshot.ratchetMerged(local: behind, remote: cloud).stars == 100)
    }

    // MARK: the owner is stored with the data

    @MainActor @Test func bindingStoresTheOwnerBesideTheData() {
        let store = ProgressStore.shared
        let before = store.belongsTo
        defer { store.bind(to: before) }
        let id = UUID()
        store.bind(to: id)
        #expect(store.holdsData(for: id))
        store.bind(to: nil)
        #expect(!store.holdsData(for: id))
        #expect(store.belongsTo == nil)
    }
}
