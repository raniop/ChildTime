import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The parent's estimate of where a child starts out. Seeds the initial
/// per-topic difficulty so the Smart Feed isn't cold on day one.
enum LearningLevel: String, Codable, CaseIterable, Identifiable {
    case beginner       // just starting out
    case developing     // typical for the age
    case proficient     // comfortable, ready for a challenge
    case advanced       // ahead of the age bracket

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner:   return "מַתְחִיל"
        case .developing: return "מִתְפַּתֵּחַ"
        case .proficient: return "שׁוֹלֵט"
        case .advanced:   return "מִתְקַדֵּם"
        }
    }

    var emoji: String {
        switch self {
        case .beginner:   return "🌱"
        case .developing: return "🌿"
        case .proficient: return "🌳"
        case .advanced:   return "🚀"
        }
    }

    /// Starting difficulty this level implies, before DDA adjusts it live.
    var seedDifficulty: Difficulty {
        switch self {
        case .beginner:   return .easy
        case .developing: return .easy
        case .proficient: return .medium
        case .advanced:   return .hard
        }
    }

    /// Affinity seed bump for interest-matched topics (0...1 space).
    var affinityBoost: Double {
        switch self {
        case .beginner:   return 0.10
        case .developing: return 0.15
        case .proficient: return 0.20
        case .advanced:   return 0.25
        }
    }
}

/// The interest tags a parent can pick for a child at setup. Each maps to the
/// learning `Topic`s it should boost in the Smart Feed, so "ספורט"/"דגלים"
/// nudge geography, "חלל" nudges science, etc.
enum InterestCatalog {
    struct Interest: Identifiable, Hashable {
        let id: String
        let label: String
        let emoji: String
        let topics: [Topic]
    }

    static let all: [Interest] = [
        Interest(id: "sports",   label: "סְפּוֹרְט",    emoji: "⚽️", topics: [.geography, .math]),
        Interest(id: "space",    label: "חָלָל",      emoji: "🚀", topics: [.science]),
        Interest(id: "animals",  label: "בַּעֲלֵי חַיִּים", emoji: "🦁", topics: [.science]),
        Interest(id: "flags",    label: "דְּגָלִים",    emoji: "🚩", topics: [.geography]),
        Interest(id: "music",    label: "מוּזִיקָה",   emoji: "🎵", topics: [.history]),
        Interest(id: "art",      label: "אָמָנוּת",    emoji: "🎨", topics: [.history]),
        Interest(id: "history",  label: "הִיסְטוֹרְיָה", emoji: "🏛️", topics: [.history]),
        Interest(id: "science",  label: "מַדָּע",      emoji: "🔬", topics: [.science]),
        Interest(id: "english",  label: "אַנְגְּלִית",   emoji: "🔤", topics: [.english]),
        Interest(id: "numbers",  label: "מִסְפָּרִים",   emoji: "🔢", topics: [.math, .logic]),
        Interest(id: "puzzles",  label: "חִידוֹת",    emoji: "🧩", topics: [.logic]),
        Interest(id: "geography",label: "מְדִינוֹת",   emoji: "🌍", topics: [.geography]),
    ]

    static func find(_ id: String) -> Interest? { all.first { $0.id == id } }

    /// The set of topics a child's chosen interests point at.
    static func topics(for interestIDs: [String]) -> Set<Topic> {
        var result: Set<Topic> = []
        for id in interestIDs {
            if let i = find(id) { result.formUnion(i.topics) }
        }
        return result
    }
}

