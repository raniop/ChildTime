import Foundation

/// App version info, read straight from the bundle so it always reflects the
/// real shipped build — never hardcoded.
///
/// `version` is the marketing version — the one a PARENT sees — and reads
/// `YYYY.M.N`: year, month, release within that month (e.g. "2026.9.1"). It says
/// at a glance how fresh the app is, stays valid for Apple (≤3 integers), and
/// always sorts forward (2026.10 > 2026.9, 2027.1 > 2026.12).
///
/// `build` is CFBundleVersion ("141") — an internal counter Apple requires to
/// increase on every upload. Never show it on its own to a parent.
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    /// A DEMO_SCREEN run (screenshots, design review): no once-a-day pop-ups,
    /// no system permission prompts — the screen being reviewed must be visible.
    static let isDemoRun = ProcessInfo.processInfo.environment["DEMO_SCREEN"] != nil

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
    /// Hebrew one-liner, e.g. "גרסה 2026.9.1 (141)".
    static var versionLine: String { "גרסה \(version) (\(build))" }
}
