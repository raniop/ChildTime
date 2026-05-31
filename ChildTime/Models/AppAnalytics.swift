import Foundation

#if canImport(FirebaseAnalytics)
import FirebaseAnalytics
#endif

/// Thin wrapper over Firebase / Google Analytics. Gives a comprehensive picture
/// of usage — active users (DAU/MAU), retention, sessions, and the full learning
/// funnel — WITHOUT ever sending personal data: only structural signals (counts,
/// topic, age band, gender, device kind). No names, emails, or free text.
///
/// Compiles to no-ops until FirebaseAnalytics is linked (SPM). Firebase Analytics
/// is thread-safe, so this is safe to call from anywhere.
enum AppAnalytics {

    // MARK: - Core

    static func log(_ name: String, _ params: [String: Any] = [:]) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(name, parameters: params.isEmpty ? nil : params)
        #endif
    }

    static func setUserProperty(_ value: String?, _ name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.setUserProperty(value, forName: name)
        #endif
    }

    /// Manual screen view (we don't auto-track since most screens are SwiftUI).
    static func screen(_ name: String) {
        #if canImport(FirebaseAnalytics)
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: name])
        #endif
    }

    // MARK: - Audience properties (who is using the app)

    /// Set once we know this device's role + the active child's age/gender band.
    static func describeAudience(role: String, ageBand: String?, gender: String?) {
        setUserProperty(role, "device_role")
        if let ageBand { setUserProperty(ageBand, "child_age_band") }
        if let gender { setUserProperty(gender, "child_gender") }
    }

    static func setSubscribed(_ active: Bool) {
        setUserProperty(active ? "yes" : "no", "is_subscribed")
    }

    // MARK: - Funnel events (no PII)

    static func roleChosen(_ role: String) {
        log("device_role_chosen", ["role": role]); setUserProperty(role, "device_role")
    }
    static func childCreated() { log("child_created") }
    static func deviceJoined(kind: String) { log("device_joined", ["device_kind": kind]) }

    static func sessionStart(mode: String, purpose: String) {
        log("learning_session_start", ["mode": mode, "purpose": purpose])
    }
    static func sessionEnd(questions: Int, accuracy: Int, minutes: Int, stars: Int) {
        log("learning_session_end",
            ["questions": questions, "accuracy": accuracy, "minutes_earned": minutes, "stars": stars])
    }
    static func questionAnswered(topic: String, correct: Bool) {
        log("question_answered", ["topic": topic, "correct": correct ? 1 : 0])
    }

    static func screenTimeOpened(minutes: Int) { log("screen_time_opened", ["minutes": minutes]) }
    static func screenTimeEnded(minutesLeft: Int) { log("screen_time_ended", ["minutes_left": minutesLeft]) }

    static func wheelSpin(bonus: Bool) { log("wheel_spin", ["bonus": bonus ? 1 : 0]) }
    static func chestOpened(kind: String) { log("chest_opened", ["kind": kind]) }
    static func levelUp(_ level: Int) { log("level_up", ["level": level]) }
    static func worldUnlocked(_ id: String) { log("world_unlocked", ["world": id]) }
    static func helpRequested() { log("help_requested") }

    static func paywallView() { log("paywall_view") }
    static func subscribed(_ product: String) { log("subscribe", ["product": product]); setSubscribed(true) }
}
