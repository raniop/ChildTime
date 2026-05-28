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
    func start() {
        #if canImport(FirebaseFirestore)
        guard let uid = AuthManager.shared.userID, !uid.isEmpty else {
            lastError = "אין משתמש מחובר — סנכרון לא פעיל"
            isActive = false
            return
        }
        isActive = true
        lastError = nil
        observeLocalChanges()
        subscribeToAllProfiles(uid: uid)
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
        saveDebounce?.cancel()
        saveDebounce = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.uploadActiveProfile()
        }
    }

    #if canImport(FirebaseFirestore)
    private func uploadActiveProfile() {
        guard let uid = AuthManager.shared.userID else { return }
        guard let pid = ProfileStore.shared.activeID else { return }
        let snapshot = ProgressStore.shared.captureSnapshot()
        guard let data = Self.encode(snapshot) else { return }
        db.collection("users").document(uid)
          .collection("profiles").document(pid.uuidString)
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
        // Listen on the user's collection so we react when new profiles
        // are created on another device, too.
        db.collection("users").document(uid)
          .collection("profiles")
          .addSnapshotListener { [weak self] _, _ in
              self?.refreshProfileSubscriptions(uid: uid)
          }
        refreshProfileSubscriptions(uid: uid)
    }

    private func refreshProfileSubscriptions(uid: String) {
        // Drop listeners for profiles we no longer have locally.
        let localIDs = Set(ProfileStore.shared.profiles.map { $0.id.uuidString })
        for (id, listener) in listeners where !localIDs.contains(id) {
            listener.remove()
            listeners.removeValue(forKey: id)
            if let uuid = UUID(uuidString: id) {
                remoteSnapshots.removeValue(forKey: uuid)
            }
        }
        // Add listeners for new ones.
        for profile in ProfileStore.shared.profiles {
            let id = profile.id.uuidString
            if listeners[id] != nil { continue }
            let listener = db.collection("users").document(uid)
                .collection("profiles").document(id)
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
        // Skip echoes of our own write.
        if snap.deviceID == ProgressSnapshot.thisDeviceID { return }
        // Store for the dashboard.
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
