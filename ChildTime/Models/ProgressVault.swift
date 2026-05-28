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

    /// Persist `snapshot` for `profileID` (overwrites any previous).
    func write(_ snapshot: ProgressSnapshot, for profileID: UUID) {
        var copy = snapshot
        copy.revision += 1
        copy.lastModifiedAt = .now
        copy.deviceID = ProgressSnapshot.thisDeviceID
        if let data = try? JSONEncoder().encode(copy) {
            defaults.set(data, forKey: key(for: profileID))
        }
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
    func switchTo(_ profile: Profile) {
        // 1. Save the outgoing profile
        if let outgoing = boundProfileID {
            write(ProgressStore.shared.captureSnapshot(), for: outgoing)
        }
        // 2. Apply incoming snapshot
        let incoming = snapshot(for: profile.id)
        ProgressStore.shared.apply(incoming)
        // 3. Bind
        boundProfileID = profile.id
        // 4. Reset live caches that don't belong to the new profile
        QuestionMemory.shared.reloadForActiveProfile()
        observeAndAutoSave()
    }

    /// Reset a specific profile's progress to a blank slate. If it's the
    /// active profile we also clear ProgressStore in memory.
    func resetProfile(_ profileID: UUID) {
        let blank = ProgressSnapshot.blank
        write(blank, for: profileID)
        if profileID == boundProfileID {
            ProgressStore.shared.resetAll()
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
            store.$totalScore.map { _ in () }.eraseToAnyPublisher(),
            store.$stars.map { _ in () }.eraseToAnyPublisher(),
            store.$gems.map { _ in () }.eraseToAnyPublisher(),
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
