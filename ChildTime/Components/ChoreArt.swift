import SwiftUI
import UIKit

/// 🎨 The picture of a chore (Rani, 2026-10-13: the child's chores screen in
/// pictures, not emoji). Each of the 16 built-in chores has a drawing of its
/// own in `Assets.xcassets/Chores`; a chore a parent wrote with one of the same
/// emoji gets that drawing too; anything else keeps its emoji.
enum ChoreArt {
    /// The built-in chore's key → its drawing ("preset-bed" → "Chore-bed").
    private static let byEmoji: [String: String] = [
        "🛏": "bed", "👕": "clothes", "🍽": "plate", "👟": "shoes", "🧸": "toys", "🍴": "table",
        "🎒": "bag", "🪴": "plants", "🐕": "pet", "🗑": "trash", "📚": "desk", "🧹": "sweep",
        "🧺": "laundry", "🛒": "groceries", "🍳": "cooking", "🎲": "sibling",
    ]

    static func image(for chore: Chore) -> UIImage? {
        if let key = chore.id.split(separator: "_").first, key.hasPrefix("preset-"),
           let img = UIImage(named: "Chore-" + key.dropFirst("preset-".count)) {
            return img
        }
        // The same emoji with or without its "emoji style" mark.
        let plain = String(String.UnicodeScalarView(chore.emoji.unicodeScalars.filter { $0.value != 0xFE0F }))
        return byEmoji[plain].flatMap { UIImage(named: "Chore-" + $0) }
    }

    /// A colour of its own for each chore's row — the same one every time.
    private static let tints = ["3A86FF", "FF7AB6", "06D6A0", "FFB703", "B15EFF"]
    static func tint(for chore: Chore) -> Color {
        let sum = chore.id.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) % 9973 }
        return Color(hex: tints[sum % tints.count])
    }
}

/// The drawing, or the chore's own emoji where there is none.
struct ChorePicture: View {
    let chore: Chore
    var side: CGFloat = 92

    var body: some View {
        Group {
            if let img = ChoreArt.image(for: chore) {
                Image(uiImage: img).resizable().scaledToFit()
            } else {
                Text(chore.emoji).font(.system(size: side * 0.62))
            }
        }
        .frame(width: side, height: side)
        .shadow(color: .black.opacity(0.3), radius: 8, y: 5)
        .accessibilityHidden(true)
    }
}
