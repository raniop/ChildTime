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
///
/// Why not Apple's own path: iOS 27.1 can host toolbar items in the vertical
/// bar — `UIBarButtonItem.AxisBehavior.verticalPreferred`, `ToolbarItem` /
/// `.axisBehavior(.verticalPreferred)` in SwiftUI. Tried and measured on the
/// Duo: it moves nothing here, because the header is explicit that an item
/// prefers a vertical placement "when both horizontal and vertical bars are
/// present" — the system hosts a vertical BAR for a tab bar or toolbar, and
/// this app has neither. Worth re-testing if a tab bar is ever added.
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

extension View {
    /// 🎚 Put this screen's own controls in the foldable's bar strip.
    ///
    /// One line per screen, and the rail is drawn where the system's own items
    /// are not (`DisplayGeometry.barStripTop`). On every other device it is not
    /// drawn at all, so a screen can declare a rail unconditionally.
    ///
    /// It is an overlay rather than something the app root renders, because a
    /// sheet and a full-screen cover live in their own hosting controllers — a
    /// preference from inside one never reaches the root, and those are exactly
    /// the screens that were losing the strip.
    func sideRail<Rail: View>(@ViewBuilder _ rail: @escaping () -> Rail) -> some View {
        overlay { SideRailContainer(content: rail) }
    }
}

/// A label under a rail control, for the few that need naming.
struct SideRailLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.8))
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: 54)
            .padding(.top, -5)
    }
}

/// A counter in the rail — ⭐ stars, 💎 diamonds. Tappable when it leads
/// somewhere, and always at least a 44pt target.
struct SideRailCounter: View {
    let emoji: String
    let value: String
    var label: String = ""
    var action: (() -> Void)? = nil

    var body: some View {
        Button {
            guard let action else { return }
            Haptic.light()
            action()
        } label: {
            VStack(spacing: 0) {
                Text(emoji).font(.system(size: 17))
                Text(value)
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(width: 52, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityLabel(label.isEmpty ? value : "\(label) \(value)")
    }
}

extension View {
    /// 🎚 A screen whose only chrome is a way out puts that way out in the rail.
    ///
    /// Sheets and covers — settings, chores, a child's worlds, the paywall —
    /// carry one button and a title. On the foldable the title bar is squeezed
    /// against the top of the glass while the bar's whole strip sits empty, so
    /// the button moves into the strip and the screen keeps its full height.
    /// Hide the toolbar item behind `DisplayGeometry.shared.hasBarStrip` so the
    /// same screen is untouched on every other device.
    func railDismiss(_ label: String, systemImage: String = "xmark",
                     action: @escaping () -> Void) -> some View {
        sideRail { SideRailButton(systemImage: systemImage, label: label, action: action) }
    }
}
