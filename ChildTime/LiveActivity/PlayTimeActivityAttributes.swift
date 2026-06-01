import ActivityKit
import Foundation

/// Shared between the app (which starts/ends the activity) and the
/// PlayTimeWidget extension (which renders it). MUST be a member of BOTH targets
/// — otherwise ActivityKit treats them as different types and nothing shows.
struct PlayTimeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Wall-clock moment the play window ends — drives the live countdown.
        var endsAt: Date
    }

    /// The child's chosen character name (a cute label on the activity).
    var characterName: String
}
