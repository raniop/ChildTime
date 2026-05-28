import SwiftUI

enum AppFont {
    static func hero() -> Font { .system(size: 80, weight: .heavy, design: .rounded) }
    static func title() -> Font { .system(size: 56, weight: .bold, design: .rounded) }
    static func question() -> Font { .system(size: 48, weight: .bold, design: .rounded) }
    static func option() -> Font { .system(size: 44, weight: .bold, design: .rounded) }
    static func subtitle() -> Font { .system(size: 28, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 22, weight: .medium, design: .rounded) }
    static func caption() -> Font { .system(size: 16, weight: .medium, design: .rounded) }
    static func bubble() -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
}

extension View {
    func heroStyle() -> some View { font(AppFont.hero()).foregroundStyle(AppColor.textPrimary) }
    func titleStyle() -> some View { font(AppFont.title()).foregroundStyle(AppColor.textPrimary) }
    func questionStyle() -> some View { font(AppFont.question()).foregroundStyle(AppColor.textPrimary) }
    func subtitleStyle() -> some View { font(AppFont.subtitle()).foregroundStyle(AppColor.textSecondary) }
}
