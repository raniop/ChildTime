import SwiftUI
import WidgetKit

/// 🌍 Parent settings → Language.
///
/// Each language is listed in its own name ("עברית", "English"), so the list is
/// readable whatever the app is showing now. Choosing one switches the whole app
/// at once — text, direction, voice — without a restart: the root view is keyed
/// on the language and rebuilds.
struct LanguagePickerView: View {
    @ObservedObject private var language = LanguageStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(language.available) { lang in
                    row(lang)
                }
                Text(tr("הַשָּׂפָה מִשְׁתַּנָּה מִיָּד בְּכָל הָאַפְּלִיקַצְיָה: טְקְסְטִים, כִּוּוּן, הַקְרָאָה וּשְׁאֵלוֹת."))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .background(GlassBackdrop())
        .environment(\.colorScheme, .dark)
        .navigationTitle("שָׁפָה · Language")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ lang: AppLanguage) -> some View {
        let selected = lang == language.current
        return Button {
            Haptic.light()
            dismiss()
            // Let the sheet close before the tree rebuilds in the new direction.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                language.set(lang)
                // Everything outside the app follows too: widgets, the shield screen, the watch.
                WidgetCenter.shared.reloadAllTimelines()
                ShieldBridge.refresh()
                WatchBridge.shared.resendLastSnapshot()
                // …and notifications sent from the server.
                if let token = PushManager.shared.currentToken { PushManager.shared.uploadFCMToken(token) }
            }
        } label: {
            HStack(spacing: 12) {
                Text(lang == .he ? "🇮🇱" : "🇺🇸").font(.system(size: 26))
                Text(lang.nativeName)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.primary)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppColor.successMint)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .glassPane(radius: 20, strength: selected ? 0.2 : 0.1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
