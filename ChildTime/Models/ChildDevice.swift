import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// A device that a child plays on. A child can have several (iPad + iPhone…),
/// so the parent can see which devices are connected and when each was last
/// active. Stored in the top-level `childDevices` collection, keyed by
/// "{childID}_{deviceID}", and gated on the household like everything else.
struct ChildDevice: Codable, Identifiable, Equatable {
    let id: String            // "{childID}_{deviceID}"
    var childID: String
    var householdID: String
    var deviceID: String      // stable per install
    var name: String          // friendly label ("אייפד", "אייפון של דן"…)
    var kind: String          // "ipad" | "iphone" | "other"
    var systemVersion: String
    var joinedAt: Date
    var lastSeenAt: Date

    var sfSymbol: String {
        switch kind {
        case "ipad":   return "ipad"
        case "iphone": return "iphone"
        default:       return "rectangle.on.rectangle"
        }
    }
}

/// Stable identity + friendly name for THIS device/install.
enum DeviceIdentity {
    private static let key = "childtime.deviceID"

    /// A UUID that persists for the life of the install (survives relaunches,
    /// resets if the app is deleted). Used so a device updates its own row
    /// instead of creating a new one on every launch.
    static var installID: String {
        let d = UserDefaults.standard
        if let existing = d.string(forKey: key) { return existing }
        let fresh = UUID().uuidString
        d.set(fresh, forKey: key)
        return fresh
    }

    static var kind: String {
        #if canImport(UIKit)
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:   return "ipad"
        case .phone: return "iphone"
        default:     return "other"
        }
        #else
        return "other"
        #endif
    }

    /// A human label. iOS returns a generic name without a special entitlement,
    /// so fall back to a Hebrew device-type label that's still clear to parents.
    static var friendlyName: String {
        #if canImport(UIKit)
        let raw = UIDevice.current.name
        let generic = ["iPhone", "iPad", "iPod touch"]
        if !raw.isEmpty, !generic.contains(raw) { return raw }
        switch kind {
        case "ipad":   return "אייפד"
        case "iphone": return "אייפון"
        default:       return "מכשיר"
        }
        #else
        return "מכשיר"
        #endif
    }

    static var systemVersion: String {
        #if canImport(UIKit)
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        return ""
        #endif
    }
}
