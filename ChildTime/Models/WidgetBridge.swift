import Foundation
import WidgetKit
import UIKit

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
        var playMinutes: Int   // earned screen-time minutes ready to spend
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
            goalToday: kidGoalPerDay,
            playMinutes: p.pendingMinutes)
        if let data = try? JSONEncoder().encode(snap) {
            AppGroup.defaults.set(data, forKey: kidKey)
        }
        writeKidAvatar()
        WidgetCenter.shared.reloadTimelines(ofKind: "TofyKidWidget")
    }

    private static let kidAvatarKey = "widget.kid.avatar"

    /// Render the active child's chosen 2D character to a small PNG in the App
    /// Group so the widget can show the REAL avatar. 3D-only characters have no
    /// flat image → we clear the key and the widget falls back to 🦁.
    private static func writeKidAvatar() {
        guard let img = ProfileStore.shared.active?.character.uiImage else {
            AppGroup.defaults.removeObject(forKey: kidAvatarKey)
            return
        }
        let target: CGFloat = 140
        let scale = min(target / max(img.size.width, 1), target / max(img.size.height, 1), 1)
        let size = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false   // keep the character's transparent background
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            img.draw(in: CGRect(origin: .zero, size: size))
        }
        if let data = small.pngData() {
            AppGroup.defaults.set(data, forKey: kidAvatarKey)
        }
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
