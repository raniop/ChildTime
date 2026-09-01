import SwiftUI

/// 🎓 A friendly, kid-facing grade picker — shown once on a child device whose
/// profile has no grade yet (e.g. existing families from before grades
/// existed). The choice drives ALL curriculum content, syncs to the parent
/// dashboard flagged "נבחרה על ידי הילד" for verification, and anchors the
/// automatic September promotion.
struct ChildGradePickerView: View {
    let profile: Profile
    let onPicked: (Int) -> Void

    @State private var chosen: Int? = nil
    @State private var confetti = 0
    private let letters = ["א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳"]

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(
                colors: [AppColor.gemPurple, AppColor.dreamyTeal, AppColor.starGold],
                count: 6, maxSize: 240, opacity: 0.4
            )
            SparkleField(count: 20, size: 12)

            VStack(spacing: AppSpacing.lg) {
                Spacer(minLength: AppSpacing.xl)

                Text("🎓")
                    .font(.system(size: 84))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)

                Text("הַיי \(profile.name)!")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("בְּאֵיזוֹ כִּתָּה \(profile.gender == .girl ? "אַתְּ" : "אַתָּה")?")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .glow(AppColor.starGold, radius: 10)

                Text("כָּךְ טוֹפִי יַתְאִים אֶת הַשְּׁאֵלוֹת בְּדִיּוּק בִּשְׁבִילְךָ 🎯")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        chip(-1, label: "גַּן טְרוֹם־חוֹבָה", emoji: "🧸")
                        chip(0, label: "גַּן חוֹבָה", emoji: "🎒")
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(1...8, id: \.self) { g in
                            chip(g, label: "כִּתָּה \(letters[g - 1])", emoji: nil)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .frame(maxWidth: 560)

                Text("לֹא בְּטוּחִים? אֶפְשָׁר לִשְׁאֹל אֶת אַבָּא אוֹ אִמָּא 😊")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                Spacer()
            }

            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func chip(_ g: Int, label: String, emoji: String?) -> some View {
        Button {
            guard chosen == nil else { return }   // one pick — no double-fires
            chosen = g
            Haptic.success()
            SoundPlayer.shared.play(.correctBig)
            confetti += 1
            // A beat of celebration before the map appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { onPicked(g) }
        } label: {
            VStack(spacing: 3) {
                if let emoji { Text(emoji).font(.system(size: 24)) }
                Text(label)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.white.opacity(chosen == g ? 0.35 : 0.14),
                        in: RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .stroke(chosen == g ? AppColor.successMint : .white.opacity(0.25),
                            lineWidth: chosen == g ? 2.5 : 1)
            )
            .glow(chosen == g ? AppColor.successMint : .clear, radius: chosen == g ? 10 : 0)
        }
        .buttonStyle(.juicy)
    }
}
