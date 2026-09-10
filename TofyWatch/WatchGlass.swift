import SwiftUI

/// The glass language, tuned for a 41mm screen.
///
/// The phone's `GlassBackdrop` uses 280–320pt orbs — wider than the whole watch.
/// These are the same three brand colours and the same two orbs, sized so they
/// read as light in the corners instead of swallowing the screen.
extension Color {
    init(tofyHex: String) {
        var h: UInt64 = 0
        Scanner(string: tofyHex).scanHexInt64(&h)
        self.init(.sRGB,
                  red: Double((h >> 16) & 0xFF) / 255,
                  green: Double((h >> 8) & 0xFF) / 255,
                  blue: Double(h & 0xFF) / 255,
                  opacity: 1)
    }
}

enum Tofy {
    static let violet = Color(tofyHex: "7A5CFF")
    static let indigo = Color(tofyHex: "5E60CE")
    static let blue   = Color(tofyHex: "3E8BF0")
    static let pink   = Color(tofyHex: "FF7BD3")
    static let teal   = Color(tofyHex: "37E2D5")
    static let mint   = Color(tofyHex: "8CFFC4")
    static let gold   = Color(tofyHex: "FFD23F")
}

struct WatchBackdrop: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors: [Tofy.violet, Tofy.indigo, Tofy.blue],
                               startPoint: UnitPoint(x: 0.62, y: 0),
                               endPoint: UnitPoint(x: 0.38, y: 1))
                Circle().fill(Tofy.pink).frame(width: 120, height: 120)
                    .blur(radius: 26).opacity(0.55)
                    .position(x: 14, y: g.size.height * 0.28)
                Circle().fill(Tofy.teal).frame(width: 130, height: 130)
                    .blur(radius: 26).opacity(0.5)
                    .position(x: g.size.width - 10, y: g.size.height * 0.86)
            }
        }
        .ignoresSafeArea()
    }
}

/// A frosted pane — the watch equivalent of `glassPane`.
struct WatchPane: ViewModifier {
    var radius: CGFloat = 14
    var tint: Color? = nil
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.white.opacity(0.17))
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(tint?.opacity(0.22) ?? .clear)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                    }
            }
    }
}

extension View {
    func watchPane(radius: CGFloat = 14, tint: Color? = nil) -> some View {
        modifier(WatchPane(radius: radius, tint: tint))
    }
}
