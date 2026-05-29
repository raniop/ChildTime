import SwiftUI

/// The very first screen a new user sees — explains plainly what טופי is and,
/// crucially, that screen-time is now managed inside the app (so any Apple
/// Family / Screen Time limits set for the child should be turned off).
///
/// The app runs RTL, so right-alignment uses `.leading` and icons lead on the
/// right (first item in each row's HStack).
struct WelcomeIntroView: View {
    @EnvironmentObject var settings: ParentSettings
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var appeared = false

    private var isCompact: Bool { hsc == .compact }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.companionGlow, AppColor.gemPurple],
                count: 6, maxSize: 280, opacity: 0.4
            )
            SparkleField(count: 22, size: 14)

            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        hero
                        whatIsItCard
                        screenTimeNoticeCard
                        startButton
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.xl)
                    .frame(minHeight: proxy.size.height, alignment: .center)
                    .frame(maxWidth: 540)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { appeared = true } }
    }

    private var hero: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("🦉")
                .font(.system(size: isCompact ? 70 : 90))
                .shadow(color: AppColor.starGold.opacity(0.6), radius: 14)
            Text("בְּרוּכִים הַבָּאִים לְטוֹפִּי")
                .font(.system(size: isCompact ? 32 : 42, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [AppColor.starGold, AppColor.companionGlow, Color(hex: "FFE082")],
                                   startPoint: .top, endPoint: .bottom)
                )
                .multilineTextAlignment(.center)
            Text("הַיֶּלֶד לוֹמֵד, מַרְוִיחַ זְמַן מָסָךְ — וְאַתֶּם רוֹאִים הַכֹּל.")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }

    private var whatIsItCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("אֵיךְ זֶה עוֹבֵד")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            row("🧠", "הַיֶּלֶד לוֹמֵד וּמְשַׂחֵק",
                "שְׁאֵלוֹת מַתְאִימוֹת לְגִיל — חֶשְׁבּוֹן, עִבְרִית, אַנְגְּלִית, מַדָּע וְעוֹד.")
            row("🎮", "כָּל 10 תְּשׁוּבוֹת = 4 דַּקּוֹת מָסָךְ",
                "מַרְוִיחַ זְמַן מָסָךְ אֲמִתִּי בְּלִמִידָה.")
            row("👨‍👩‍👧", "אַתֶּם עוֹקְבִים וּמְקַבְּלִים הַמְלָצוֹת",
                "דּוּחוֹת, חֹזֶק וְחֻלְשָׁה, וְהַתְרָאוֹת — בְּמַכְשִׁיר נִפְרָד.")
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(.white.opacity(0.12))
        )
    }

    private var screenTimeNoticeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.starGold)
                Text("חָשׁוּב: זְמַן הַמָּסָךְ מְנֻהָל בְּטוֹפִּי")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            Text("אִם הִגְדַּרְתֶּם לַיֶּלֶד מַגְבָּלוֹת זְמַן מָסָךְ בְּ\"מִשְׁפָּחָה\" / Screen Time שֶׁל אַפְּל — כַּבּוּ אוֹתָן. מֵעַכְשָׁו טוֹפִּי מְנַהֵל אֶת זְמַן הַמָּסָךְ, וּשְׁתֵּי מַעֲרָכוֹת בְּמַקְבִּיל יִתְנַגְּשׁוּ.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("הַגְדָּרוֹת ← זְמַן מָסָךְ ← [שֵׁם הַיֶּלֶד] ← כַּבּוּ מַגְבָּלוֹת.")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                .fill(AppColor.flameOrange.opacity(0.30))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(AppColor.starGold.opacity(0.6), lineWidth: 1.5))
        )
    }

    private var startButton: some View {
        Button {
            Haptic.medium()
            settings.hasSeenWelcome = true
        } label: {
            Text("בּוֹאוּ נַתְחִיל 🚀")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .glow(AppColor.starGold, radius: 12)
        }
        .buttonStyle(.juicy)
    }

    /// Icon leads on the RIGHT (first in the HStack under RTL); text is
    /// right-aligned beside it.
    private func row(_ emoji: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.system(size: 30))
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.15)))
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
    }
}

#Preview {
    WelcomeIntroView()
        .environmentObject(ParentSettings.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