/// Firestore representation of a child, owned by a household (not a single
/// parent uid) so co-parents can both see and manage them. Mirrors `Profile`
/// plus the household link. Progress lives in `children/{id}/state/current`.
struct ChildRecord: Codable, Identifiable, Equatable {
    let id: String                 // == Profile.id.uuidString
    var householdID: String
    var name: String
    var age: Int                   // ChildAge.rawValue
    var gender: String?            // ChildGender.rawValue
    var avatarPresetID: String
    var character3DID: String?     // chosen 3D character — syncs to co-parents
    var grade: Int?
    var interests: [String]
    var learningLevel: String      // LearningLevel.rawValue
    var createdAt: Date
    /// A small, compressed copy of the child's photo so it syncs to co-parents'
    /// devices. Downscaled to ≤256px JPEG to stay well under Firestore's 1MB
    /// document limit. nil when the child uses a preset face (no custom photo).
    var photoData: Data?
    /// Per-topic difficulty the parent set for this child (topic.rawValue →
    /// Difficulty.rawValue). Optional so children docs created before this field
    /// existed still decode. The parent's device is authoritative — it edits this
    /// from the dashboard; the child's device mirrors it.
    var difficultyByTopic: [String: String]?
    /// Per-child daily screen-time cap in minutes (parent-set, authoritative on
    /// the parent's device). nil → inherit the device global; 0 → unlimited.
    var dailyCapMinutes: Int?
    /// Topics (worlds) the parent enabled for this child (topic.rawValues).
    /// nil → all topics enabled (also the backward-compatible default).
    var enabledTopics: [String]?
    /// The child's own "protect my time" code (see `Profile.playPIN` — stored
    /// in the clear on purpose so the parent dashboard can SHOW it). Child-
    /// editable (like `character3DID`); the parent dashboard may clear it if
    /// the child forgot the code ("" sentinel). Optional so docs created
    /// before this field existed still decode.
    var playPIN: String?

    init(profile: Profile, householdID: String) {
        self.id = profile.id.uuidString
        self.householdID = householdID
        self.name = profile.name
        self.age = profile.age.rawValue
        self.gender = profile.gender?.rawValue
        self.avatarPresetID = profile.avatarPresetID
        self.character3DID = profile.character3DID
        self.grade = profile.grade
        self.interests = profile.interests
        self.learningLevel = profile.learningLevel.rawValue
        self.createdAt = profile.createdAt
        self.photoData = Self.compressForSync(profile.photoData)
        self.difficultyByTopic = profile.difficultyByTopic.isEmpty ? nil : profile.difficultyByTopic
        self.dailyCapMinutes = profile.dailyCapMinutes
        // Store only when the parent narrowed it (all-enabled stays nil → smaller doc).
        self.enabledTopics = profile.enabledTopics.count >= Topic.allCases.count
            ? nil
            : profile.enabledTopics.map { $0.rawValue }.sorted()
        self.playPIN = profile.playPIN
    }

    /// Rehydrate a local `Profile`. The photo now syncs (compressed), so a custom
    /// avatar picked on the child's device shows up on the parent's device too.
    func toProfile() -> Profile? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return Profile(
            id: uuid,
            name: name,
            gender: gender.flatMap(ChildGender.init(rawValue:)),
            age: ChildAge(rawValue: age) ?? .grade1,
            photoData: photoData,
            avatarPresetID: avatarPresetID,
            character3DID: character3DID,
            createdAt: createdAt,
            grade: grade,
            interests: interests,
            learningLevel: LearningLevel(rawValue: learningLevel) ?? .developing,
            difficultyByTopic: difficultyByTopic ?? [:],
            dailyCapMinutes: dailyCapMinutes,
            enabledTopics: enabledTopics.map { Set($0.compactMap(Topic.init(rawValue:))) } ?? Set(Topic.allCases),
            playPIN: playPIN
        )
    }

    /// Downscale + JPEG-compress a photo so it's safe to store in a Firestore
    /// document (a few KB instead of hundreds). Returns the original when UIKit
    /// is unavailable or the data isn't an image.
    static func compressForSync(_ data: Data?) -> Data? {
        guard let data else { return nil }
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let maxDim: CGFloat = 256
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDim ? maxDim / longest : 1
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        return resized.jpegData(compressionQuality: 0.7) ?? data
        #else
        return data
        #endif
    }
}
