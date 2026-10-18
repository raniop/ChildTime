import Foundation
import Testing
@testable import ChildTime

/// ✈️ The flight code (Rani, 2026-10-16): opens only while the parents are
/// away, only with the right code, and five wrong tries mean a short wait.
@MainActor
struct FlightModeTests {
    private func reset() {
        UserDefaults.standard.removeObject(forKey: "flightCodeTries")
        UserDefaults.standard.removeObject(forKey: "flightCodeWaitUntil")
    }
    private var active: FlightMode {
        FlightMode(code: "4821", until: Date().addingTimeInterval(86400).timeIntervalSince1970, setAt: Date().timeIntervalSince1970)
    }

    @Test func theRightCodeOpens() {
        reset()
        #expect(FlightModeStore.check("4821", against: active))
        #expect(!FlightModeStore.check("1111", against: active))
    }

    @Test func anExpiredCodeNeverOpens() {
        reset()
        let over = FlightMode(code: "4821", until: Date().addingTimeInterval(-60).timeIntervalSince1970, setAt: 0)
        #expect(!over.isActive)
        #expect(!FlightModeStore.check("4821", against: over))
        // Ended by the parent: until 0, no code.
        #expect(!FlightMode(code: "", until: 0, setAt: 0).isActive)
    }

    @Test func fiveWrongTriesMeanAWait() {
        reset()
        for _ in 0..<FlightModeStore.maxTries { _ = FlightModeStore.check("0001", against: active) }
        #expect(FlightModeStore.waitSeconds > 0)
        // Even the right code waits.
        #expect(!FlightModeStore.check("4821", against: active))
        reset()
    }

    @Test func codesAreFourDigitsAndNeverObvious() {
        for _ in 0..<500 {
            let c = FlightMode.newCode()
            #expect(c.count == 4 && c.allSatisfy(\.isNumber))
            #expect(!["0000", "1234", "1111"].contains(c))
        }
    }
}
