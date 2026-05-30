import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Cross-device sync layer for per-profile progress snapshots.
///
/// Topology (when the parent is signed in via Firebase Auth):
///   `users/{uid}/profiles/{profileID}/state` ← live document
///
/// Each device:
///   • Uploads its captured `ProgressSnapshot` whenever it changes
///     (debounced through the same path the Vault uses for local saves).
///   • Listens to *all* of the user's profile docs and merges newer
///     remote snapshots back into local state.
///
/// 'Newer' is decided by `revision`, then `lastModifiedAt`. The
/// `deviceID` field lets us skip echoes of our own writes.
///
/// Without FirebaseFirestore in the build (e.g. SDK not added yet),
/// every method is a no-op so the app still compiles and runs.
@MainActor
final class RemoteSyncManager: ObservableObject {
    static let shared = RemoteSyncManager()

    @Published private(set) var isActive = false
    @Published private(set) var lastUploadAt: Date? = nil
    @Published private(set) var lastError: String? = nil
    /// Snapshots pulled from Firestore for non-active profiles, keyed by
    /// profile UUID. The dashboard merges these in.
    @Published private(set) var remoteSnapshots: [UUID: ProgressSnapshot] = [:]

    private var cancellables: Set<AnyCancellable> = []
    private var saveDebounce: Task<Void, Never>? = nil

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var listeners: [String: ListenerRegistration] = [:]   // keyed by profileID
    #endif

    private init() {}

    // MARK: - Public lifecycle

    /// Start syncing for the currently-signed-in parent. Idempotent.
    ///
    /// Pass `explicitUID` when calling from inside `AuthManager` so we
    /// don't reach back into `AuthManager.shared` while *that* singleton
    /// is still inside its own dispatch_once init. Without the explicit
    /// uid we deadlock the launcher with EXC_BREAKPOINT.
    func start(uid explicitUID: String? = nil) {
        #if canImport(FirebaseFirestore)
        let resolvedUID: String
        if let explicitUID, !explicitUID.isEmpty {
            resolvedUID = explicitUID
        } else if let cached = AuthManager.shared.userID, !cached.isEmpty {
            resolvedUID = cached
        } else {
            lastError = "אין משתמש מחובר — סנכרון לא פעיל"
            isActive = false
            return
        }
        isActive = true
        lastError = nil
        observeLocalChanges()
        subscribeToAllProfiles(uid: resolvedUID)
        // First push of the active profile's current state so the cloud
        // mirrors what's on disk.
        uploadActiveProfileSoon()
        #else
        lastError = "Firebase Firestore לא הותקן"
        isActive = false
        #endif
    }

    /// Tear down on sign-out.
    func stop() {
        cancellables.removeAll()
        saveDebounce?.cancel()
        saveDebounce = nil
        #if canImport(FirebaseFirestore)
        for (_, listener) in listeners { listener.remove() }
        listeners.removeAll()
        #endif
        isActive = false
        remoteSnapshots = [:]
    }

    /// Force-write the current active profile's snapshot now (used after
    /// the parent taps reset, so the kid's other device sees it fast).
    func pushNow() {
        #if canImport(FirebaseFirestore)
        uploadActiveProfile()
        #endif
    }

    /// Parent action: grant/spend a child's play-minutes by editing the CLOUD
    /// snapshot directly, in a transaction that BUMPS the revision so the child's
    /// device accepts it (a stale local push from the parent would otherwise lose
    /// the revision race and be ignored). Works for ANY child, active or not.
    func adjustChildMinutes(childID: UUID, deltaMinutes: Int) {
        #if canImport(FirebaseFirestore)
        let ref = db.collection("children").document(childID.uuidString)
            .collection("state").document("current")
        db.runTransaction({ txn, _ -> Any? in
            let existing = try? txn.getDocument(ref)
            var snap = (existing?.data()).flatMap { Self.decode($0) } ?? ProgressSnapshot()
            snap.pendingMinutes = max(0, snap.pendingMinutes + deltaMinutes)
            snap.revision += 1
            snap.lastModifiedAt = Date()
            snap.deviceID = ProgressSnapshot.thisDeviceID
            if let data = Self.encode(snap) {
                txn.setData(data, forDocument: ref, merge: true)
            }
            return nil
        }) { [weak self] _, _ in
            self?.refreshNow()
        }
        #endif
    }

    /// Force an immediate re-fetch of every child's cloud state (used by the
    /// parent's "refresh" button). Also re-ensures the live listeners are
    /// attached, in case they were dropped.
    func refreshNow() {
        #if canImport(FirebaseFirestore)
        refreshProfileSubscriptions()
        for profile in ProfileStore.shared.profiles {
            let id = profile.id.uuidString
            db.collection("children").document(id)
              .collection("state").document("current")
              .getDocument { [weak self] doc, _ in
                  guard let raw = doc?.data(), let snap = Self.decode(raw) else { return }
                  self?.handleRemoteSnapshot(snap, profileID: profile.id)
              }
        }
        #endif
    }

    // MARK: - Local change observation

