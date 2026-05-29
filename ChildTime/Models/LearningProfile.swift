import Foundation

/// A read-only snapshot of what the system has learned about one child, derived
/// on demand from `ProgressStore`'s per-topic signals. Nothing here is persisted
/// separately — it's a projection used by the Smart Feed engine and the parent
/// dashboard so both share one definition of "favorite", "strong", "weak", etc.
struct LearningProfile {

    // Raw signals (copied from the store at build time).
    let age: ChildAge
    let enabledTopics: Set<Topic>
    private let accuracy: [Topic: Double]
    private let answered: [Topic: Int]
    private let affinity: [Topic: Double]
    private let exposure: [Topic: Int]
    private let abandon: [Topic: Int]
    private let responseMs: [Topic: Double]

    /// Topics need at least this many answers before we trust their accuracy
    /// label (strong / weak), so a single lucky or unlucky answer can't brand a
    /// topic.
    private static let confidentSampleCount = 4

    // MARK: - Build from the live store

    init(store: ProgressStore, settings: ParentSettings) {
        self.age = settings.childAge
        self.enabledTopics = settings.enabledTopics

        var acc: [Topic: Double] = [:]
        var ans: [Topic: Int] = [:]
        var aff: [Topic: Double] = [:]
        var exp: [Topic: Int] = [:]
        var aband: [Topic: Int] = [:]
        var resp: [Topic: Double] = [:]
        for topic in Topic.allCases {
            acc[topic] = store.accuracy(for: topic)
            ans[topic] = store.topicAnswered[topic.rawValue] ?? 0
            aff[topic] = store.affinity(for: topic)
            exp[topic] = store.exposure(for: topic)
            aband[topic] = store.topicAbandon[topic.rawValue] ?? 0
            if let ms = store.responseMs(for: topic) { resp[topic] = ms }
        }
        self.accuracy = acc
        self.answered = ans
        self.affinity = aff
        self.exposure = exp
        self.abandon = aband
        self.responseMs = resp
    }

    /// Build from a stored snapshot (e.g. the parent dashboard, which reads
    /// per-profile snapshots without making that profile active).
    init(snapshot s: ProgressSnapshot, enabledTopics: Set<Topic>, age: ChildAge) {
        self.age = age
        self.enabledTopics = enabledTopics

        var acc: [Topic: Double] = [:]
        var ans: [Topic: Int] = [:]
        var aff: [Topic: Double] = [:]
        var exp: [Topic: Int] = [:]
        var aband: [Topic: Int] = [:]
        var resp: [Topic: Double] = [:]
        for topic in Topic.allCases {
            let raw = topic.rawValue
            acc[topic] = s.topicAccuracy[raw] ?? 0.7
            ans[topic] = s.topicAnswered[raw] ?? 0
            aff[topic] = s.topicAffinity[raw] ?? (enabledTopics.contains(topic) ? 0.6 : 0.4)
            exp[topic] = s.topicExposure[raw] ?? 0
            aband[topic] = s.topicAbandon[raw] ?? 0
            if let ms = s.topicResponseMs[raw] { resp[topic] = ms }
        }
        self.accuracy = acc
        self.answered = ans
        self.affinity = aff
        self.exposure = exp
        self.abandon = aband
        self.responseMs = resp
    }

    // MARK: - Per-topic lookups

    func affinity(for topic: Topic) -> Double { affinity[topic] ?? 0.5 }
    func exposure(for topic: Topic) -> Int { exposure[topic] ?? 0 }
    func successRate(for topic: Topic) -> Double { accuracy[topic] ?? 0 }
    func avgResponseMs(for topic: Topic) -> Double? { responseMs[topic] }

    /// Average success rate across topics the child has actually met. Defaults
    /// to a neutral 0.7 before there's any history.
    var overallAccuracy: Double {
        let met = Topic.allCases.filter { (answered[$0] ?? 0) > 0 }
        guard !met.isEmpty else { return 0.7 }
        return met.reduce(0.0) { $0 + successRate(for: $1) } / Double(met.count)
    }

    private func isConfident(_ topic: Topic) -> Bool {
        (answered[topic] ?? 0) >= Self.confidentSampleCount
    }

    // MARK: - Derived groupings (for the parent dashboard)

    /// Topics the child gravitates to, highest affinity first. Only topics the
    /// child has actually met (exposure > 0).
    var favorites: [Topic] {
        enabledTopics
            .filter { exposure(for: $0) > 0 }
            .sorted { affinity(for: $0) > affinity(for: $1) }
    }

    /// Topics with confidently high accuracy.
    var strong: [Topic] {
        Topic.allCases
            .filter { isConfident($0) && successRate(for: $0) >= 0.8 }
            .sorted { successRate(for: $0) > successRate(for: $1) }
    }

    /// Topics the child struggles with — candidates for gentle reinforcement.
    var weak: [Topic] {
        Topic.allCases
            .filter { isConfident($0) && successRate(for: $0) < 0.5 }
            .sorted { successRate(for: $0) < successRate(for: $1) }
    }

    /// Topics the child barely meets — the explore frontier.
    var unexplored: [Topic] {
        enabledTopics
            .filter { exposure(for: $0) < Self.confidentSampleCount }
            .sorted { exposure(for: $0) < exposure(for: $1) }
    }

    /// Topics the child tends to bail on (highest abandonment first).
    var abandoned: [Topic] {
        Topic.allCases
            .filter { (abandon[$0] ?? 0) > 0 }
            .sorted { (abandon[$0] ?? 0) > (abandon[$1] ?? 0) }
    }

    /// Topics newly "discovered": low exposure yet high affinity — the child
    /// took to something fresh. Surfaced to the parent as growth.
    var discovering: [Topic] {
        enabledTopics
            .filter { exposure(for: $0) > 0 && exposure(for: $0) < 8 && affinity(for: $0) >= 0.65 }
            .sorted { affinity(for: $0) > affinity(for: $1) }
    }
}
