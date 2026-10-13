import SwiftUI
import UIKit

/// 🎨 The picture of a chore (Rani, 2026-10-13: the chores screens in pictures,
/// not emoji). 48 drawings live in `Assets.xcassets/Chores`: the 16 built-in
/// chores have theirs, and a parent who writes a chore picks one from the
/// picture chooser — or any emoji at all, which then shows as itself.
enum ChoreArt {
    /// Every drawing there is, in the order the parent's picture chooser shows
    /// them, each with the emoji that stands for it. A chore keeps only an
    /// emoji (the same field as ever — nothing new to sync, and an older app or
    /// the watch still shows something sensible); the drawing is found from it.
    static let library: [(key: String, emoji: String)] = [
        // around the room
        ("bed", "🛏️"), ("sweep", "🧹"), ("toys", "🧸"), ("desk", "📚"), ("clothes", "👕"), ("laundry", "🧺"),
        ("socks", "🧦"), ("shoes", "👟"), ("coat", "🧥"), ("lights", "💡"),
        // kitchen and table
        ("plate", "🍽️"), ("table", "🍴"), ("dishes", "🧽"), ("cooking", "🍳"), ("groceries", "🛒"),
        ("lunchbox", "🥪"), ("trash", "🗑️"), ("recycle", "♻️"),
        // around the house
        ("mop", "🪣"), ("window", "🪟"), ("plants", "🪴"), ("garden", "🍂"), ("carwash", "🚗"), ("mail", "📬"),
        // pets
        ("pet", "🐕"), ("walkdog", "🦮"), ("cat", "🐈"), ("fish", "🐠"),
        // me, every day
        ("wakeup", "⏰"), ("dress", "👚"), ("teeth", "🦷"), ("hands", "🧼"), ("shower", "🚿"), ("bath", "🛁"),
        ("breakfast", "🥣"), ("veggies", "🥦"), ("water", "🥛"), ("bedtime", "🌙"),
        // school and me
        ("bag", "🎒"), ("homework", "✏️"), ("reading", "📖"), ("music", "🎹"), ("screens", "📵"),
        // with others, and moving
        ("sibling", "🎲"), ("baby", "🍼"), ("kindness", "❤️"), ("ball", "⚽"), ("bike", "🚲"),
    ]

    /// The same emoji with or without its "emoji style" mark.
    private static func plain(_ emoji: String) -> String {
        String(String.UnicodeScalarView(emoji.unicodeScalars.filter { $0.value != 0xFE0F }))
    }
    private static let byEmoji: [String: String] =
        Dictionary(library.map { (plain($0.emoji), $0.key) }, uniquingKeysWith: { first, _ in first })

    /// The drawing that stands for this emoji, if there is one.
    static func key(forEmoji emoji: String) -> String? { byEmoji[plain(emoji)] }
    static func image(key: String) -> UIImage? { UIImage(named: "Chore-" + key) }

    static func image(for chore: Chore) -> UIImage? {
        // A built-in chore: its own drawing, by its key ("preset-bed_<child>").
        if let key = chore.id.split(separator: "_").first, key.hasPrefix("preset-"),
           let img = image(key: String(key.dropFirst("preset-".count))) {
            return img
        }
        return key(forEmoji: chore.emoji).flatMap(image(key:))
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
