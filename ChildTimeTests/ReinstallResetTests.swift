import Testing
import Foundation
@testable import ChildTime

/// 🧼 Deleting Tofy and installing it again starts from zero (Rani, 2026-10-11 —
/// Yoav's reinstalled iPad came up as his little brother, connected to nothing).
struct ReinstallResetTests {
    @Test func aLiveSessionOnDefaultsThatNeverSawAnAccountIsAReinstall() {
        #expect(AuthManager.looksReinstalled(liveSession: true, cachedUser: false, installMarked: false))
    }

    /// Every install that was ever used has the cached account beside its
    /// session — an update must never be mistaken for a reinstall and sign a
    /// family out.
    @Test func anInstallThatWasUsedBeforeIsNotAReinstall() {
        #expect(!AuthManager.looksReinstalled(liveSession: true, cachedUser: true, installMarked: false))
        #expect(!AuthManager.looksReinstalled(liveSession: true, cachedUser: true, installMarked: true))
        // A child device the parent removed: its cache is wiped, its session and mark stay.
        #expect(!AuthManager.looksReinstalled(liveSession: true, cachedUser: false, installMarked: true))
    }

    @Test func aFirstInstallWithNoSessionIsNotAReinstall() {
        #expect(!AuthManager.looksReinstalled(liveSession: false, cachedUser: false, installMarked: false))
    }
}
