import Foundation

/// The brain of the Smart Learning Feed. Given what we've learned about a child
/// (`LearningProfile`) and the topics already served this session, it picks the
/// next topic — balancing **exploit** (topics the child loves) with **explore**
/// (fresh topics they've barely met), and letting genuinely-enjoyed new topics
/// graduate into favorites over time (the discovery loop).
///
/// Pure value type: no state, no side effects. All adaptation lives in the
/// affinity / exposure signals the profile carries.
struct LearningFeedEngine {

    let profile: LearningProfile

    /// Softmax temperature for exploit sampling. Lower = greedier toward the
    /// current favorite; higher = flatter. 0.5 keeps favorites dominant while
    /// still giving other liked topics a real chance.
    private let exploitTemperature = 0.5

    /// The universe of topics we're allowed to serve — strictly the parent's
    /// enabled set, so parental control is never bypassed.
    private var universe: [Topic] {
        let enabled = Array(profile.enabledTopics)
        return enabled.isEmpty ? Topic.allCases : enabled
    }

    // MARK: - Public API

    /// Picks the topic for the next question. `history` is the ordered list of
    /// topics already served this session; `index` is the 0-based position of
    /// the question about to be created.
    func nextTopic(history: [Topic], index: Int) -> Topic {
        let pool = universe
        guard pool.count > 1 else { return pool.first ?? .math }

        // Drop a topic that has already run twice in a row, for variety.
        let candidates = antiRepeatFiltered(pool, history: history)

        let topic = isExploreSlot(index: index)
            ? exploreTopic(from: candidates)
            : exploitTopic(from: candidates)
        return topic
    }

    /// Builds a full session plan up front (used for previews / tests). The live
    /// runner calls `nextTopic` per question so it reacts to in-session signals,
    /// but a static plan is handy for inspection.
    func plan(length: Int) -> [Topic] {
        var history: [Topic] = []
        for i in 0..<max(0, length) {
            history.append(nextTopic(history: history, index: i))
        }
        return history
    }

    // MARK: - Explore / exploit ratio

    /// The share of questions that should explore fresh topics. Base 20%, nudged
    /// by how the child is doing: thriving → push discovery (30%); struggling →
    /// stay in the comfort zone (10%).
    var exploreRatio: Double {
        let acc = profile.overallAccuracy
        if acc > 0.85 { return 0.30 }
        if acc < 0.50 { return 0.10 }
        return 0.20
    }

    /// Spreads explore slots evenly through the session (e.g. ratio 0.2 →
    /// every 5th question explores).
    private func isExploreSlot(index: Int) -> Bool {
        let cadence = max(2, Int((1.0 / exploreRatio).rounded()))
        return (index + 1) % cadence == 0
    }

    // MARK: - Selection

    /// Exploit: weighted sampling by learned affinity among topics the child has
    /// already met. Falls back to the full universe (seeded affinity) early on.
    private func exploitTopic(from candidates: [Topic]) -> Topic {
        let met = candidates.filter { profile.exposure(for: $0) > 0 }
        let pool = met.isEmpty ? candidates : met
        let weights = pool.map { exp(profile.affinity(for: $0) / exploitTemperature) }
        return weightedPick(pool, weights: weights) ?? pool.randomElement() ?? candidates[0]
    }

    /// Explore: bias hard toward the least-seen topics so new worlds surface.
    private func exploreTopic(from candidates: [Topic]) -> Topic {
        let maxExposure = candidates.map { profile.exposure(for: $0) }.max() ?? 0
        // Inverse-exposure weight: never-seen topics get the largest weight.
        let weights = candidates.map { Double(maxExposure - profile.exposure(for: $0)) + 1.0 }
        return weightedPick(candidates, weights: weights) ?? candidates.randomElement() ?? candidates[0]
    }

    // MARK: - Helpers

    /// Removes a topic that already appears as the last two consecutive picks,
    /// unless that would leave nothing to choose from.
    private func antiRepeatFiltered(_ pool: [Topic], history: [Topic]) -> [Topic] {
        guard history.count >= 2 else { return pool }
        let last = history[history.count - 1]
        let prev = history[history.count - 2]
        guard last == prev else { return pool }
        let filtered = pool.filter { $0 != last }
        return filtered.isEmpty ? pool : filtered
    }

    /// Roulette-wheel selection over non-negative weights.
    private func weightedPick(_ items: [Topic], weights: [Double]) -> Topic? {
        guard items.count == weights.count, !items.isEmpty else { return nil }
        let total = weights.reduce(0, +)
        guard total > 0 else { return items.randomElement() }
        var roll = Double.random(in: 0..<total)
        for (item, w) in zip(items, weights) {
            roll -= w
            if roll < 0 { return item }
        }
        return items.last
    }
}
