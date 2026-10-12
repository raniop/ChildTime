import SwiftUI

/// ⚙️ ONE settings window (Rani, 2026-10-11: "אני לוחץ הגדרות של נוני, זה סוגר
/// את המסך ואז פותח מסך הגדרות חדש — זה נורא"). The gear opens one sheet with
/// one navigation stack; a child's settings, an editor, the map and the pairing
/// code all slide IN and the back arrow goes one step back. Nothing closes and
/// reopens. "סיום" is on the window's FIRST page only: a pushed page has one
/// button, its back arrow — the two side by side read as two ways out (Rani,
/// 2026-10-12: "למה יש גם סיום וגם X?"). The window still closes from any depth
/// by pulling it down.
///
/// A page that can also stand alone in a sheet of its own (the editors do, from
/// the child's card) takes `embedded`: alone it brings its own stack and its
/// own "סיום"; inside the settings window it brings neither.
struct SettingsStack<Content: View>: View {
    var embedded = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        // These windows are drawn for white text on the backdrop. In the phone's
        // LIGHT mode the bar's title and "סיום" came out black over it (Rani,
        // 2026-10-12: "הכול רשום בלבן ואז פתאום הכותרות בשחור") — the window is
        // dark whatever the phone is set to.
        if embedded { content() } else { NavigationStack { content() }.preferredColorScheme(.dark) }
    }
}

private struct CloseSettingsKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    /// Closes the WHOLE settings window. Set by the window's root; a pushed page
    /// calls it from its "סיום".
    var closeSettings: (() -> Void)? {
        get { self[CloseSettingsKey.self] }
        set { self[CloseSettingsKey.self] = newValue }
    }
}

extension View {
    /// The foldable's corner "סיום" — only when this page stands alone. Pushed
    /// inside the settings window, the window's own corner button is the one.
    @ViewBuilder
    func railDismiss(unless embedded: Bool, _ label: String, systemImage: String = "xmark",
                     action: @escaping () -> Void) -> some View {
        if embedded { self } else { railDismiss(label, systemImage: systemImage, action: action) }
    }
}

// MARK: - 📐 The foldable: the settings window's own top row

/// On the foldable the system takes a pushed page's back button OUT of the
/// navigation bar and floats it in the vertical bar's column — measured
/// 2026-10-12: in English it sat under the clock, on top of the page's first
/// row. A button of ours in the bar lands in the same spot. So on that device
/// the settings window hides the system's bar (`settingsBand`) and every page
/// carries this row as the first thing in its content, the way the child's page
/// does: the arrow (or the first page's "סיום") in the corner AWAY from the
/// clock, the title on the reading side, and the content starting below the
/// clock. On every other device there is no row, and the system's bar stays.
struct SettingsBandRow: View {
    let title: String
    /// False for a page standing alone in its own sheet: it keeps the system's bar.
    var active = true
    /// The window's first page passes its "סיום"; a pushed page gets the back arrow.
    var done: (() -> Void)? = nil
    /// What already sits above the row inside the page (top safe area + the page's own padding).
    var above: CGFloat = DisplayProbeView.minimumTopMargin
    /// The page's own side margin — the row stops short of the clock by the rest.
    var sideInset: CGFloat = AppSpacing.lg

    @ObservedObject private var display = DisplayGeometry.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if active && display.hasBarStrip {
            let farIsLeft = !display.barOnLeft
            // The title sits on the reading side: beside the arrow when that is
            // the far side, at the other end of the row when it is the clock's.
            let titleBesideControl = LanguageStore.shared.current.isRightToLeft != farIsLeft
            HStack(spacing: 12) {
                control
                if !titleBesideControl { Spacer(minLength: 8) }
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .environment(\.layoutDirection, .app)
                if titleBesideControl { Spacer(minLength: 8) }
            }
            // Laid out so the control lands on the PHYSICAL far side; trailing is the clock's.
            .padding(.trailing, max(0, display.barInset - sideInset) + 6)
            .environment(\.layoutDirection, farIsLeft ? .leftToRight : .rightToLeft)
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(44, display.barStripTop - above), alignment: .top)
        }
    }

    @ViewBuilder private var control: some View {
        if let done {
            Button { Haptic.light(); done() } label: {
                Text(tr("סיום"))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
        } else {
            Button { Haptic.light(); dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("חזרה"))
        }
    }
}

/// `SettingsBandRow` as the first row of a Form.
struct SettingsBandHeader: View {
    let title: String
    var active = true
    @ObservedObject private var display = DisplayGeometry.shared

    var body: some View {
        if active && display.hasBarStrip {
            Section {
                SettingsBandRow(title: title, above: DisplayProbeView.minimumTopMargin + Self.formTop, sideInset: 20)
                    .padding(.top, Self.formTop)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
        }
    }

    /// The same 8pt the first page's row has above it, so the arrow sits level
    /// with that page's "סיום" (the Form's own top margin is removed in `settingsBand`).
    static let formTop: CGFloat = AppSpacing.sm
}

private struct SettingsBandBar: ViewModifier {
    let active: Bool
    @ObservedObject private var display = DisplayGeometry.shared

    func body(content: Content) -> some View {
        if active && display.hasBarStrip, #available(iOS 17, *) {
            content
                .toolbar(.hidden, for: .navigationBar)
                // A Form starts its first row ~33pt down; the row belongs at the
                // top of the band, level with the first page's "סיום".
                .contentMargins(.top, 0, for: .scrollContent)
        } else {
            content
        }
    }
}

extension View {
    /// Hides the system's bar on the foldable — the page carries a `SettingsBandRow` instead.
    func settingsBand(active: Bool = true) -> some View { modifier(SettingsBandBar(active: active)) }
}
