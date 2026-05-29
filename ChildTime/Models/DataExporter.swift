import Foundation

/// Produces a complete, human-readable JSON export of everything the app holds
/// about a family — profiles, progress snapshots, and daily learning history —
/// so a parent can keep or move their data (data-portability requirement).
@MainActor
enum DataExporter {

    struct Export: Codable {
        var exportedAt: Date
        var appVersion: String
        var children: [ChildExport]
    }

    struct ChildExport: Codable {
        var id: String
        var name: String
        var age: Int
        var grade: Int?
        var interests: [String]
        var learningLevel: String
        var progress: ProgressSnapshot
        var dailyHistory: [DailyStat]
    }

    /// Builds the export from local stores (works offline).
    static func buildExport() -> Export {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let children = ProfileStore.shared.profiles.map { profile -> ChildExport in
            let snap = ProgressVault.shared.snapshot(for: profile.id)
            let history = LearningHistoryStore.shared.history(for: profile.id)
            return ChildExport(
                id: profile.id.uuidString,
                name: profile.name,
                age: profile.age.rawValue,
                grade: profile.grade,
                interests: profile.interests,
                learningLevel: profile.learningLevel.rawValue,
                progress: snap,
                dailyHistory: history
            )
        }
        return Export(exportedAt: Date(), appVersion: version, children: children)
    }

    /// Writes the export to a temporary file and returns its URL, ready for a
    /// share sheet. Returns nil on failure.
    static func writeExportFile() -> URL? {
        let export = buildExport()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(export) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChildTime-Export.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// Wipes all local data for the family (UserDefaults app-group + standard).
    /// Pair with `HouseholdManager.deleteAllData()` for the cloud side.
    static func wipeLocalData() {
        let group = AppGroup.defaults
        let standard = UserDefaults.standard
        // Per-profile keys + profile list + auth cache + history.
        for profile in ProfileStore.shared.profiles {
            let id = profile.id.uuidString
            group.removeObject(forKey: "progressSnapshot.\(id)")
            group.removeObject(forKey: "questionMemory.\(id)")
            group.removeObject(forKey: "learningHistory.\(id)")
        }
        for key in ["profiles.list", "profiles.activeID", "profiles.didMigrateLegacyKid",
                    "household.didMigrate", "auth.cachedUser"] {
            standard.removeObject(forKey: key)
            group.removeObject(forKey: key)
        }
    }
}
