import Foundation

/// How a question session sources its topics.
///
/// - `.world` — the classic focused practice: every question is drawn from one
///   world's topic (the original behavior).
/// - `.smartFeed` — the personalized feed: each question's topic is chosen on
///   the fly by `LearningFeedEngine`, mixing favorites with fresh discoveries.
/// Why the child is in a session — the second, orthogonal axis to `SessionMode`.
///
/// - `earnTime`: the Earn-to-Unlock flow (default screen-time context). Capped
///   at ≤30 questions, grants screen-time minutes, ends with an earnings screen.
/// - `freePlay`: the child opened Tofy voluntarily to learn/play. No question
///   cap, no screen-time minutes — the reward is in-game progression (XP, coins,
///   chests, wheel, levels, worlds).
enum SessionPurpose: Equatable {
    case earnTime
    case freePlay

    var grantsScreenTime: Bool { self == .earnTime }
}

enum SessionMode: Equatable {
    case world(World)
    case smartFeed

    var isFeed: Bool {
        if case .smartFeed = self { return true }
        return false
    }

    /// The fixed topic for a world session; nil for the feed (topic varies).
    var fixedTopic: Topic? {
        if case let .world(world) = self { return world.topic }
        return nil
    }
}

extension Worlds {
    /// The world used to theme a given topic (background, orbs, glow). Drives the
    /// per-question visuals in the Smart Feed. Falls back to the first world.
    static func forTopic(_ topic: Topic) -> World {
        all.first { $0.topic == topic } ?? all[0]
    }
}
