import XCTest
@testable import ChildTime

/// 🔊 A change that arrives by sync (earned on ANOTHER device of the same child)
/// must not trigger "you just did this here" reactions — Dan answered on his
/// iPad and his iPhone played the cheer (Rani, 2026-10-08).
@MainActor
final class SyncReactionTests: XCTestCase {
    func testAppliedSnapshotCountsAsSync() {
        let store = ProgressStore.shared
        var s = store.captureSnapshot()
        s.stars += 5
        store.apply(s)
        XCTAssertTrue(store.changeCameFromSync, "a snapshot just applied is a sync, not a local answer")
    }

    func testSyncFlagExpires() {
        let store = ProgressStore.shared
        store.apply(store.captureSnapshot())
        let exp = expectation(description: "flag clears")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            XCTAssertFalse(store.changeCameFromSync, "later local answers must cheer again")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 3)
    }
}
