import SwiftUI
import FamilyControls

/// One-time setup shown on a CHILD's device right after it joins: the parent
/// chooses which apps get locked until the child earns screen time. Shielding is
/// device-local in Family Controls, so this MUST run on the child's device (not
/// the parent's control-center device). Skippable — reachable later from
/// Parent Settings → "אפליקציות לחסום".
struct ChildAppLockSetupView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @Environment(\.dismiss) private var dismiss

    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()
    @State private var companion = CompanionController()

    private var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 20, size: 13)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "lock.app.dashed")
                        .font(.system(size: 64))
                        .foregroundStyle(AppColor.starGold)
                        .glow(AppColor.starGold, radius: 14)

                    Text("אֵילוּ אַפְּלִיקַצְיוֹת לִנְעֹל?")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text("בַּחֲרוּ אֶת הָאַפְּלִיקַצְיוֹת שֶׁיִּהְיוּ נְעוּלוֹת בַּמַּכְשִׁיר הַזֶּה — עַד שֶׁהַיֶּלֶד מַרְוִיחַ זְמַן מָסָךְ בְּטוֹפִּי. אֶפְשָׁר לְשַׁנּוֹת בְּכָל עֵת בְּהַגְדָּרוֹת הוֹרֶה.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)

                    Button {
                        Task {
                            await shields.requestAuthorizationIfNeeded()
                            if shields.isAuthorized { showAppPicker = true }
                        }
                    } label: {
                        Label(selectedCount > 0
                                ? "\(selectedCount) אַפְּלִיקַצְיוֹת נִבְחֲרוּ · הַקִּישׁוּ לַעֲרֹךְ"
                                : "בַּחֲרוּ אַפְּלִיקַצְיוֹת",
                              systemImage: selectedCount > 0 ? "checkmark.circle.fill" : "app.badge.fill")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedCount > 0
                                    ? AnyShapeStyle(.white.opacity(0.18))
                                    : AnyShapeStyle(AppGradient.gold),
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(.white.opacity(selectedCount > 0 ? 0.35 : 0), lineWidth: 1.5)
                            )
                            .glow(selectedCount > 0 ? .clear : AppColor.starGold, radius: 12)
                    }
                    .buttonStyle(.juicy)

                    if !shields.isAuthorized, let err = shields.authorizationError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }

                    // Clear primary "let's start" button once apps are chosen, so
                    // it's obvious you confirm to continue (not just back out).
                    if selectedCount > 0 {
                        Button {
                            Haptic.success()
                            finish()
                        } label: {
                            Label("בּוֹאוּ נַתְחִיל! 🚀", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 21, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    LinearGradient(colors: [AppColor.successMint, Color(hex: "06A57E")],
                                                   startPoint: .top, endPoint: .bottom),
                                    in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .glow(AppColor.successMint, radius: 12)
                        }
                        .buttonStyle(.juicy)
                        .padding(.top, AppSpacing.sm)
                    } else {
                        Button {
                            Haptic.medium()
                            finish()
                        } label: {
                            Text("אֶבְחַר אַחַר כָּךְ")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 28).padding(.vertical, 12)
                                .background(.white.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
        .onChange(of: selection) { _, new in
            settings.activitySelectionData = SelectionStorage.encode(new)
            shields.applyShield(from: new)
        }
        .onAppear {
            selection = SelectionStorage.decode(settings.activitySelectionData)
        }
    }

    private func finish() {
        settings.hasPromptedChildAppLock = true
        dismiss()
    }
}
