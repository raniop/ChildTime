import SwiftUI

/// Post-sign-in fork for an account with NO family yet (Rani): nobody gets a
/// silently-created empty household anymore. A spouse who naturally tapped
/// "Sign in with Google" lands here and gets the question in human words,
/// instead of a mysterious empty family.
struct FamilyChoiceView: View {
    @EnvironmentObject var settings: ParentSettings
    @StateObject private var household = HouseholdManager.shared
    @State private var creating = false
    /// Naming the family was only ever reachable from the parent home title —
    /// the sign-up flow never asked (OnboardingView, which had the field, is not
    /// part of the real flow). Ask here, once, while creating the family.
    @State private var namingNewFamily = false
    @State private var familyName = ""

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            if namingNewFamily { namingView } else { choiceView }
        }
        .environment(\.layoutDirection, .app)
    }

    // MARK: - 👪 Name the family (new families only)

    private var namingView: some View {
        VStack(spacing: AppSpacing.xl) {
            VStack(spacing: AppSpacing.sm) {
                Text("👪").font(.system(size: 54))
                Text(tr("אֵיךְ נִקְרָא לַמִּשְׁפָּחָה?"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(tr("הַשֵּׁם מוֹפִיעַ בַּמָּסָךְ הָרָאשִׁי וּבַהוֹדָעוֹת — לְכָל הַהוֹרִים בַּמִּשְׁפָּחָה."))
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.lg)
            }

            TextField("", text: $familyName,
                      prompt: Text(tr("לְמָשָׁל: מִשְׁפַּחַת גּוֹלָן")).foregroundColor(.white.opacity(0.55)))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .glassPane(radius: AppRadius.large)
                .frame(maxWidth: 460)

            VStack(spacing: AppSpacing.sm) {
                JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {
                    createFamily(named: familyName)
                } label: {
                    if creating { ProgressView().tint(.white) } else { Text(tr("צְרוּ אֶת הַמִּשְׁפָּחָה")) }
                }
                .disabled(creating)
                Button(tr("אֶקְבַּע אֶת הַשֵּׁם אַחַר כָּךְ")) { createFamily(named: "") }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .disabled(creating)
            }
            .frame(maxWidth: 460)
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    private func createFamily(named name: String) {
        guard !creating else { return }
        creating = true
        Haptic.medium()
        Task {
            await household.createOwnHousehold()
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { household.setFamilyName(trimmed) }
            creating = false
        }
    }

    private var choiceView: some View {
        VStack(spacing: AppSpacing.xl) {
                VStack(spacing: AppSpacing.sm) {
                    Text("👋").font(.system(size: 54))
                    Text(tr("עוֹד אֵין לַחֶשְׁבּוֹן הַזֶּה מִשְׁפָּחָה"))
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(tr("רַק שְׁאֵלָה אַחַת כְּדֵי שֶׁנֵּדַע לְאָן לְהַמְשִׁיךְ:"))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                VStack(spacing: AppSpacing.lg) {
                    choiceCard(
                        emoji: "🏠",
                        title: tr("אֲנַחְנוּ חֲדָשִׁים בְּטוֹפִי"),
                        subtitle: tr("צְרוּ מִשְׁפָּחָה חֲדָשָׁה וְהַתְחִילוּ לְהַגְדִּיר"),
                        glow: AppColor.starGold,
                        busy: creating
                    ) {
                        guard !creating else { return }
                        Haptic.light()
                        familyName = household.suggestedFamilyName ?? ""
                        namingNewFamily = true
                    }
                    choiceCard(
                        emoji: "👨‍👩‍👧",
                        title: tr("הַהוֹרֶה הַשֵּׁנִי כְּבָר הִגְדִּיר"),
                        subtitle: tr("הִצְטָרְפוּ לַמִּשְׁפָּחָה הַקַּיֶּמֶת — סוֹרְקִים קוֹד מֵהַמַּכְשִׁיר שֶׁלּוֹ"),
                        glow: AppColor.companionGlow,
                        busy: false
                    ) {
                        Haptic.light()
                        settings.pendingJoinFamily = true
                    }
                }
                .frame(maxWidth: 460)

                Text(tr("טִיפּ: הַהוֹרֶה שֶׁכְּבָר בִּפְנִים יָכוֹל לְהַזְמִין אֶתְכֶם בְּאִימֵיל — וְאָז הַמָּסָךְ הַזֶּה נֶעֱלָם לְגַמְרֵי 😊"))
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
        .padding(.horizontal, AppSpacing.lg)
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
            .glassPane(radius: AppRadius.large)
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
        return names.first.map { tr("הַמִּשְׁפָּחָה שֶׁל \($0)") } ?? tr("הַמִּשְׁפָּחָה שֶׁלָּכֶם")
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            VStack(spacing: AppSpacing.xl) {
                Text("🎉").font(.system(size: 64))
                Text(tr("\(familyName) מְחַכָּה לָכֶם!"))
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(tr("הֻזְמַנְתֶּם לְהִצְטָרֵף כְּהוֹרֶה — תִּרְאוּ אֶת הַיְלָדִים, הַהִתְקַדְּמוּת וְהַשְּׁלִיטָה, בְּדִיּוּק כְּמוֹ הַהוֹרֶה שֶׁהִזְמִין אֶתְכֶם."))
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
                        Text(tr("הִצְטָרְפוּ לַמִּשְׁפָּחָה"))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassFill(AppGradient.gold, radius: 22)
                }
                .buttonStyle(.juicy)
                .frame(maxWidth: 420)

                Button {
                    Haptic.light()
                    household.pendingEmailInvite = nil
                    household.needsFamilyChoice = true
                } label: {
                    Text(tr("לֹא הַמִּשְׁפָּחָה שֶׁלִּי — הַתְחִילוּ מֵהַתְחָלָה"))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .underline()
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .environment(\.layoutDirection, .app)
    }
}
