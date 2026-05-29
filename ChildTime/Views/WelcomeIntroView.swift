import SwiftUI

/// The first screen a new user sees — explains plainly what טופי is, and that
/// screen-time is now managed inside the app (so any Apple Family / Screen Time
/// limits for the child should be turned off). RTL: right-align uses `.leading`
/// and each row's icon leads on the right.
struct WelcomeIntroView: View {
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var companion = CompanionController()
    @State private var appeared = false

    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 24, size: 14)

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        hero
                        stepsCard
                        screenTimeNoticeCard
                        startButton
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xl)
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.45)) { appeared = true } }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: AppSpacing.md) {
            CompanionView(controller: companion, size: isCompact ? 120 : 150)
            Text("טוֹפִּי")
                .font(.system(size: isCompact ? 52 : 68, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                                   startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: AppColor.starGold.opacity(0.5), radius: 12)
            Text("לוֹמְדִים, מַרְוִיחִים זְמַן מָסָךְ —\nוְהַהוֹרִים רוֹאִים הַכֹּל.")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - How it works

    private var stepsCard: some View {
        VStack(spacing: 0) {
            step("🧠", AppColor.gemPurple,
                 "הַיֶּלֶד לוֹמֵד וּמְשַׂחֵק",
                 "שְׁאֵלוֹת מַתְאִימוֹת לְגִיל — חֶשְׁבּוֹן, עִבְרִית, אַנְגְּלִית, מַדָּע וְעוֹד.")
            divider
            step("🎮", AppColor.successMint,
                 "כָּל 10 תְּשׁוּבוֹת = 4 דַּקּוֹת מָסָךְ",
                 "מַרְוִיחַ זְמַן מָסָךְ אֲמִתִּי דֶּרֶךְ לְמִידָה.")
            divider
            step("📊", AppColor.starGold,
                 "אַתֶּם עוֹקְבִים וּמְקַבְּלִים הַמְלָצוֹת",
                 "דּוּחוֹת, חֹזֶק וְחֻלְשָׁה, וְהַתְרָאוֹת — בְּמַכְשִׁיר נִפְרָד.")
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(.white.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1))
        )
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.12)).frame(height: 1).padding(.vertical, 4)
    }

    private func step(_ emoji: String, _ tint: Color, _ title: String, _ body: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 54, height: 54)
                .background(
                    Circle().fill(
                        LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.5)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                )
                .glow(tint, radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(body)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Screen Time notice

    private var screenTimeNoticeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.flameOrange)
                Text("זְמַן הַמָּסָךְ מְנֻהָל בְּטוֹפִּי")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            Text("אִם הִגְדַּרְתֶּם לַיֶּלֶד מַגְבָּלוֹת זְמַן מָסָךְ בְּ\"מִשְׁפָּחָה\" / Screen Time שֶׁל אַפְּל — כַּבּוּ אוֹתָן. מֵעַכְשָׁו טוֹפִּי מְנַהֵל אֶת זְמַן הַמָּסָךְ; שְׁתֵּי מַעֲרָכוֹת בְּמַקְבִּיל יִתְנַגְּשׁוּ.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.flameOrange.opacity(0.22))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(AppColor.flameOrange.opacity(0.5), lineWidth: 1.5))
        )
    }

    // MARK: - CTA

    private var startButton: some View {
        Button {
            Haptic.medium()
            settings.hasSeenWelcome = true
        } label: {
            Text("בּוֹאוּ נַתְחִיל 🚀")
                .font(.system(size: 21, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .glow(AppColor.starGold, radius: 14)
        }
        .buttonStyle(.juicy)
    }
}

#Preview {
    WelcomeIntroView()
        .environmentObject(ParentSettings.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
