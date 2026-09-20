import SwiftUI

/// 🎚 The rail down the foldable's bar strip.
///
/// The iPhone Duo moves the status bar off the top and into a strip down one
/// side — 84pt that every screen otherwise loses, and that made the content
/// look permanently off-centre (Rani: "כל מסך אצלנו נראה כאילו הוא לא ממורכז").
/// Instead of fighting the strip, the parent's home puts its own controls in it.
///
/// Only the TOP of the strip is the system's, and iOS says exactly how much:
/// an `.occlusion` region over it, measured at 170pt closed and 120pt open.
/// Taps above that line are swallowed; taps below it arrive (verified on the
/// Duo simulator — see `DisplayGeometry.barStripTop`). So the rail starts below
/// it and nothing is ever placed where a finger cannot reach.
///
/// The payoff is continuity: the rail sits at a PHYSICAL edge, so unfolding the
/// device does not move it. The column beside it does not move either — the
/// screen only grows a second half. Fold back and that half closes again.
struct SideRailContainer<Content: View>: View {
    @ObservedObject private var display = DisplayGeometry.shared

    /// Rail content, top to bottom. Laid out at the strip's width.
    @ViewBuilder var content: () -> Content

    /// Breathing room under the system's own items.
    private static var topGap: CGFloat { 10 }

    var body: some View {
        if display.hasBarStrip {
            GeometryReader { geo in
                VStack(spacing: 8) { content() }
                    .frame(width: display.barInset)
                    .padding(.top, display.barStripTop + Self.topGap)
                    .padding(.bottom, 12)
                    // The strip is physical: the rail belongs on the bar's own
                    // side of the glass, in Hebrew exactly as in English. Forced
                    // LTR below, so this offset is measured from the real left.
                    .offset(x: display.barOnLeft ? 0 : geo.size.width - display.barInset)
            }
            .ignoresSafeArea()
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

/// One control in the rail — an icon, no label.
struct SideRailButton: View {
    /// An SF Symbol, drawn in the app's white ink…
    var systemImage: String? = nil
    /// …or the emoji the feature already carries everywhere else (🧹 chores).
    var emoji: String? = nil
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.light()
            action()
        } label: {
            icon
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.white.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var icon: some View {
        if let emoji {
            Text(emoji).font(.system(size: 20))
        } else {
            Image(systemName: systemImage ?? "circle")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

/// A child in the rail: their character, their name, and whether they are
/// playing right now. Selecting one is what the second half of the screen shows.
struct SideRailAvatar: View {
    let profile: Profile
    var isSelected: Bool = false
    var isPlaying: Bool = false
    let action: () -> Void

    private static let size: CGFloat = 46

    var body: some View {
        Button {
            Haptic.light()
            action()
        } label: {
            VStack(spacing: 2) {
                ZStack(alignment: .bottomLeading) {
                    avatar
                        .frame(width: Self.size, height: Self.size)
                        .clipShape(Circle())
                        .overlay(
                            Circle().strokeBorder(isSelected ? AppColor.starGold : .white.opacity(0.45),
                                                  lineWidth: isSelected ? 2.5 : 1.5)
                        )
                        .shadow(color: isSelected ? AppColor.starGold.opacity(0.45) : .clear, radius: 6)
                    if isPlaying {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 2))
                    }
                }
                Text(profile.name)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: Self.size + 8)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(profile.name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder private var avatar: some View {
        if let img = profile.character.uiImage
            ?? CharacterSnapshot.image(modelName: profile.character.scn, pixelSize: Self.size * 2) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Circle().fill(.white.opacity(0.2))
                .overlay(Text(String(profile.name.prefix(1)))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white))
        }
    }
}

/// A hairline between groups in the rail.
struct SideRailDivider: View {
    var body: some View {
        Rectangle()
            .fill(.white.opacity(0.28))
            .frame(width: 34, height: 1)
            .padding(.vertical, 2)
    }
}


/// 📐 Take the width back from the bar's mirror.
///
/// On the foldable a `UINavigationController` insets its content by the bar's
/// width on BOTH sides, so the page stays optically centred between the bar and
/// the far edge. With our own rail living in the bar's strip that mirror is just
/// 84pt of dead glass (Rani: "חבל על המקום בצד שמאל" — measured: the parent's
/// home ran 266pt wide inside a 382pt safe area). A screen with no navigation
/// controller never had the mirror and is untouched.
///
/// This reclaims the horizontal safe area and hands back only the side the bar
/// is really on. The layout is done physically, so it is the same page in
/// Hebrew and in English; the content keeps whatever direction it came with.
struct FillBesideBar: ViewModifier {
    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.layoutDirection) private var direction

    func body(content: Content) -> some View {
        if display.hasBarStrip {
            HStack(spacing: 0) {
                if display.barOnLeft { gap }
                content
                    .frame(maxWidth: .infinity)
                    .environment(\.layoutDirection, direction)
                if !display.barOnLeft { gap }
            }
            .environment(\.layoutDirection, .leftToRight)
            .ignoresSafeArea(.container, edges: .horizontal)
        } else {
            content
        }
    }

    private var gap: some View { Color.clear.frame(width: display.barInset) }
}

extension View {
    /// See `FillBesideBar`.
    func fillBesideBar() -> some View { modifier(FillBesideBar()) }
}