    private func observeLocalChanges() {
        cancellables.removeAll()
        let store = ProgressStore.shared
        let triggers: [AnyPublisher<Void, Never>] = [
            store.$pendingMinutes.map { _ in () }.eraseToAnyPublisher(),
            store.$totalScore.map { _ in () }.eraseToAnyPublisher(),
            store.$stars.map { _ in () }.eraseToAnyPublisher(),
            store.$gems.map { _ in () }.eraseToAnyPublisher(),
            store.$unlockEndsAt.map { _ in () }.eraseToAnyPublisher(),
            store.$minutesEarnedToday.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(triggers)
            .dropFirst()
            .sink { [weak self] _ in self?.uploadActiveProfileSoon() }
            .store(in: &cancellables)
    }

    // MARK: - Upload (debounced ~3s)

    private func uploadActiveProfileSoon() {
        // The parent control-center device is a MONITOR — it must never push its
        // own (empty) local state, or it clobbers the child's real cloud data
        // with zeros. Explicit parent actions (reset / ±minutes) still go through
        // pushNow() → uploadActiveProfile().
        guard ParentSettings.shared.deviceRole != .parent else { return }
        saveDebounce?.cancel()
        saveDebounce = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.uploadActiveProfile()
        }
    }

    #if canImport(FirebaseFirestore)
    private func uploadActiveProfile() {
        guard let pid = ProfileStore.shared.activeID else { return }
        let snapshot = ProgressStore.shared.captureSnapshot()
        guard let data = Self.encode(snapshot) else { return }
        // Children are household-owned (top-level `children` collection) so
        // co-parents on different uids can both sync. Access is gated by
        // firestore.rules (uid must be on the child's household).
        db.collection("children").document(pid.uuidString)
          .collection("state").document("current")
          .setData(data, merge: true) { [weak self] err in
              if let err {
                  self?.lastError = err.localizedDescription
              } else {
                  self?.lastUploadAt = .now
                  self?.lastError = nil
              }
          }
    }
    #endif

    // MARK: - Listeners (per profile)

    #if canImport(FirebaseFirestore)
    private func subscribeToAllProfiles(uid: String) {
        // React when the local roster of children changes (e.g. a co-parent's
        // child arrives via the household listener) by re-subscribing.
        ProfileStore.shared.$profiles
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshProfileSubscriptions() }
            .store(in: &cancellables)
        refreshProfileSubscriptions()
    }

    private func refreshProfileSubscriptions() {
        // Drop listeners for children we no longer have locally.
        let localIDs = Set(ProfileStore.shared.profiles.map { $0.id.uuidString })
        for (id, listener) in listeners where !localIDs.contains(id) {
            listener.remove()
            listeners.removeValue(forKey: id)
            if let uuid = UUID(uuidString: id) {
                remoteSnapshots.removeValue(forKey: uuid)
            }
        }
        // Add listeners for new ones — household-owned `children` docs.
        for profile in ProfileStore.shared.profiles {
            let id = profile.id.uuidString
            if listeners[id] != nil { continue }
            let listener = db.collection("children").document(id)
                .collection("state").document("current")
                .addSnapshotListener { [weak self] doc, _ in
                    guard let self, let doc, let raw = doc.data() else { return }
                    guard let snap = Self.decode(raw) else { return }
                    self.handleRemoteSnapshot(snap, profileID: profile.id)
                }
            listeners[id] = listener
        }
    }

    private func handleRemoteSnapshot(_ snap: ProgressSnapshot, profileID: UUID) {
        // Always cache for the dashboard — the parent monitor must reflect the
        // cloud even when THIS device made the last write (e.g. a +minutes
        // grant). Skipping our own writes here is what made the parent's view
        // stop updating after it edited a child.
        remoteSnapshots[profileID] = snap
        // If this is the ACTIVE profile and the remote snapshot is newer
        // than what we have locally, apply it (so a reset on the parent's
        // phone propagates to the kid's iPad in real time).
        guard profileID == ProfileStore.shared.activeID else {
            // For non-active profiles, mirror into the vault so the
            // dashboard reflects the latest cloud state immediately.
            ProgressVault.shared.write(snap, for: profileID)
            return
        }
        // Don't re-apply our OWN echo to the live in-memory store (it would fight
        // local play). Display caching above already happened.
        if snap.deviceID == ProgressSnapshot.thisDeviceID { return }
        let local = ProgressStore.shared.captureSnapshot()
        if snap.revision > local.revision ||
           (snap.revision == local.revision && snap.lastModifiedAt > local.lastModifiedAt) {
            ProgressStore.shared.apply(snap)
        }
    }
    #endif

    // MARK: - Encode / decode (Firestore-friendly)

    private static func encode(_ snap: ProgressSnapshot) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(snap),
              let any = try? JSONSerialization.jsonObject(with: data),
              let dict = any as? [String: Any]
        else { return nil }
        return dict
    }

    private static func decode(_ raw: [String: Any]) -> ProgressSnapshot? {
        guard let data = try? JSONSerialization.data(withJSONObject: raw),
              let snap = try? JSONDecoder().decode(ProgressSnapshot.self, from: data)
        else { return nil }
        return snap
    }
}
