import SwiftUI

/// 🎒 September 1st — the first day of school! Shown ONCE per school year on
/// the child's device when their grade auto-advances (see
/// `Profile.effectiveGrade`): confetti, the new grade, and off we go.
struct SchoolYearCelebrationView: View {
    let gradeName: String
    let childName: String
    let onDone: () -> Void

    @State private var confetti = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppGradient.gold.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.starGold, AppColor.flameOrange, .white, AppColor.successMint],
                count: 7, maxSize: 260, opacity: 0.4
            )
            SparkleField(count: 30, size: 14)

            VStack(spacing: AppSpacing.lg) {
                Spacer()

                Text("🎒")
                    .font(.system(size: 110))
                    .rotationEffect(.degrees(appeared ? 8 : -8))
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: appeared)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 8)

                Text("יוֹם רִאשׁוֹן לַלִּמּוּדִים!")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("\(childName) עוֹלֶה/עוֹלָה לְ\(gradeName)! 🎉")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .scaleEffect(appeared ? 1 : 0.6)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: appeared)

                Text("טוֹפִי כְּבָר הֵכִין שְׁאֵלוֹת חֲדָשׁוֹת בְּדִיּוּק בִּשְׁבִילְךָ — בְּהַצְלָחָה בַּשָּׁנָה הַחֲדָשָׁה!")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer()

                Button {
                    Haptic.success()
                    onDone()
                } label: {
                    Text("יַאלְלָה, מַתְחִילִים! 🚀")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .frame(maxWidth: 420)
                        .padding(.vertical, 16)
                        .background(.white, in: Capsule())
                        .glow(.white, radius: 14)
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)
            }

            Confetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            appeared = true
            confetti += 1
            SoundPlayer.shared.play(.levelUp)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { confetti += 1 }
        }
    }
}

enum SchoolYearCelebration {
    /// The school year already celebrated (or acknowledged) for a profile.
    private static func key(_ id: UUID) -> String { "schoolYear.celebrated.\(id.uuidString)" }

    /// Whether to show the party for this profile now — and keep the stored
    /// year in sync. First sighting of a profile just records the current year
    /// (no fake party on day one); a real advance celebrates only during the
    /// first months of school (Sep–Oct), otherwise it's silently acknowledged.
    @MainActor
    static func shouldCelebrate(_ profile: Profile, now: Date = Date()) -> Bool {
        guard profile.grade != nil else { return false }
        let current = Profile.schoolYear(for: now)
        let d = UserDefaults.standard
        guard let stored = d.object(forKey: key(profile.id)) as? Int else {
            d.set(current, forKey: key(profile.id))
            return false
        }
        guard current > stored else { return false }
        d.set(current, forKey: key(profile.id))
        let month = Calendar.current.component(.month, from: now)
        return month == 9 || month == 10
    }
}
