import Foundation
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// ☁️ Questions that live in the cloud.
///
/// Every question used to ship inside the binary, so reaching 200 per grade
/// (Rani) would have meant an App Store release for every batch. These come
/// from Firestore instead, and reach children the moment they are approved.
///
/// The built-in banks stay: they are the seed for a first launch with no network
/// and the safety net if the cloud is unreachable. This only ever ADDS on top.
///
/// Cost is one tiny read per launch — `questionBankIndex/current` holds a version
/// per topic, and a topic's full document is fetched only when its version moved.
final class RemoteQuestionBank {
    static let shared = RemoteQuestionBank()

    /// Wire format, identical to what the admin import writes.
    struct Item: Codable, Equatable {
        let id: String
        let prompt: String
        let correctAnswer: String
        let distractors: [String]
        let tier: String?
        let gradeLo: Int
        let gradeHi: Int

        init?(_ d: [String: Any]) {
            guard let id = d["id"] as? String,
                  let prompt = d["prompt"] as? String,
                  let answer = d["correctAnswer"] as? String,
                  let distractors = d["distractors"] as? [String],
                  let lo = Self.int(d["gradeLo"]), let hi = Self.int(d["gradeHi"]) else { return nil }
            // Only approved items ever reach a child. Drafts wait in the admin.
            guard (d["status"] as? String ?? "approved") == "approved" else { return nil }
            self.id = id; self.prompt = prompt; self.correctAnswer = answer
            self.distractors = distractors; self.tier = d["tier"] as? String
            self.gradeLo = lo; self.gradeHi = hi
        }

        private static func int(_ v: Any?) -> Int? {
            if let i = v as? Int { return i }
            if let d = v as? Double { return Int(d) }
            if let n = v as? NSNumber { return n.intValue }
            return nil
        }

        /// Defensive: the server validates on import, but a malformed item must
        /// never become a question with its answer among the wrong options.
        var isPlayable: Bool {
            let p = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            let ds = distractors.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            return !p.isEmpty && !a.isEmpty
                && ds.count >= 3
                && !ds.contains(a)
                && Set(ds).count == ds.count
                && (0...6).contains(gradeLo) && (0...6).contains(gradeHi) && gradeLo <= gradeHi
        }

        var bankQuestion: BankQuestion {
            BankQuestion(prompt: prompt, correctAnswer: correctAnswer,
                         distractors: Array(distractors.prefix(3)),
                         tier: tier.flatMap(Difficulty.init(rawValue:)),
                         grades: gradeLo...gradeHi)
        }
    }

    private struct Cache: Codable {
        var versions: [String: Int] = [:]
        var items: [String: [Item]] = [:]
    }

    private var cache = Cache()
    private let lock = NSLock()
    private var syncing = false
    private var lastSyncAt: Date?

    private init() { loadFromDisk() }

    /// Approved cloud questions for a topic, ready to merge. Synchronous — reads
    /// the in-memory cache only, so it is safe on the question runner's hot path.
    func questions(for topic: Topic) -> [BankQuestion] {
        lock.lock(); defer { lock.unlock() }
        return (cache.items[topic.rawValue] ?? []).filter(\.isPlayable).map(\.bankQuestion)
    }

    /// How many cloud items each topic holds — for diagnostics.
    var countsByTopic: [String: Int] {
        lock.lock(); defer { lock.unlock() }
        return cache.items.mapValues(\.count)
    }

    /// Pull any topic whose version moved. Throttled; safe to call on every
    /// foreground.
    func syncIfNeeded(force: Bool = false) {
        #if canImport(FirebaseFirestore)
        lock.lock()
        let recent = lastSyncAt.map { Date().timeIntervalSince($0) < 10 * 60 } ?? false
        guard !syncing, force || !recent else { lock.unlock(); return }
        syncing = true
        lock.unlock()
        Task.detached(priority: .utility) { [weak self] in
            await self?.sync()
        }
        #endif
    }

    #if canImport(FirebaseFirestore)
    private func sync() async {
        var reached = false
        defer {
            // Only a sync that actually reached the server starts the 10-minute
            // quiet period. A denied read (not signed in yet on a fresh install)
            // must retry as soon as the device signs in — otherwise a child who
            // signs in a minute after launch waits ten more for cloud questions.
            lock.lock(); syncing = false; if reached { lastSyncAt = Date() }; lock.unlock()
        }
        let db = Firestore.firestore()
        guard let index = try? await db.collection("questionBankIndex").document("current").getDocument(),
              let topics = index.data()?["topics"] as? [String: Any] else { return }
        reached = true

        var changed = false
        for (raw, value) in topics {
            let version = (value as? Int) ?? (value as? NSNumber)?.intValue ?? 0
            lock.lock(); let have = cache.versions[raw] ?? 0; lock.unlock()
            guard version > have else { continue }
            guard let doc = try? await db.collection("questionBanks").document(raw).getDocument(),
                  let rows = doc.data()?["items"] as? [[String: Any]] else { continue }
            let items = rows.compactMap(Item.init)
            lock.lock()
            cache.items[raw] = items
            cache.versions[raw] = version
            lock.unlock()
            changed = true
        }
        if changed { saveToDisk() }
    }
    #endif

    // MARK: - Disk cache (works fully offline after the first sync)

    private var fileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("remoteQuestionBank.json")
    }

    private func loadFromDisk() {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(Cache.self, from: data) else { return }
        lock.lock(); cache = decoded; lock.unlock()
    }

    private func saveToDisk() {
        guard let url = fileURL else { return }
        lock.lock(); let snapshot = cache; lock.unlock()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }
}
