import Foundation

enum AppGroup {
    static let id = "group.com.childtime.shared"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}
