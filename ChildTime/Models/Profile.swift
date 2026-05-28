import Foundation
import SwiftUI

/// A child profile — identity + appearance.
///
/// Each family can have up to 4 profiles. The active profile drives what
/// ParentSettings / ProgressStore read & write. v1 stores identity only;
/// per-profile progress partitioning ships in v2.
struct Profile: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var gender: ChildGender?
    var age: ChildAge
    var photoData: Data?
    var avatarPresetID: String      // initial character preset (boy_red, girl_blue, etc.)
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        gender: ChildGender? = nil,
        age: ChildAge = .grade1,
        photoData: Data? = nil,
        avatarPresetID: String = AvatarPreset.defaultID(for: nil),
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.gender = gender
        self.age = age
        self.photoData = photoData
        self.avatarPresetID = avatarPresetID
        self.createdAt = createdAt
    }

    /// Display avatar — photo if available, otherwise the preset.
    var hasPhoto: Bool { photoData != nil }
}

// MARK: - Avatar presets

/// A starter character a kid can pick before they earn cosmetics in the shop.
/// Each preset is a colored circle + emoji combo — cheerful and recognizable
/// at a glance.
struct AvatarPreset: Identifiable, Hashable {
    let id: String
    let emoji: String
    let topColor: Color
    let bottomColor: Color
    let label: String   // accessibility / picker label

    static let all: [AvatarPreset] = [
        // Boy-leaning
        AvatarPreset(id: "boy_red",
                     emoji: "👦",
                     topColor: Color(hex: "FF6B6B"),
                     bottomColor: Color(hex: "FFB84D"),
                     label: "אדום-כתום"),
        AvatarPreset(id: "boy_blue",
                     emoji: "🧑",
                     topColor: Color(hex: "5B9BFF"),
                     bottomColor: Color(hex: "48BFE3"),
                     label: "כחול"),
        AvatarPreset(id: "boy_green",
                     emoji: "👦",
                     topColor: Color(hex: "06D6A0"),
                     bottomColor: Color(hex: "118AB2"),
                     label: "ירוק-טורקיז"),
        // Girl-leaning
        AvatarPreset(id: "girl_pink",
                     emoji: "👧",
                     topColor: Color(hex: "F15BB5"),
                     bottomColor: Color(hex: "FF6B9D"),
                     label: "ורוד"),
        AvatarPreset(id: "girl_purple",
                     emoji: "👧",
                     topColor: Color(hex: "9B5DE5"),
                     bottomColor: Color(hex: "5E60CE"),
                     label: "סגול"),
        AvatarPreset(id: "girl_yellow",
                     emoji: "🧒",
                     topColor: Color(hex: "FFD166"),
                     bottomColor: Color(hex: "FFB84D"),
                     label: "צהוב-זהוב"),
        // Neutral / fun
        AvatarPreset(id: "neutral_rainbow",
                     emoji: "🦄",
                     topColor: Color(hex: "9B5DE5"),
                     bottomColor: Color(hex: "06D6A0"),
                     label: "קסם"),
        AvatarPreset(id: "neutral_robot",
                     emoji: "🤖",
                     topColor: Color(hex: "5E60CE"),
                     bottomColor: Color(hex: "48BFE3"),
                     label: "רובוטי"),
    ]

    static func find(_ id: String) -> AvatarPreset {
        all.first { $0.id == id } ?? all[0]
    }

    /// Reasonable default based on gender — first preset matching the lean.
    static func defaultID(for gender: ChildGender?) -> String {
        switch gender {
        case .boy:  return "boy_blue"
        case .girl: return "girl_pink"
        case .none: return "neutral_rainbow"
        }
    }
}
