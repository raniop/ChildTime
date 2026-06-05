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
    /// The chosen 3D character's id (see Character3DCatalog). nil → default.
    /// Lives on the profile so it syncs to co-parents' devices via ChildRecord.
    var character3DID: String?
    var createdAt: Date

    // MARK: - Learning identity (Parent Platform)
    /// School grade (1–12), if the parent specified one. Independent of the
    /// coarse `age` bracket used for difficulty defaults.
    var grade: Int?
    /// Interest tags the parent picked at setup (see `InterestCatalog`). Seed
    /// the Smart Feed's topic affinity toward what the child already likes.
    var interests: [String]
    /// Initial learning level the parent estimated — seeds starting difficulty.
    var learningLevel: LearningLevel
    /// Per-topic question difficulty for THIS child (topic.rawValue →
    /// Difficulty.rawValue). Set by the parent from their device and synced via
    /// `ChildRecord`. Empty for a topic → fall back to `learningLevel.seedDifficulty`.
    /// Difficulty is per-child (not a global device setting) so siblings at
    /// different levels each get the right challenge.
    var difficultyByTopic: [String: String]
    /// Daily screen-time cap for THIS child, in minutes — set by the parent from
    /// their device and synced via `ChildRecord`. nil → inherit the device's
    /// global setting; 0 → unlimited (no cap). Per-child so siblings can differ.
    var dailyCapMinutes: Int?
    /// Topics (worlds) the parent allows THIS child to learn. Drives BOTH the
    /// world cards on the home screen AND the Smart Feed's topic universe — so a
    /// parent who turns off English hides that world and stops English questions.
    /// Synced via `ChildRecord`. Default: every topic enabled (opt-out per child).
    var enabledTopics: Set<Topic>

    init(
        id: UUID = UUID(),
        name: String,
        gender: ChildGender? = nil,
        age: ChildAge = .grade1,
        photoData: Data? = nil,
        avatarPresetID: String = AvatarPreset.defaultID(for: nil),
        character3DID: String? = nil,
        createdAt: Date = .now,
        grade: Int? = nil,
        interests: [String] = [],
        learningLevel: LearningLevel = .developing,
        difficultyByTopic: [String: String] = [:],
        dailyCapMinutes: Int? = nil,
        enabledTopics: Set<Topic> = Set(Topic.allCases)
    ) {
        self.id = id
        self.name = name
        self.gender = gender
        self.age = age
        self.photoData = photoData
        self.avatarPresetID = avatarPresetID
        self.character3DID = character3DID
        self.createdAt = createdAt
        self.grade = grade
        self.interests = interests
        self.learningLevel = learningLevel
        self.difficultyByTopic = difficultyByTopic
        self.dailyCapMinutes = dailyCapMinutes
        self.enabledTopics = enabledTopics
    }

    // Backward-compatible decoding: profiles stored before the Parent Platform
    // shipped won't have grade / interests / learningLevel keys.
    enum CodingKeys: String, CodingKey {
        case id, name, gender, age, photoData, avatarPresetID, character3DID, createdAt
        case grade, interests, learningLevel, difficultyByTopic, dailyCapMinutes, enabledTopics
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.gender = try c.decodeIfPresent(ChildGender.self, forKey: .gender)
        self.age = try c.decode(ChildAge.self, forKey: .age)
        self.photoData = try c.decodeIfPresent(Data.self, forKey: .photoData)
        self.avatarPresetID = try c.decode(String.self, forKey: .avatarPresetID)
        self.character3DID = try c.decodeIfPresent(String.self, forKey: .character3DID)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.grade = try c.decodeIfPresent(Int.self, forKey: .grade)
        self.interests = try c.decodeIfPresent([String].self, forKey: .interests) ?? []
        self.learningLevel = try c.decodeIfPresent(LearningLevel.self, forKey: .learningLevel) ?? .developing
        self.difficultyByTopic = try c.decodeIfPresent([String: String].self, forKey: .difficultyByTopic) ?? [:]
        self.dailyCapMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyCapMinutes)
        // Older profiles (pre per-child topics) decode to "everything enabled".
        self.enabledTopics = try c.decodeIfPresent(Set<Topic>.self, forKey: .enabledTopics) ?? Set(Topic.allCases)
    }

    /// Whether the parent allows this topic for the child.
    func allows(_ topic: Topic) -> Bool { enabledTopics.contains(topic) }

    /// Resolved daily screen-time cap for this child. A per-child value overrides
    /// the device-global setting; nil → inherit the global; ≤0 → unlimited.
    func resolvedDailyCap(globalEnabled: Bool, globalMax: Int) -> (enabled: Bool, minutes: Int) {
        if let m = dailyCapMinutes {
            return m <= 0 ? (false, 0) : (true, m)
        }
        return (globalEnabled, globalMax)
    }

    /// Effective base difficulty for a topic: the parent's explicit per-topic
    /// choice if set, otherwise the starting level implied by `learningLevel`.
    /// (The live question feed still nudges this up/down via DDA on top.)
    func difficulty(for topic: Topic) -> Difficulty {
        if let raw = difficultyByTopic[topic.rawValue], let d = Difficulty(rawValue: raw) {
            return d
        }
        return learningLevel.seedDifficulty
    }

    /// Display avatar — photo if available, otherwise the preset.
    var hasPhoto: Bool { photoData != nil }

    /// The chosen 3D character (falls back to the catalog default).
    var character: Character3D { Character3DCatalog.find(character3DID) }
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
                     label: "אָדוֹם-כָּתוֹם"),
        AvatarPreset(id: "boy_blue",
                     emoji: "🧑",
                     topColor: Color(hex: "5B9BFF"),
                     bottomColor: Color(hex: "48BFE3"),
                     label: "כָּחוֹל"),
        AvatarPreset(id: "boy_green",
                     emoji: "👦",
                     topColor: Color(hex: "06D6A0"),
                     bottomColor: Color(hex: "118AB2"),
                     label: "יָרוֹק-טוּרְקִיז"),
        // Girl-leaning
        AvatarPreset(id: "girl_pink",
                     emoji: "👧",
                     topColor: Color(hex: "F15BB5"),
                     bottomColor: Color(hex: "FF6B9D"),
                     label: "וָרוֹד"),
        AvatarPreset(id: "girl_purple",
                     emoji: "👧",
                     topColor: Color(hex: "9B5DE5"),
                     bottomColor: Color(hex: "5E60CE"),
                     label: "סָגוֹל"),
        AvatarPreset(id: "girl_yellow",
                     emoji: "🧒",
                     topColor: Color(hex: "FFD166"),
                     bottomColor: Color(hex: "FFB84D"),
                     label: "צָהוֹב-זָהוֹב"),
        // More faces — diverse skin tones
        AvatarPreset(id: "boy_tan",
                     emoji: "👦🏽",
                     topColor: Color(hex: "FF9F45"),
                     bottomColor: Color(hex: "FF6B6B"),
                     label: "פַּרְצוּף שָׁזוּף"),
        AvatarPreset(id: "girl_dark",
                     emoji: "👧🏿",
                     topColor: Color(hex: "C77DFF"),
                     bottomColor: Color(hex: "7C4DFF"),
                     label: "פַּרְצוּף כֵּהֶה"),
        AvatarPreset(id: "kid_light",
                     emoji: "🧒🏻",
                     topColor: Color(hex: "48BFE3"),
                     bottomColor: Color(hex: "06D6A0"),
                     label: "פַּרְצוּף בָּהִיר"),
        // Neutral / fun
        AvatarPreset(id: "neutral_rainbow",
                     emoji: "🦄",
                     topColor: Color(hex: "9B5DE5"),
                     bottomColor: Color(hex: "06D6A0"),
                     label: "קֶסֶם"),
        AvatarPreset(id: "neutral_robot",
                     emoji: "🤖",
                     topColor: Color(hex: "5E60CE"),
                     bottomColor: Color(hex: "48BFE3"),
                     label: "רוֹבּוֹטִי"),
        AvatarPreset(id: "fun_fox",
                     emoji: "🦊",
                     topColor: Color(hex: "FF8C42"),
                     bottomColor: Color(hex: "FF6B6B"),
                     label: "שׁוּעָל"),
        AvatarPreset(id: "fun_panda",
                     emoji: "🐼",
                     topColor: Color(hex: "5B9BFF"),
                     bottomColor: Color(hex: "9B5DE5"),
                     label: "פַּנְדָּה"),
        AvatarPreset(id: "fun_dragon",
                     emoji: "🐲",
                     topColor: Color(hex: "06D6A0"),
                     bottomColor: Color(hex: "118AB2"),
                     label: "דְּרָקוֹן"),
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
