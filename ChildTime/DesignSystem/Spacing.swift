import SwiftUI

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
    static let huge: CGFloat = 16
}

/// ONE corner for every frame in the app (Rani, 2026-10-08: "כל המסגרות חייבות
/// להיות אותו CornerRound … הכל יותר מלבני"). The names stay for the call sites.
enum AppRadius {
    static let small: CGFloat = 16
    static let medium: CGFloat = 16
    static let large: CGFloat = 16
    static let huge: CGFloat = 16
}
