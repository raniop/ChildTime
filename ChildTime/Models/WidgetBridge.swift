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
        var choresAvailable: Int   // 🧹 chores the kid can do right now
        var money: Int             // 💰 unpaid chore-money balance (₪)
    }

    private struct FamilyChild: Codable {
        var name: String
        var stars: Int
        var dayStreak: Int
        var answeredToday: Int
        var accuracy: Int
        var playedToday: Bool
        var playingNow: Bool       // 🟢 an open screen-time window right now
        var pendingChores: Int     // 🧹 marked done, waiting for approval
        var money: Int             // 💰 unpaid chore-money balance (₪)
    }

    /// Refresh the KID widget from the active child's live progress (kid device).
    @MainActor
    static func refreshKid() {
        let p = ProgressStore.shared
        let activeID = ProfileStore.shared.activeID
        let snap = KidSnapshot(
            name: ProfileStore.shared.active?.name ?? "טופי",
            stars: p.stars,
            diamonds: p.diamonds,
            dayStreak: p.dayStreak,
            answeredToday: p.answeredToday,
            correctToday: p.correctToday,
            goalToday: kidGoalPerDay,
            playMinutes: p.pendingMinutes,
            choresAvailable: activeID.map { ChoreStore.shared.chores(forChild: $0).filter(\.isAvailable).count } ?? 0,
            money: activeID.map { ChoreStore.shared.moneyBalance(forChild: $0) } ?? 0)
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
    @MainActor
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
                playedToday: s.answeredToday > 0,
                playingNow: (s.unlockEndsAt ?? .distantPast) > Date(),
                pendingChores: ChoreStore.shared.chores(forChild: row.profile.id)
                    .filter(\.isPendingApproval).count,
                money: ChoreStore.shared.moneyBalance(forChild: row.profile.id))
        }
        if let data = try? JSONEncoder().encode(Array(kids)) {
            AppGroup.defaults.set(data, forKey: familyKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "TofyFamilyWidget")
    }

    // MARK: - Freshness (Rani: the family widget lagged until the app was opened)

    private static var familyRefreshWork: DispatchWorkItem?

    /// Rebuild the family widget straight from the live stores — called whenever
    /// a remote child snapshot or a chore doc changes (which is exactly when a
    /// silent/visible push wakes the app), debounced against listener bursts.
    /// The dashboard no longer has to be OPENED for the widget to be fresh.
    @MainActor
    static func refreshFamilySoon() {
        guard ParentSettings.shared.deviceRole == .parent else { return }
        familyRefreshWork?.cancel()
        let work = DispatchWorkItem {
            Task { @MainActor in
                let rows = ProfileStore.shared.profiles.compactMap { p -> (profile: Profile, snapshot: ProgressSnapshot)? in
                    guard let snap = RemoteSyncManager.shared.remoteSnapshots[p.id] else { return nil }
                    return (p, snap)
                }
                guard !rows.isEmpty else { return }
                writeFamily(rows)
            }
        }
        familyRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }
}
