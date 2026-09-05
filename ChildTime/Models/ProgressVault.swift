import Foundation
import Combine

/// Persists a `ProgressSnapshot` per profile under
/// `progressSnapshot.<profileID>` in shared UserDefaults.
///
/// Two responsibilities:
/// 1. Profile-switch handoff — save the *previous* profile's state and
///    load the *next* profile's into the live `ProgressStore`.
/// 2. Expose a read-only "snapshot of all profiles" API for the parent
///    dashboard.
@MainActor
final class ProgressVault {
    static let shared = ProgressVault()

    private let defaults = AppGroup.defaults
    private var cancellables: Set<AnyCancellable> = []
    private var saveDebounce: Task<Void, Never>? = nil
    private(set) var boundProfileID: UUID? = nil

    private init() {}

    private func key(for profileID: UUID) -> String {
        "progressSnapshot.\(profileID.uuidString)"
    }

    // MARK: - Snapshot reads

    /// Load the saved snapshot for `profileID`. Returns `.blank` if none.
    func snapshot(for profileID: UUID) -> ProgressSnapshot {
        guard let data = defaults.data(forKey: key(for: profileID)),
              let snap = try? JSONDecoder().decode(ProgressSnapshot.self, from: data)
        else { return .blank }
        return snap
    }

    /// Persist `snapshot` for `profileID` (overwrites any previous). Stored
    /// VERBATIM — the version metadata (`revision`/`lastModifiedAt`/`deviceID`)
    /// is now owned by whoever produced the snapshot (`ProgressStore` for local
    /// state, the remote sender for cached cloud state). Bumping it here used to
    /// corrupt both: local saves never climbed past revision 1, and cached remote
    /// snapshots got restamped as if this device authored them.
    func write(_ snapshot: ProgressSnapshot, for profileID: UUID) {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: key(for: profileID))
        }
    }

    /// Throw away this device's cached copy of `profileID`, so the next cloud
    /// snapshot is adopted wholesale instead of being merged with it.
    ///
    /// This is the ONLY cure for a poisoned cache. Accumulators merge by `max`,
    /// which ignores revision entirely, so a cached copy holding numbers that are
    /// too high — another child's, say — re-raises them on every sync and no
    /// cloud-side restore can hold. Until this existed the only answer for a real
    /// family was "delete and reinstall the app", which they cannot be expected
    /// to diagnose, and which our own app-removal lock can even prevent.
    ///
    /// Refuses to purge the profile currently bound: that data is live, not a
    /// cache, and dropping it would discard whatever the child just did.
    @discardableResult
    func purgeCache(for profileID: UUID) -> Bool {
        guard profileID != boundProfileID else { return false }
        defaults.removeObject(forKey: key(for: profileID))
        TofyLink("vault: purged cached copy of \(profileID.uuidString.prefix(8))")
        return true
    }

    /// All persisted snapshots — used by the parent dashboard.
    func allSnapshots(for profiles: [Profile]) -> [(profile: Profile, snapshot: ProgressSnapshot)] {
        profiles.map { profile in
            // The currently-bound profile's snapshot lives in memory on
            // ProgressStore — capture it fresh so the dashboard reflects
            // the latest values.
            if profile.id == boundProfileID {
                return (profile, ProgressStore.shared.captureSnapshot())
            }
            return (profile, snapshot(for: profile.id))
        }
    }

    // MARK: - Profile switching

    /// Save the currently-active profile's state, then load `profile`'s
    /// state into the live `ProgressStore`.
    func switchTo(_ profile: Profile) { switchTo(profileID: profile.id) }

    /// Same handoff by ID ONLY — for adopting a profile that hasn't streamed
    /// down from the cloud yet (child-device rebind). The incoming snapshot is
    /// whatever the vault holds for that id (usually .blank); the cloud
    /// listener fills in the real state when it arrives. Without this, the
    /// caller flipped `activeID` with the PREVIOUS kid's data still live in
    /// ProgressStore — and the sync uploaded those points under the new id
    /// (the "duplicate child with the sibling's stars" incident, 36502FEA).
    func switchTo(profileID: UUID) {
        // 0. Device-local play state (open window / frozen parent time) belongs
        //    to the OUTGOING kid — save it into their wallet/freezer, then clear,
        //    so it can't leak onto the incoming profile. ONLY on a real switch
        //    (first bind and same-profile re-selects leave the live value alone —
        //    restoring there wiped frozen time on every launch of a 1-kid device).
        let switching = boundProfileID != nil && boundProfileID != profileID
        if switching, let outgoing = boundProfileID {
            let hadWindow = ProgressStore.shared.isUnlocked
            ProgressStore.shared.stopAndSaveCurrentUnlock()
            if hadWindow {
                // The window's apps must not stay open for the NEXT kid.
                ShieldManager.shared.cancelScheduledReshield()
                ShieldManager.shared.relockBaseline()
            }
            ProgressStore.shared.stashDeviceLocalPlayState(for: outgoing)
        }
        // 1. Save the outgoing profile — but ONLY if the live store really is
        //    holding their data. If a previous switch was interrupted, or the
        //    store was rebound elsewhere, `captureSnapshot()` returns some OTHER
        //    child's progress, and writing it under `outgoing` copies one child
        //    onto another. Accumulators merge by `max`, so that copy then
        //    ratchets the sibling's stars up permanently and cannot be undone
        //    from the cloud. Skipping the save loses at most the last few seconds;
        //    writing the wrong child's data is unrecoverable.
        if let outgoing = boundProfileID, ProgressStore.shared.holdsData(for: outgoing) {
            write(ProgressStore.shared.captureSnapshot(), for: outgoing)
            // …and push it NOW while `activeID` is still the outgoing kid: the
            // debounced upload would fire later for the NEW active kid, leaving the
            // outgoing kid's just-banked leftover only in the vault (where the next
            // cloud echo overwrites it).
            // …but never from a parent's MONITOR device. A parent tapping between
            // children in the dashboard switches profiles constantly, and each
            // switch would upload that device's cached copy of the outgoing child.
            // The cache is a view, not a source of truth — if it is ever wrong,
            // this is a second door for it to escape through. Deliberate parent
            // actions (±minutes, gift, reset) push through their own paths.
            let mayPush = ParentSettings.shared.deviceRole != .parent
                || KidModeManager.shared.active
            if switching, mayPush { RemoteSyncManager.shared.pushNow() }
        }
        // 2. Apply incoming snapshot
        let incoming = snapshot(for: profileID)
        ProgressStore.shared.apply(incoming)
        // 3. Bind — the store now holds THIS child's data, and says so. Every
        //    path that writes it out (vault save, cloud upload) checks this.
        ProgressStore.shared.bind(to: profileID)
        boundProfileID = profileID
        // 3b. Restore the incoming kid's own frozen parent time (if any) —
        //     only on a real switch (see step 0)…
        if switching { ProgressStore.shared.restoreDeviceLocalPlayState(for: profileID) }
        //     …then fold ANY device-local frozen time (live or stashed) into the
        //     synced gift pocket — frozen time is no longer device-local. Persist
        //     right away so a kill before the next autosave can't lose it.
        if ProgressStore.shared.migrateFrozenIntoGiftPocket(for: profileID) {
            write(ProgressStore.shared.captureSnapshot(), for: profileID)
        }
        // 4. Reset live caches that don't belong to the new profile
        QuestionMemory.shared.reloadForActiveProfile()
        LearningHistoryStore.shared.bind(to: profileID)
        observeAndAutoSave()
    }

    /// Reset a specific profile's progress to a blank slate. If it's the
    /// active profile we also clear ProgressStore in memory.
    func resetProfile(_ profileID: UUID) {
        if profileID == boundProfileID {
            // Active profile: ProgressStore.resetAll() zeroes the data AND bumps
            // its revision; capture that bumped-blank state and persist it.
            ProgressStore.shared.resetAll()
            write(ProgressStore.shared.captureSnapshot(), for: profileID)
        } else {
            // Non-active profile: bump past the last-known revision so the wipe
            // outranks whatever the kid's other device last synced to the cloud.
            let prior = snapshot(for: profileID)
            var blank = ProgressSnapshot.blank
            blank.revision = prior.revision + 1
            blank.lastModifiedAt = .now
            blank.deviceID = ProgressSnapshot.thisDeviceID
            write(blank, for: profileID)
        }
        QuestionMemory.shared.clear(for: profileID)
    }

    // MARK: - Auto-save (debounced)

    /// Subscribe to ProgressStore changes and persist a fresh snapshot
    /// every ~3 seconds when changes occur. Avoids hammering UserDefaults
    /// on every single field change.
    private func observeAndAutoSave() {
        cancellables.removeAll()
        let store = ProgressStore.shared
        let triggers: [AnyPublisher<Void, Never>] = [
            store.$pendingMinutes.map { _ in () }.eraseToAnyPublisher(),
            store.$parentGiftMinutes.map { _ in () }.eraseToAnyPublisher(),   // 💝 synced pocket
            store.$totalScore.map { _ in () }.eraseToAnyPublisher(),
            store.$stars.map { _ in () }.eraseToAnyPublisher(),
            store.$diamonds.map { _ in () }.eraseToAnyPublisher(),
            store.$xp.map { _ in () }.eraseToAnyPublisher(),
            store.$unlockEndsAt.map { _ in () }.eraseToAnyPublisher(),
            store.$minutesEarnedToday.map { _ in () }.eraseToAnyPublisher(),
            store.$totalCorrect.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(triggers)
            .dropFirst()  // ignore the apply() values we just set
            .sink { [weak self] _ in
                self?.scheduleSave()
            }
            .store(in: &cancellables)
    }

    private func scheduleSave() {
        saveDebounce?.cancel()
        saveDebounce = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            guard let pid = self.boundProfileID else { return }
            self.write(ProgressStore.shared.captureSnapshot(), for: pid)
        }
    }
}
