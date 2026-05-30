import Foundation
import Combine

/// Manages the family's array of `Profile`s + which one is active.
///
/// v1 contract:
///   • Up to 4 profiles per family.
///   • Active profile's identity (name / age / gender / photo / avatar)
///     mirrors into `ParentSettings.shared` so existing UI keeps working.
///   • Progress (stars, score, etc.) is shared across profiles in v1.
///     Per-profile partitioning ships in v2.
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let profiles = "profiles.list"
        static let activeID = "profiles.activeID"
        static let didMigrate = "profiles.didMigrateLegacyKid"
    }

    @Published private(set) var profiles: [Profile] = [] {
        didSet { saveProfiles() }
    }
    @Published private(set) var activeID: UUID? {
        didSet {
            if let id = activeID {
                defaults.set(id.uuidString, forKey: Key.activeID)
            } else {
                defaults.removeObject(forKey: Key.activeID)
            }
            mirrorActiveIntoSettings()
        }
    }

    static let maxProfiles = 4

    private init() {
        loadProfiles()
        loadActiveID()
        migrateLegacyKidIfNeeded()
        // CRUCIAL: defer the vault bind to the next runloop tick.
        //
        // If we call ProgressVault.switchTo here synchronously, it touches
        // QuestionMemory.shared, whose init reads ProgressStore /
        // ProfileStore.shared.activeID — and ProfileStore.shared is STILL
        // inside its own dispatch_once init right now. dispatch_once
        // detects the re-entry and traps with EXC_BREAKPOINT.
        //
        // Async-on-main breaks the cycle: by the time the closure runs,
        // ProfileStore.shared has been fully constructed.
        if let id = activeID, let p = profiles.first(where: { $0.id == id }) {
            DispatchQueue.main.async {
                ProgressVault.shared.switchTo(p)
            }
        }
    }

    // MARK: - Public API

    var active: Profile? {
        guard let id = activeID else { return nil }
        return profiles.first(where: { $0.id == id })
    }

    var canAddMore: Bool { profiles.count < Self.maxProfiles }

    /// True iff a kid still needs to pick a profile.
    var needsProfileSelection: Bool {
        !profiles.isEmpty && activeID == nil
    }

    /// True iff the family has never created a profile yet.
    var isEmpty: Bool { profiles.isEmpty }

    func add(_ profile: Profile) {
        guard canAddMore else { return }
        profiles.append(profile)
        // If this is the first profile, make it active automatically.
        if activeID == nil { activeID = profile.id }
        HouseholdManager.shared.upsertChild(profile)
    }

    func remove(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if activeID == profile.id {
            activeID = profiles.first?.id
        }
        HouseholdManager.shared.deleteChild(profile.id)
    }

    func update(_ profile: Profile) {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            if profile.id == activeID { mirrorActiveIntoSettings() }
            HouseholdManager.shared.upsertChild(profile)
        }
    }

    func setActive(_ profile: Profile) {
        guard profiles.contains(where: { $0.id == profile.id }) else { return }
        // Save the OLD profile's progress + load the new one BEFORE we
        // flip `activeID`, so listeners that react to activeID see a
        // store that already holds the new kid's state.
        ProgressVault.shared.switchTo(profile)
        // Fresh child? Seed the Smart Feed from their interests + level.
        ProgressStore.shared.seedLearning(from: profile)
        activeID = profile.id
    }

    /// Select a child by id — used after a child device joins by code, where
    /// the profile may still be streaming down from the cloud.
    func setActiveID(_ id: UUID) {
        if let p = profiles.first(where: { $0.id == id }) {
            setActive(p)
        } else {
            activeID = id   // profile will arrive via mergeRemoteChildren
        }
    }

    /// Sign-out style: clears active selection (forces the picker on next launch).
    func signOutCurrentProfile() {
        activeID = nil
    }

    /// Merge children pulled from the household in Firestore into the local
    /// store. Adds new ones and refreshes identity fields, while preserving
    /// device-local photo data. Does not auto-remove (avoids data-loss races
    /// from listener ordering); explicit deletes go through `remove`.
    func mergeRemoteChildren(_ records: [ChildRecord]) {
        var working = profiles
        var changed = false
        for record in records {
            guard let remote = record.toProfile() else { continue }
            if let idx = working.firstIndex(where: { $0.id == remote.id }) {
                var merged = remote
                // Prefer the synced photo (so a photo the child picked shows up
                // here); fall back to the existing local photo when the remote
                // has none — e.g. legacy profiles or a preset-face child.
                merged.photoData = remote.photoData ?? working[idx].photoData
                if working[idx] != merged { working[idx] = merged; changed = true }
            } else {
                working.append(remote); changed = true
            }
        }
        if changed {
            profiles = working
            if activeID == nil { activeID = profiles.first?.id }
        }
    }

    // MARK: - Mirroring to legacy settings

    /// The rest of the app reads identity off `ParentSettings.shared`. Keep
    /// it in sync with the active profile so we don't have to refactor every
    /// view in v1.
    private func mirrorActiveIntoSettings() {
        guard let p = active else { return }
        let s = ParentSettings.shared
        s.childName = p.name
        s.childGender = p.gender
        s.childAge = p.age
        s.childPhotoData = p.photoData
    }

    /// Pull the latest identity edits *from* ParentSettings back into the
    /// active profile. Used when the parent edits name/photo in Settings.
    func syncBackFromSettings() {
        guard var p = active else { return }
        let s = ParentSettings.shared
        if p.name != s.childName { p.name = s.childName }
        if p.gender != s.childGender { p.gender = s.childGender }
        if p.age != s.childAge { p.age = s.childAge }
        if p.photoData != s.childPhotoData { p.photoData = s.childPhotoData }
        update(p)
    }

    // MARK: - Persistence

    private func loadProfiles() {
        guard let data = defaults.data(forKey: Key.profiles),
              let decoded = try? JSONDecoder().decode([Profile].self, from: data) else {
            return
        }
        profiles = decoded
    }

    private func saveProfiles() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Key.profiles)
    }

    private func loadActiveID() {
        if let raw = defaults.string(forKey: Key.activeID),
           let id = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == id }) {
            activeID = id
        }
    }

    // MARK: - One-time migration

    /// On first launch after the profiles feature ships, if the family had
    /// the legacy single-kid setup (name / age / gender in ParentSettings),
    /// auto-create their first profile so nobody loses their setup.
    private func migrateLegacyKidIfNeeded() {
        guard !defaults.bool(forKey: Key.didMigrate) else { return }
        defaults.set(true, forKey: Key.didMigrate)

        // Only auto-migrate if there are no profiles yet AND there's
        // legacy data worth saving.
        guard profiles.isEmpty else { return }

        let s = ParentSettings.shared
        let hasLegacyData = !s.childName.isEmpty || s.childGender != nil || s.childPhotoData != nil

        if hasLegacyData {
            let p = Profile(
                name: s.childName.isEmpty ? "הילד שלי" : s.childName,
                gender: s.childGender,
                age: s.childAge,
                photoData: s.childPhotoData,
                avatarPresetID: AvatarPreset.defaultID(for: s.childGender)
            )
            profiles = [p]
            activeID = p.id
        }
    }
}
