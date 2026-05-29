import Foundation

/// How a question session sources its topics.
///
/// - `.world` — the classic focused practice: every question is drawn from one
///   world's topic (the original behavior).
/// - `.smartFeed` — the personalized feed: each question's topic is chosen on
///   the fly by `LearningFeedEngine`, mixing favorites with fresh discoveries.
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
