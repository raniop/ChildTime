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
        static let createdHere = "profiles.createdHereIDs"
    }

    /// IDs of profiles genuinely CREATED on this device (vs merged from the
    /// cloud). Only these (plus cloud-known ids) may ever be (re)uploaded by
    /// the reconcile sweep — a stale local copy of a child that lives (or
    /// died) elsewhere must never be pushed back up. This is what let old
    /// UUIDs resurrect as "duplicate children" in the day-one families.
    private var createdHereIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: Key.createdHere) ?? []) }
        set { defaults.set(Array(newValue), forKey: Key.createdHere) }
    }

    func wasCreatedHere(_ id: UUID) -> Bool { createdHereIDs.contains(id.uuidString) }

    /// Full local wipe — clears the in-memory roster, the active id, and the
    /// createdHere set, so a device reset followed by signing into a DIFFERENT
    /// account (without killing the app) can't re-upload the previous family's
    /// children into the new one. This was the resurrection engine behind the
    /// duplicate-children / cross-family-leak incidents.
    func wipeAllInMemory() {
        defaults.removeObject(forKey: Key.createdHere)
        activeID = nil
        profiles = []
    }

    /// Wipe every local trace of a DEMO-seeded profile (see ChildTimeApp.seedDemo)
    /// so a normal launch can never sync it into a real production family:
    /// the profile row, its createdHere mark (reconcile bait), and its vault snapshot.
    func purgeDemoProfile(_ id: UUID) {
        removeLocalOnly(id)
        var s = createdHereIDs; s.remove(id.uuidString); createdHereIDs = s
        AppGroup.defaults.removeObject(forKey: "progressSnapshot.\(id.uuidString)")
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
        createdHereIDs.insert(profile.id.uuidString)
        profiles.append(profile)
        // If this is the first profile, make it active automatically.
        if activeID == nil { activeID = profile.id }
        HouseholdManager.shared.upsertChild(profile)
    }

    func remove(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if activeID == profile.id {
            activeID = fallbackActiveID()
        }
        HouseholdManager.shared.deleteChild(profile.id)
    }

    /// Drop a profile from the LOCAL store only — no cloud delete. Used by the
    /// tombstone listener so a child deleted on another device disappears here too
    /// (and this device stops re-uploading it), without re-triggering a cloud delete.
    func removeLocalOnly(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        profiles.removeAll { $0.id == id }
        if activeID == id { activeID = fallbackActiveID() }
    }

    /// Replacement identity after the active profile disappears. A PARENT device
    /// may fall back to the first profile (dashboard convenience, no identity at
    /// stake). A CHILD device must NEVER guess — the roster order is arbitrary,
    /// and guessing is exactly how Yoav's iPad silently became his sibling. nil
    /// routes the kid to the explicit selection / rescan screen instead.
    private func fallbackActiveID() -> UUID? {
        ParentSettings.shared.deviceRole == .child ? nil : profiles.first?.id
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
            // Not local yet (arrives via mergeRemoteChildren). Park the vault
            // on the NEW id FIRST — save the outgoing kid, load the (blank)
            // incoming snapshot — so the sync can never capture the PREVIOUS
            // kid's live points under the new id (the "duplicate child with
            // the sibling's stars" incident, 36502FEA).
            ProgressVault.shared.switchTo(profileID: id)
            activeID = id
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
        // Profiles whose LOCAL character pick is fresher than the cloud's —
        // pushed back up after the merge so the cloud converges to the pick.
        var localCharacterWinners: [Profile] = []
        for record in records {
            guard let remote = record.toProfile() else { continue }
            if let idx = working.firstIndex(where: { $0.id == remote.id }) {
                var merged = remote
                // Prefer the synced photo (so a photo the child picked shows up
                // here); fall back to the existing local photo when the remote
                // has none — e.g. legacy profiles or a preset-face child.
                merged.photoData = remote.photoData ?? working[idx].photoData
                // Character: the FRESHER pick wins (characterUpdatedAt stamp) —
                // "remote always wins" let a parent device's stale roster upload
                // revert the kid's new pick (hedgehog → rabbit). nil stamp =
                // distant past, so legacy data loses to any stamped pick.
                let localCharStamp = working[idx].characterUpdatedAt ?? .distantPast
                let remoteCharStamp = remote.characterUpdatedAt ?? .distantPast
                if localCharStamp > remoteCharStamp {
                    merged.character3DID = working[idx].character3DID ?? remote.character3DID
                    merged.characterUpdatedAt = working[idx].characterUpdatedAt
                    // This device holds the newer pick — heal the stale cloud doc
                    // (the pick's own upsert may have been raced over). Converges:
                    // once the cloud carries this stamp, local never wins again.
                    localCharacterWinners.append(merged)
                } else {
                    merged.character3DID = remote.character3DID ?? working[idx].character3DID
                }
                // Play-protection code: a MISSING remote field (pre-field doc /
                // stale writer) must not wipe a code the child just set locally —
                // but an EMPTY string is a deliberate clear (parent reset), and
                // must win. (See Profile.playPIN.)
                merged.playPIN = remote.playPIN ?? working[idx].playPIN
                // A bought pack is never lost to a stale writer — union.
                merged.ownedPacks = remote.ownedPacks.union(working[idx].ownedPacks)
                merged.packExpiry = remote.packExpiry.merging(working[idx].packExpiry) { max($0, $1) }
                if working[idx] != merged { working[idx] = merged; changed = true }
            } else {
                working.append(remote); changed = true
            }
        }
        if changed {
            profiles = working
            // Auto-pick a default ONLY where no identity is at stake (parent
            // dashboard). On a CHILD device the identity is the joinedChildID
            // binding — "first in the list" once bound Yoav's iPad to a sibling.
            if activeID == nil, ParentSettings.shared.deviceRole != .child {
                activeID = profiles.first?.id
            }
        }
        for winner in localCharacterWinners {
            HouseholdManager.shared.upsertChild(winner)
        }
    }

    /// Remove local profiles the cloud household no longer contains — ghosts
    /// accumulated over months of merges (Shlomo's device showed a deleted
    /// duplicate + counted 9 kids). Called only with an authoritative SERVER
    /// children snapshot (never cache). Never touches the bound child
    /// (joinedChildID) or a profile created on this device that may not have
    /// reached the cloud yet.
    func pruneLocalGhosts(cloudIDs: Set<String>) {
        guard !cloudIDs.isEmpty else { return }   // empty snapshot → don't judge
        let joined = ParentSettings.shared.joinedChildID
        let ghosts = profiles.filter { p in
            let id = p.id.uuidString
            return !cloudIDs.contains(id) && id != joined && !wasCreatedHere(p.id)
        }
        for g in ghosts {
            TofyLink("pruneLocalGhosts: dropping \(g.name):\(g.id.uuidString.prefix(8)) — absent from cloud household")
            removeLocalOnly(g.id)
        }
    }

    // MARK: - Mirroring to legacy settings

    /// The rest of the app reads identity off `ParentSettings.shared`. Keep
    /// it in sync with the active profile so we don't have to refactor every
    /// view in v1.
    private func mirrorActiveIntoSettings() {
        guard let p = active else { return }
        // Deferred to the next runloop tick: this is often triggered as a side
        // effect of a view update (a view switching the active profile), and
        // mutating ParentSettings' @Published fields *synchronously* during a
        // view update trips SwiftUI's "Publishing changes from within view
        // updates is not allowed" warning. The equality guards also skip
        // needless publishes when nothing actually changed.
        DispatchQueue.main.async {
            let s = ParentSettings.shared
            if s.childName != p.name { s.childName = p.name }
            if s.childGender != p.gender { s.childGender = p.gender }
            if s.childAge != p.age { s.childAge = p.age }
            if s.childPhotoData != p.photoData { s.childPhotoData = p.photoData }
        }
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
        let raw = defaults.string(forKey: Key.activeID)
        if let raw, let id = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == id }) {
            activeID = id
        }
        // Migration: a child device already bound to a kid (persisted activeID)
        // BEFORE `joinedChildID` existed should keep its binding — don't force a
        // surprise re-scan. A fresh device has no persisted activeID, so it still
        // must scan to bind.
        if ParentSettings.shared.deviceRole == .child,
           ParentSettings.shared.joinedChildID == nil,
           let raw, !raw.isEmpty {
            ParentSettings.shared.joinedChildID = raw
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
