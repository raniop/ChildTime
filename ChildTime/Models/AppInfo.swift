import Foundation

/// App version info, read straight from the bundle so it always reflects the
/// real shipped build — never hardcoded. `version` is the marketing version
/// (CFBundleShortVersionString, e.g. "1.0"); `build` is CFBundleVersion ("33").
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
    }
    /// Hebrew one-liner, e.g. "גרסה 1.0 (33)".
    static var versionLine: String { "גרסה \(version) (\(build))" }
}
