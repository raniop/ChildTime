import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// ✈️ מצב טיסה (Rani, 2026-10-16: "אני ואישתי טסנו והילדים נשארו לבד"): the
/// parents fly, the children stay home, and nobody can approve anything from
/// the air. Before leaving, the parent sets the date they're back and Tofy
/// makes a 4-digit code for THIS child. The child types it on their own
/// device and picks how long to open — as often as they like — until that
/// date. Then the code stops working by itself.
///
/// It works with no internet on the child's device (the code arrives with the
/// child's doc beforehand and is checked locally), 🌙 bedtime still closes the
/// device (the window opens as kind "flight", not "grant"), and every opening
/// reaches the parents like any other ("פתחה זמן מסך").
///
/// Written ONLY through `FlightModeStore.save` as its own field on
/// `children/{id}` — never inside a roster upload, so a device holding an old
/// copy can't write it back. Turning it off writes `until: 0`.
struct FlightMode: Codable, Hashable, Sendable {
    /// Four digits. The child is GIVEN the code, so it is kept in the clear —
    /// the parent's other phone must be able to show it again.
    var code: String
    /// Back home at (seconds since 1970). 0 = off.
    var until: Double
    var setAt: Double

    var isActive: Bool { !code.isEmpty && until > Date().timeIntervalSince1970 }
    var untilDate: Date { Date(timeIntervalSince1970: until) }

    static func newCode() -> String {
        // No 0000/1234-style codes a child would simply guess.
        let weak: Set<String> = ["0000", "1111", "2222", "3333", "4444", "5555", "6666", "7777", "8888", "9999",
                                 "1234", "4321", "1212", "0123"]
        var code: String
        repeat { code = String(format: "%04d", Int.random(in: 0...9999)) } while weak.contains(code)
        return code
    }
}

extension FlightMode: Identifiable {
    var id: String { "\(code)|\(until)" }
}

/// The parent's write, and the child's guard against guessing.
enum FlightModeStore {
    /// PARENT: set (or end, with `nil`) a child's flight mode. Confirms like
    /// every parent→child command: `.ok`/`.queued` reach the child.
    static func save(_ mode: FlightMode?, for childID: UUID) async -> ConfirmedWriteOutcome {
        let value = mode ?? FlightMode(code: "", until: 0, setAt: Date().timeIntervalSince1970)
        // Local copy first, so the parent's screen shows it at once.
        if var p = ProfileStore.shared.profiles.first(where: { $0.id == childID }) {
            p.flightMode = value
            ProfileStore.shared.update(p)   // the roster upload never carries flightMode
        }
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync else { return .ok }
        let ref = Firestore.firestore().collection("children").document(childID.uuidString)
        let fields: [String: Any] = ["flightMode": ["code": value.code, "until": value.until, "setAt": value.setAt]]
        var outcome = await confirmedMerge(ref, fields, timeout: 6)
        if outcome == .denied {
            _ = await HouseholdManager.shared.reassertMembership()
            outcome = await confirmedMerge(ref, fields, timeout: 6)
        }
        return outcome
        #else
        return .error
        #endif
    }

    // MARK: Child: five wrong tries → a minute's wait

    private static let triesKey = "flightCodeTries"
    private static let waitKey = "flightCodeWaitUntil"
    static let maxTries = 5

    /// Seconds left to wait before another try (0 = may try now).
    static var waitSeconds: Int {
        max(0, Int(UserDefaults.standard.double(forKey: waitKey) - Date().timeIntervalSince1970))
    }

    /// Checks a typed code. A right one resets the count.
    static func check(_ typed: String, against mode: FlightMode) -> Bool {
        guard waitSeconds == 0, mode.isActive else { return false }
        if typed == mode.code {
            UserDefaults.standard.set(0, forKey: triesKey)
            return true
        }
        let tries = UserDefaults.standard.integer(forKey: triesKey) + 1
        if tries >= maxTries {
            UserDefaults.standard.set(0, forKey: triesKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970 + 60, forKey: waitKey)
        } else {
            UserDefaults.standard.set(tries, forKey: triesKey)
        }
        return false
    }
}
