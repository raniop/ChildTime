import SwiftUI

/// ⚙️ ONE settings window (Rani, 2026-10-11: "אני לוחץ הגדרות של נוני, זה סוגר
/// את המסך ואז פותח מסך הגדרות חדש — זה נורא"). The gear opens one sheet with
/// one navigation stack; a child's settings, an editor, the map and the pairing
/// code all slide IN, the back arrow goes one step back, and "סיום" closes the
/// whole window from any depth. Nothing closes and reopens.
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

/// "סיום" on a page that lives only inside the settings window (a child's
/// devices, "עוד הגדרות"): it closes the whole window, like every other page's.
private struct SettingsDoneButton: ViewModifier {
    @Environment(\.closeSettings) private var closeSettings
    @ObservedObject private var railHost = DisplayGeometry.shared

    func body(content: Content) -> some View {
        content.toolbar {
            if !railHost.hasRail, let closeSettings {
                ToolbarItem(placement: .awayFromBar(.confirmationAction, leading: false)) {
                    Button(tr("סיום")) { closeSettings() }
                }
            }
        }
    }
}

extension View {
    func settingsDoneButton() -> some View { modifier(SettingsDoneButton()) }
}
