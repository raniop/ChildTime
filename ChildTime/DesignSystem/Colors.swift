import SwiftUI

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

enum AppColor {
    // Accents
    static let starGold      = Color(hex: "FFD23F")
    static let gemPurple     = Color(hex: "9B5DE5")
    static let companionGlow = Color(hex: "FFB84D")
    static let companionBody = Color(hex: "FFC94A")
    static let successMint   = Color(hex: "06D6A0")
    static let almostWarm    = Color(hex: "FF9F1C")
    static let flameOrange   = Color(hex: "F25C54")
    static let dreamyIndigo  = Color(hex: "5E60CE")
    static let dreamyTeal    = Color(hex: "48BFE3")

    // Text
    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.65)
    static let textOnLight   = Color(hex: "2B2D42")

    // Glass / surfaces
    static let glass = Color.white.opacity(0.15)
}

enum AppGradient {
    static let dreamy = LinearGradient(
        colors: [AppColor.dreamyIndigo, AppColor.dreamyTeal],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let castle = LinearGradient(
        colors: [Color(hex: "FF6B9D"), Color(hex: "FFB84D")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let tower = LinearGradient(
        colors: [Color(hex: "5E2BFF"), Color(hex: "2E1A6B")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let valley = LinearGradient(
        colors: [Color(hex: "0AAE6B"), Color(hex: "48BFE3")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let gold = LinearGradient(
        colors: [AppColor.starGold, AppColor.companionGlow],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let success = LinearGradient(
        colors: [AppColor.successMint, Color(hex: "118AB2")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let almost = LinearGradient(
        colors: [AppColor.almostWarm, Color(hex: "FFD23F")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let portal = LinearGradient(
        colors: [AppColor.gemPurple, Color(hex: "FF6B9D"), AppColor.gemPurple],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
