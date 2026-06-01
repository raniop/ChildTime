import ActivityKit
import Foundation

/// Starts/ends the play-time Live Activity (lock screen + Dynamic Island
/// countdown) when the child opens / runs out of game time.
enum PlayTimeLiveActivity {
    private static var current: Activity<PlayTimeActivityAttributes>?

    /// Begin a countdown Live Activity ending at `endsAt`.
    static func start(endsAt: Date, characterName: String) {
        guard #available(iOS 16.2, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End only the PREVIOUS activity (not "all" — ending all here runs in a
        // Task that races the request below and would immediately kill the new
        // activity, so nothing renders).
        if let previous = current {
            Task { await previous.end(nil, dismissalPolicy: .immediate) }
        }
        current = nil

        let attributes = PlayTimeActivityAttributes(characterName: characterName)
        let state = PlayTimeActivityAttributes.ContentState(endsAt: endsAt)
        let content = ActivityContent(state: state, staleDate: endsAt)
        do {
            current = try Activity.request(attributes: attributes, content: content)
        } catch {
            print("[PlayTimeLiveActivity] start failed: \(error.localizedDescription)")
        }
    }

    /// End the countdown (time's up, locked early, etc.) and clear any strays.
    static func end() {
        guard #available(iOS 16.2, *) else { return }
        let toEnd = current
        current = nil
        Task {
            await toEnd?.end(nil, dismissalPolicy: .immediate)
            for activity in Activity<PlayTimeActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
