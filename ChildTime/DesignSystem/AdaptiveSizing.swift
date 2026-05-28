import SwiftUI

/// Wraps two sizes — one for compact (iPhone) and one for regular (iPad) horizontal size class.
/// Use via `.scaled(for: hsc)` inside a view that has @Environment(\.horizontalSizeClass).
struct AdaptiveValue<T> {
    let compact: T
    let regular: T

    func resolve(_ sizeClass: UserInterfaceSizeClass?) -> T {
        sizeClass == .compact ? compact : regular
    }
}

extension View {
    /// Returns the view modifier-friendly value picker. Used as `.adaptiveFont(.system(size: pick(36, 44)...))`
    /// In practice we just inline `isCompact ? small : big` in each view — this is here as a reference.
    func adaptiveFontSize(compact: CGFloat, regular: CGFloat, _ sizeClass: UserInterfaceSizeClass?) -> some View {
        font(.system(size: sizeClass == .compact ? compact : regular, weight: .bold, design: .rounded))
    }
}

/// Quick adaptive number helpers — used inline.
extension UserInterfaceSizeClass {
    /// Pick compact-value when iPhone, otherwise regular.
    func pick<T>(_ compact: T, _ regular: T) -> T {
        self == .compact ? compact : regular
    }
}

/// For optional size classes — defaults to "regular" if nil (covers preview/macOS cases).
func pickValue<T>(_ compact: T, _ regular: T, sizeClass: UserInterfaceSizeClass?) -> T {
    sizeClass == .compact ? compact : regular
}
