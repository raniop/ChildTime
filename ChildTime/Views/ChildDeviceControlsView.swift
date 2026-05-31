import SwiftUI
import FamilyControls

/// The ONLY parent-facing screen on a CHILD's device, reached via the gear in
/// the corner and locked behind the family parent code. It holds just the things
/// Apple's Family Controls forces to be device-local — choosing which apps are
/// locked, and manually opening screen time for a while. Everything else (rewards,
/// reports, difficulty, notifications) is managed on the parent's own device.
struct ChildDeviceControlsView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var shields: ShieldManager
    @EnvironmentObject var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss

    @State private var showAppPicker = false
    @State private var selection = FamilyActivitySelection()

    private var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }
    private var isUnlocked: Bool { progress.isUnlocked }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 16, size: 12)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    header

                    manualUnlockCard
                    appLockCard

                    Text("שְׁאָר הַהַגְדָּרוֹת — פְּרָסִים, דּוּחוֹת, רָמַת קֹשִׁי וְהַתְרָאוֹת — מְנֻהֲלוֹת בְּמַכְשִׁיר הַהוֹרֶה.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.md)

                    Button {
                        Haptic.light()
                        dismiss()
                    } label: {
                        Text("סְגִירָה")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.horizontal, 28).padding(.vertical, 12)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .familyActivityPicker(isPresented: $showAppPicker, selection: $selection)
        .onChange(of: selection) { _, new in
            settings.activitySelectionData = SelectionStorage.encode(new)
            // Keep the live shield in sync only when the child isn't mid-unlock.
            if !isUnlocked { shields.applyShield(from: new) }
        }
        .onAppear {
            selection = SelectionStorage.decode(settings.activitySelectionData)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.starGold)
                .glow(AppColor.starGold, radius: 12)
            Text("בַּקָּרַת הַמַּכְשִׁיר")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Manual unlock

    private var manualUnlockCard: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            Label(isUnlocked ? "זְמַן מָסָךְ פָּתוּחַ כָּעֵת" : "פְּתִיחָה יְדָנִית שֶׁל זְמַן מָסָךְ",
                  systemImage: isUnlocked ? "lock.open.fill" : "hourglass")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            if isUnlocked {
                Text("הָאַפְּלִיקַצְיוֹת פְּתוּחוֹת. אֶפְשָׁר לִנְעֹל מִיָּד אוֹ לְהוֹסִיף זְמַן.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            } else {
                Text("פִּתְחוּ לַיֶּלֶד אֶת הָאַפְּלִיקַצְיוֹת הַחֲסוּמוֹת לְפֶרֶק זְמַן — בְּלִי שֶׁיִּצְטָרֵךְ לְהַרְוִיחַ.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            // Duration choices.
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    durationButton("חֲצִי שָׁעָה", minutes: 30)
                    durationButton("שָׁעָה", minutes: 60)
                }
                HStack(spacing: 10) {
                    durationButton("שְׁעָתַיִם", minutes: 120)
                    durationButton("עַד סוֹף הַיּוֹם", minutes: minutesUntilEndOfDay())
                }
            }

            if isUnlocked {
                Button {
                    Haptic.medium()
                    lockNow()
                } label: {
                    Label("נְעִילָה עַכְשָׁיו", systemImage: "lock.fill")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColor.flameOrange.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.juicy)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
    }

    private func durationButton(_ title: String, minutes: Int) -> some View {
        Button {
            Haptic.success()
            grant(minutes: minutes)
        } label: {
            Text(isUnlocked ? "+\(title)" : title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .glow(AppColor.starGold, radius: 8)
        }
        .buttonStyle(.juicy)
    }

    // MARK: - App lock

    private var appLockCard: some View {
        VStack(alignment: .center, spacing: AppSpacing.md) {
            Label("אֵילוּ אַפְּלִיקַצְיוֹת נְעוּלוֹת", systemImage: "lock.app.dashed")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(selectedCount > 0
                 ? "\(selectedCount) אַפְּלִיקַצְיוֹת/קָטֵגוֹרְיוֹת נְעוּלוֹת עַד שֶׁמַּרְוִיחִים זְמַן."
                 : "עֲדַיִן לֹא נִבְחֲרוּ אַפְּלִיקַצְיוֹת לִנְעִילָה.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await shields.requestAuthorizationIfNeeded()
                    if shields.isAuthorized { showAppPicker = true }
                }
            } label: {
                Label(selectedCount > 0 ? "עֲרִיכַת הָרְשִׁימָה" : "בְּחִירַת אַפְּלִיקַצְיוֹת",
                      systemImage: "app.badge.fill")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.juicy)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Actions

    private func grant(minutes: Int) {
        Task {
            await shields.requestAuthorizationIfNeeded()
            shields.cancelScheduledReshield()
            // If already unlocked, ADD to the remaining window; else start fresh.
            let total: Int
            if isUnlocked {
                total = max(0, progress.unlockSecondsRemaining / 60) + minutes
            } else {
                total = minutes
            }
            shields.unlock(minutes: total)
            progress.startUnlock(minutes: total)
            dismiss()
        }
    }

    private func lockNow() {
        shields.cancelScheduledReshield()
        progress.endUnlock()
        shields.applyShield(from: SelectionStorage.decode(settings.activitySelectionData))
        dismiss()
    }

    private func minutesUntilEndOfDay() -> Int {
        let cal = Calendar.current
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) else { return 120 }
        let endOfDay = cal.startOfDay(for: tomorrow)
        return max(1, Int(endOfDay.timeIntervalSinceNow / 60))
    }
}

#Preview {
    ChildDeviceControlsView()
        .environmentObject(ParentSettings.shared)
        .environmentObject(ShieldManager.shared)
        .environmentObject(ProgressStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
