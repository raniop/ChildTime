import SwiftUI
import FamilyControls

/// One-time setup shown on a CHILD's device right after it joins.
///
/// It asks for the ALLOW-list — what stays open — not for a list of apps to
/// lock, because a list of apps to lock can never name an app the child installs
/// tomorrow (an `ApplicationToken` only exists for an app someone already
/// picked). Everything the parent does not name here is shielded until the child
/// earns minutes, now and in the future. See `ShieldPolicy.swift`.
///
/// Shielding is device-local in Family Controls, so this MUST run on the child's
/// device (not the parent's control-center device). Skippable — reachable later
/// from the gear on this device, behind the parent code.
struct ChildAppLockSetupView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @Environment(\.dismiss) private var dismiss

    @State private var showAppPicker = false
    @State private var requestingAuth = false
    @State private var openSelection = SelectionStorage.empty()
    @StateObject private var companion = CompanionController()

    /// Apps named as "stays open". Only apps arm the lock, not categories.
    private var selectedCount: Int { openSelection.applicationTokens.count }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "lock.app.dashed")
                        .font(.system(size: 64))
                        .foregroundStyle(AppColor.starGold)

                    Text(tr("מה נשאר פתוח?"))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(tr("כל האפליקציות במכשיר הזה יהיו נעולות עד שהילד מרוויח זמן מסך בטופי — גם אפליקציה שתותקן מחר. בחרו כאן מה נשאר פתוח תמיד: את טופי עצמה, וגם טלפון, הודעות, מצלמה ושעון. אפשר לשנות בכל עת."))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)

                    // Rani (live, on a child's device): the tap looked stuck. iOS
                    // takes a few seconds to bring up ITS Screen Time consent
                    // dialog the first time — so say so, spin, and refuse a
                    // second tap while it's coming.
                    Button {
                        guard !requestingAuth else { return }
                        Haptic.light()
                        requestingAuth = true
                        Task {
                            await shields.requestAuthorizationIfNeeded(userInitiated: true)
                            requestingAuth = false
                            if shields.isAuthorized { showAppPicker = true }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if requestingAuth {
                                ProgressView().tint(Color(hex: "4B3FBF"))
                                Text(tr("מְבַקְּשִׁים אִשּׁוּר מֵ־iOS…"))
                            } else {
                                Image(systemName: selectedCount > 0 ? "checkmark.circle.fill" : "app.badge.fill")
                                Text(selectedCount > 0
                                     ? tr("\(selectedCount) אפליקציות נשארות פתוחות · הקישו לעריכה")
                                     : tr("בחרו מה נשאר פתוח"))
                            }
                        }
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3FBF"))
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.92)))
                        .shadow(color: .black.opacity(0.2), radius: 14, y: 8)
                    }
                    .buttonStyle(.juicy)
                    .disabled(requestingAuth)

                    if requestingAuth {
                        Text(tr("iOS מַצִּיג עַכְשָׁיו חַלּוֹן אִשּׁוּר לְ־Screen Time — זֶה יָכוֹל לָקַחַת כַּמָּה שְׁנִיּוֹת. אַשְּׁרוּ שָׁם, וְנַמְשִׁיךְ."))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(GlassInk.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                    }

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
                            Label(tr("בּוֹאוּ נַתְחִיל! 🚀"), systemImage: "checkmark.circle.fill")
                                .font(.system(size: 21, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .glassFill(AppGradient.success, radius: 22)
                        }
                        .buttonStyle(.juicy)
                        .padding(.top, AppSpacing.sm)
                    } else {
                        Text(tr("אם תדלגו, נעולות רק האפליקציות שבחרתם קודם — ואפליקציה חדשה שהילד מתקין תישאר פתוחה."))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.md)
                        Button {
                            Haptic.medium()
                            finish()
                        } label: {
                            Text(tr("אבחר אחר כך"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 28).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14))).overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
        }
        .tofyActivityPicker(title: PickerCopy.allowList.title, header: PickerCopy.allowList.header, footer: PickerCopy.allowList.footer, isPresented: $showAppPicker, selection: $openSelection)
        .onChangeCompat(of: openSelection) { _, new in
            settings.allowedAppsData = SelectionStorage.encode(new)
            // Arms immediately — no relaunch needed.
            shields.applyDefaultLock()
        }
        .onAppear {
            openSelection = SelectionStorage.decode(settings.allowedAppsData)
        }
    }

    private func finish() {
        settings.hasPromptedChildAppLock = true
        dismiss()
    }
}
