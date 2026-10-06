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
    private let letters = [tr("א׳"), tr("ב׳"), tr("ג׳"), tr("ד׳"), tr("ה׳"), tr("ו׳"), tr("ז׳"), tr("ח׳")]
    /// 📐 This picker has no way out — a child who cannot reach their grade is
    /// stuck on it. Sideways on a phone the bottom row (כיתה ה׳–ח׳) ran off the
    /// glass with nothing to scroll, so a short screen draws everything smaller,
    /// a wide one puts all eight grades on one row, and the whole thing now
    /// scrolls as a last resort.
    @ObservedObject private var display = DisplayGeometry.shared
    private var short: Bool { display.isShort }
    private var gradeColumns: Int { display.isWideShort ? 8 : 4 }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 20, size: 12)

            ScrollView {
                VStack(spacing: short ? AppSpacing.sm : AppSpacing.lg) {
                    Text("🎓")
                        .font(.system(size: short ? 44 : 84))
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 6)

                    Text(tr("הַיי \(profile.name)!"))
                        .font(.system(size: short ? 20 : 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text(tr("בְּאֵיזוֹ כִּתָּה \(profile.gender == .girl ? tr("אַתְּ") : tr("אַתָּה"))?"))
                        .font(.system(size: short ? 23 : 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .glow(AppColor.starGold, radius: 10)

                    Text(profile.gender == .girl ? tr("כָּךְ טוֹפִי יַתְאִים אֶת הַשְּׁאֵלוֹת בְּדִיּוּק בִּשְׁבִילֵךְ 🎯") : tr("כָּךְ טוֹפִי יַתְאִים אֶת הַשְּׁאֵלוֹת בְּדִיּוּק בִּשְׁבִילְךָ 🎯"))
                        .font(.system(size: short ? 13 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            chip(-1, label: tr("גַּן טְרוֹם־חוֹבָה"), emoji: "🧸")
                            chip(0, label: tr("גַּן חוֹבָה"), emoji: "🎒")
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: gradeColumns), spacing: 8) {
                            ForEach(1...8, id: \.self) { g in
                                chip(g, label: tr("כִּתָּה \(letters[g - 1])"), emoji: nil)
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(maxWidth: display.isWideShort ? 760 : 560)

                    Text(tr("לֹא בְּטוּחִים? אֶפְשָׁר לִשְׁאֹל אֶת אַבָּא אוֹ אִמָּא 😊"))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, short ? AppSpacing.md : AppSpacing.xl)
            }

            FancyConfetti(trigger: confetti)
        }
        .environment(\.layoutDirection, .app)
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
                if let emoji { Text(emoji).font(.system(size: short ? 18 : 24)) }
                Text(label)
                    .font(.system(size: short ? 14 : 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, short ? 9 : 14)
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
