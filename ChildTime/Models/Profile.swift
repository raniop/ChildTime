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
    /// When the character was last PICKED (kid's shop / editor). Freshness
    /// stamp for cross-device merges: without it, a parent device's stale
    /// roster re-upload silently reverted the kid's new pick (hedgehog →
    /// rabbit). nil (legacy data) = distant past — any stamped pick wins.
    var characterUpdatedAt: Date? = nil
    var createdAt: Date

    // MARK: - Learning identity (Parent Platform)
    /// School grade the parent picked. Scale: -1 = גן טרום־חובה, 0 = גן חובה,
    /// 1–12 = כיתות א׳–יב׳. Independent of the coarse `age` bracket.
    var grade: Int?
    /// True when the CHILD picked their own grade (the friendly picker shown on
    /// a child device that has no grade yet). The parent dashboard flags it so
    /// the parent verifies; a parent-side save clears it.
    var gradeSetByChild: Bool = false
    /// The Israeli SCHOOL YEAR (see `Profile.schoolYear(for:)`) in which the
    /// parent set `grade`. Every September 1st the child auto-advances one
    /// grade per school year elapsed — computed, so it needs no background job
    /// and works offline. nil (legacy data) → treated as set "now" (no jump).
    var gradeSchoolYear: Int?

    /// Israeli school-year index for a date: the year of its September 1st
    /// (e.g. 2026-08-20 → 2025; 2026-09-01 → 2026).
    static func schoolYear(for date: Date = Date(), calendar: Calendar = .current) -> Int {
        let y = calendar.component(.year, from: date)
        return calendar.component(.month, from: date) >= 9 ? y : y - 1
    }

    /// The grade the CONTENT engines should target (משרד החינוך alignment):
    /// the parent-set grade auto-advanced by school years elapsed since it was
    /// set; else derived from the age bracket. ≤0 = גן (pre-reader mode).
    var effectiveGrade: Int {
        if let grade, (-1...12).contains(grade) {
            let advance = Swift.max(0, Profile.schoolYear() - (gradeSchoolYear ?? Profile.schoolYear()))
            return Swift.min(12, grade + advance)
        }
        switch age {
        case .preK:   return 0
        case .grade1: return 1
        case .grade3: return 3
        case .older:  return 5
        }
    }

    /// Kid-facing name for a grade value on our scale.
    static func gradeDisplayName(_ g: Int) -> String {
        switch g {
        case ..<0: return "גַּן טְרוֹם־חוֹבָה"
        case 0:    return "גַּן חוֹבָה"
        default:
            let letters = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳", "ט׳", "י׳", "יא׳", "יב׳"]
            return "כִּתָּה \(letters[Swift.min(g, 12) - 1])"
        }
    }
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
    /// Version stamp for `enabledTopics`. Data written before הבנת הנקרא shipped
    /// (version 1 / missing) can't tell "parent disabled reading" from "reading
    /// didn't exist yet" — so v1 data gets the new topic enabled once on decode,
    /// and every write from this build stamps 2, preserving the parent's choice.
    var topicsVersion: Int = 2
    /// The child's OWN 4-digit "protect my time" code. When set, redeeming/
    /// resuming play minutes on the child's device asks for this code — so a
    /// sibling/friend holding the device can't burn the minutes the child
    /// earned. nil → no code (default). Stored in the clear DELIBERATELY: the
    /// parent dashboard shows it (full parental transparency, and so a parent
    /// can remind a forgetful kid), and it guards play minutes — not data.
    /// The child sets/changes it on their device; the parent can see it and
    /// reset it from the dashboard.
    var playPIN: String?

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
        gradeSchoolYear: Int? = nil,
        interests: [String] = [],
        learningLevel: LearningLevel = .developing,
        difficultyByTopic: [String: String] = [:],
        dailyCapMinutes: Int? = nil,
        enabledTopics: Set<Topic> = Set(Topic.allCases),
        topicsVersion: Int = 2,
        playPIN: String? = nil
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
        self.gradeSchoolYear = gradeSchoolYear
        self.interests = interests
        self.learningLevel = learningLevel
        self.difficultyByTopic = difficultyByTopic
        self.dailyCapMinutes = dailyCapMinutes
        self.enabledTopics = enabledTopics
        self.topicsVersion = topicsVersion
        self.playPIN = playPIN
    }

    // Backward-compatible decoding: profiles stored before the Parent Platform
    // shipped won't have grade / interests / learningLevel keys.
    enum CodingKeys: String, CodingKey {
        case id, name, gender, age, photoData, avatarPresetID, character3DID, characterUpdatedAt, createdAt
        case grade, gradeSchoolYear, gradeSetByChild, interests, learningLevel, difficultyByTopic, dailyCapMinutes, enabledTopics
        case topicsVersion
        case playPIN
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
        self.characterUpdatedAt = try? c.decodeIfPresent(Date.self, forKey: .characterUpdatedAt)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
        self.grade = try c.decodeIfPresent(Int.self, forKey: .grade)
        self.gradeSchoolYear = try c.decodeIfPresent(Int.self, forKey: .gradeSchoolYear)
        self.gradeSetByChild = try c.decodeIfPresent(Bool.self, forKey: .gradeSetByChild) ?? false
        self.interests = try c.decodeIfPresent([String].self, forKey: .interests) ?? []
        self.learningLevel = try c.decodeIfPresent(LearningLevel.self, forKey: .learningLevel) ?? .developing
        self.difficultyByTopic = try c.decodeIfPresent([String: String].self, forKey: .difficultyByTopic) ?? [:]
        self.dailyCapMinutes = try c.decodeIfPresent(Int.self, forKey: .dailyCapMinutes)
        // Older profiles (pre per-child topics) decode to "everything enabled".
        // LENIENT on the values: an unknown topic rawValue (data written by a
        // NEWER build that added a topic) silently drops instead of failing the
        // whole profile decode — ProfileStore.loadProfiles() try?-decodes the
        // entire array, so one strict failure would wipe every profile.
        let rawTopics = (try? c.decodeIfPresent([String].self, forKey: .enabledTopics)) ?? nil
        if let rawTopics {
            let parsed = Set(rawTopics.compactMap(Topic.init(rawValue:)))
            self.enabledTopics = parsed.isEmpty ? Set(Topic.allCases) : parsed
        } else {
            self.enabledTopics = Set(Topic.allCases)
        }
        // v1 data predates הבנת הנקרא — enable it once (except preK, who can't
        // read yet); a version-2 write means the set reflects the parent's choice.
        self.topicsVersion = (try? c.decodeIfPresent(Int.self, forKey: .topicsVersion)) ?? nil ?? 1
        if topicsVersion < 2 {
            if age != .preK { enabledTopics.insert(.reading) }
            topicsVersion = 2
        }
        self.playPIN = try c.decodeIfPresent(String.self, forKey: .playPIN)
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

    /// Whether the child protected their play minutes with a personal code.
    /// Empty string counts as "no code" — it's the deliberate-clear sentinel a
    /// parent reset writes (nil can't be used for that: a missing field in a
    /// stale record must not wipe a freshly set code during merge).
    var hasPlayPIN: Bool { !(playPIN?.isEmpty ?? true) }

    /// Does `pin` match this profile's stored play-protection code?
    func verifyPlayPIN(_ pin: String) -> Bool {
        guard hasPlayPIN else { return true }
        return playPIN == pin
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
