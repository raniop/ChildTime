import Foundation

/// 📍 A fixed place the parents marked on the map — home, school, a club.
/// Lives on the household (`households/{id}.places`), shared by both parents
/// and every child device. Android mirrors it in `FamilyPlace.kt`.
struct FamilyPlace: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var emoji: String
    var lat: Double
    var lng: Double
    /// Meters.
    var radius: Double
    /// Child UUID string → which crossings ping the parents.
    var alerts: [String: PlaceAlert]

    struct PlaceAlert: Codable, Hashable, Sendable {
        var arrive: Bool
        var leave: Bool
    }

    /// Rani: "חייבים לצמצם". The phone fences at ~100 m at best, so 50 marks the
    /// spot for the label; arrive/leave still fire at the OS minimum.
    static let radii: [Double] = [50, 100, 200]

    init(id: String = UUID().uuidString, name: String, emoji: String = "📍",
         lat: Double, lng: Double, radius: Double = 100, alerts: [String: PlaceAlert] = [:]) {
        self.id = id; self.name = name; self.emoji = emoji
        self.lat = lat; self.lng = lng; self.radius = radius; self.alerts = alerts
    }

    /// The Firestore shape (plain values only — written with updateData).
    var firestore: [String: Any] {
        ["id": id, "name": name, "emoji": emoji, "lat": lat, "lng": lng, "radius": radius,
         "alerts": alerts.mapValues { ["arrive": $0.arrive, "leave": $0.leave] }]
    }

    func contains(lat: Double, lng: Double) -> Bool {
        Self.meters(lat, lng, self.lat, self.lng) <= radius
    }

    /// Great-circle distance in meters (haversine).
    static func meters(_ lat1: Double, _ lng1: Double, _ lat2: Double, _ lng2: Double) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180, dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }

    /// The place a point is in — the nearest centre when fences overlap.
    static func place(at lat: Double, _ lng: Double, in places: [FamilyPlace]) -> FamilyPlace? {
        places.filter { $0.contains(lat: lat, lng: lng) }
            .min { meters(lat, lng, $0.lat, $0.lng) < meters(lat, lng, $1.lat, $1.lng) }
    }
}

/// One device's last fix, as the parent reads it (`children/{id}/location/fix_<installID>`).
/// A child with an iPhone AND an iPad has two — the phone that travels and the
/// tablet that stays home must not overwrite each other.
struct ChildLocationFix: Equatable, Sendable {
    var deviceID: String = ""
    /// "iphone" / "ipad" / "android"…
    var kind: String = ""
    var lat: Double
    var lng: Double
    var accuracy: Double
    /// Unix seconds of the fix (the device's clock; the server stamp when present).
    var at: Double
    /// 0…1, nil when unknown.
    var battery: Double?
    var placeID: String?
    var placeSince: Double?
    /// "denied" / "whenInUse" / "always" — what the child's phone allows.
    var permission: String?
}
