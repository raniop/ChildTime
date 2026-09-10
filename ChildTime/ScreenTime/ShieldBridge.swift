import Foundation

/// Keeps the shield screen's copy truthful.
///
/// The shield extension runs for a couple of seconds with no network and no
/// access to our stores, so everything it shows has to be sitting in the App
/// Group before the child ever taps the locked app. This writes it, from the
/// same numbers the kid's own screens use.
enum ShieldBridge {

    /// Recompute and store what the shield should say. Cheap — call it wherever
    /// the widget is refreshed.
    static func refresh() {
        let p = ProgressStore.shared
        let s = ParentSettings.shared
        let profile = ProfileStore.shared.active

        var state = ShieldState()
        state.childName = profile?.name ?? ""
        state.girl = profile?.gender == .girl
        state.availableMinutes = max(0, p.pendingMinutes)
        state.minutesPerWindow = max(1, s.minutesPerCorrectAnswer * 5)
        state.updatedAt = Date().timeIntervalSince1970

        // Order matters: the daily cap outranks everything (there is nothing the
        // child can do about it), then minutes already waiting, then the ask.
        if s.dailyCapEnabled, p.minutesEarnedToday >= s.maxMinutesPerDay, p.pendingMinutes <= 0 {
            state.mode = .dailyCapReached
        } else if p.pendingMinutes > 0 {
            state.mode = .hasMinutes
        } else {
            state.mode = .needsQuestions
            let perAnswer = max(1, s.minutesPerCorrectAnswer)
            state.questionsToGo = max(1, Int(ceil(Double(state.minutesPerWindow) / Double(perAnswer))))
        }
        state.save()
    }
}
