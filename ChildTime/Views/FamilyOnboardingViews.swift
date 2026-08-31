import SwiftUI

/// Post-sign-in fork for an account with NO family yet (Rani): nobody gets a
/// silently-created empty household anymore. A spouse who naturally tapped
/// "Sign in with Google" lands here and gets the question in human words,
/// instead of a mysterious empty family.
struct FamilyChoiceView: View {
    @EnvironmentObject var settings: ParentSettings
    @StateObject private var household = HouseholdManager.shared
    @State private var creating = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 18, size: 12)
            VStack(spacing: AppSpacing.xl) {
                VStack(spacing: AppSpacing.sm) {
                    Text("👋").font(.system(size: 54))
                    Text("עוֹד אֵין לַחֶשְׁבּוֹן הַזֶּה מִשְׁפָּחָה")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("רַק שְׁאֵלָה אַחַת כְּדֵי שֶׁנֵּדַע לְאָן לְהַמְשִׁיךְ:")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                VStack(spacing: AppSpacing.lg) {
                    choiceCard(
                        emoji: "🏠",
                        title: "אֲנַחְנוּ חֲדָשִׁים בְּטוֹפִי",
                        subtitle: "צְרוּ מִשְׁפָּחָה חֲדָשָׁה וְהַתְחִילוּ לְהַגְדִּיר",
                        glow: AppColor.starGold,
                        busy: creating
                    ) {
                        guard !creating else { return }
                        creating = true
                        Haptic.medium()
                        Task {
                            await household.createOwnHousehold()
                            creating = false
                        }
                    }
                    choiceCard(
                        emoji: "👨‍👩‍👧",
                        title: "הַהוֹרֶה הַשֵּׁנִי כְּבָר הִגְדִּיר",
                        subtitle: "הִצְטָרְפוּ לַמִּשְׁפָּחָה הַקַּיֶּמֶת — סוֹרְקִים קוֹד מֵהַמַּכְשִׁיר שֶׁלּוֹ",
                        glow: AppColor.companionGlow,
                        busy: false
                    ) {
                        Haptic.light()
                        settings.pendingJoinFamily = true
                    }
                }
                .frame(maxWidth: 460)

                Text("טִיפּ: הַהוֹרֶה שֶׁכְּבָר בִּפְנִים יָכוֹל לְהַזְמִין אֶתְכֶם בְּאִימֵּיְל — וְאָז הַמָּסָךְ הַזֶּה נֶעֱלָם לְגַמְרֵי 😊")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func choiceCard(emoji: String, title: String, subtitle: String,
                            glow: Color, busy: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Text(emoji)
                    .font(.system(size: 36))
                    .frame(width: 60, height: 60)
                    .background(Circle().fill(glow.opacity(0.3)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if busy { ProgressView().tint(.white) }
                else {
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(AppSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .fill(.white.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(glow.opacity(0.55), lineWidth: 2))
            )
        }
        .buttonStyle(.juicy)
    }
}

/// "משפחת X מחכה לך" — the account's email was pre-invited by the family
/// owner, so joining is ONE tap: no QR, no codes, no prior knowledge.
struct EmailInviteWelcomeView: View {
    @StateObject private var household = HouseholdManager.shared
    @State private var joining = false

    private var familyName: String {
        let names = (household.pendingEmailInvite?.parentNames ?? [:]).values
            .filter { !$0.isEmpty }.sorted()
        return names.first.map { "הַמִּשְׁפָּחָה שֶׁל \($0)" } ?? "הַמִּשְׁפָּחָה שֶׁלָּכֶם"
    }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 22, size: 13)
            VStack(spacing: AppSpacing.xl) {
                Text("🎉").font(.system(size: 64))
                Text("\(familyName) מְחַכָּה לָכֶם!")
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("הֻזְמַנְתֶּם לְהִצְטָרֵף כְּהוֹרֶה — תִּרְאוּ אֶת הַיְלָדִים, הַהִתְקַדְּמוּת וְהַשְּׁלִיטָה, בְּדִיּוּק כְּמוֹ הַהוֹרֶה שֶׁהִזְמִין אֶתְכֶם.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                Button {
                    guard !joining else { return }
                    joining = true
                    Haptic.success()
                    Task {
                        await household.acceptEmailInvite()
                        joining = false
                    }
                } label: {
                    HStack(spacing: 10) {
                        if joining { ProgressView().tint(.white) }
                        Text("הִצְטָרְפוּ לַמִּשְׁפָּחָה")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .glow(AppColor.starGold, radius: 14)
                }
                .buttonStyle(.juicy)
                .frame(maxWidth: 420)

                Button {
                    Haptic.light()
                    household.pendingEmailInvite = nil
                    household.needsFamilyChoice = true
                } label: {
                    Text("לֹא הַמִּשְׁפָּחָה שֶׁלִּי — הַתְחִילוּ מֵהַתְחָלָה")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .underline()
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
