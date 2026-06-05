import Foundation
import WidgetKit

/// Writes compact snapshots into the shared App Group so the home-screen widgets
/// (kid + family) can render without touching Firestore or auth, then asks
/// WidgetKit to refresh. The Codable shapes + keys here MUST stay in sync with
/// `TofyHomeWidgets.swift` in the widget target (each target keeps its own copy).
enum WidgetBridge {
    private static let kidKey = "widget.kid.v1"
    private static let familyKey = "widget.family.v1"
    static let kidGoalPerDay = 10

    private struct KidSnapshot: Codable {
        var name: String
        var stars: Int
        var diamonds: Int
        var dayStreak: Int
        var answeredToday: Int
        var correctToday: Int
        var goalToday: Int
    }

    private struct FamilyChild: Codable {
        var name: String
        var stars: Int
        var dayStreak: Int
        var answeredToday: Int
        var accuracy: Int
        var playedToday: Bool
    }

    /// Refresh the KID widget from the active child's live progress (kid device).
    static func refreshKid() {
        let p = ProgressStore.shared
        let snap = KidSnapshot(
            name: ProfileStore.shared.active?.name ?? "טופי",
            stars: p.stars,
            diamonds: p.diamonds,
            dayStreak: p.dayStreak,
            answeredToday: p.answeredToday,
            correctToday: p.correctToday,
            goalToday: kidGoalPerDay)
        if let data = try? JSONEncoder().encode(snap) {
            AppGroup.defaults.set(data, forKey: kidKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "TofyKidWidget")
    }

    /// Refresh the FAMILY widget from the parent dashboard's per-child rows.
    static func writeFamily(_ rows: [(profile: Profile, snapshot: ProgressSnapshot)]) {
        let kids = rows.prefix(6).map { row -> FamilyChild in
            let s = row.snapshot
            let acc = s.answeredToday > 0 ? Int((Double(s.correctToday) / Double(s.answeredToday)) * 100) : 0
            return FamilyChild(
                name: row.profile.name,
                stars: s.stars,
                dayStreak: s.dayStreak,
                answeredToday: s.answeredToday,
                accuracy: acc,
                playedToday: s.answeredToday > 0)
        }
        if let data = try? JSONEncoder().encode(Array(kids)) {
            AppGroup.defaults.set(data, forKey: familyKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "TofyFamilyWidget")
    }
}
