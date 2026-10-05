import SwiftUI

/// 🎁 "קיבלתם את טופי+ במתנה" — once, the moment the family's gift opens.
///
/// Rani, 2026-10-05: every family gets Tofy+ for 30 days the moment it is
/// created ("עם הצגה יפה שהם קיבלו במתנה את טופי פלוס ל-30 ימים"). The server
/// opens it (`giftOnHouseholdCreated` / the conversion engine); this is how the
/// parent finds out — a moment, not a row in a list. A family whose running
/// gift was stretched to 30 days sees it too, with the days it has left.
///
/// Parent-facing: no niqqud. Shown once per gift (keyed by its start).
struct GiftWelcomeView: View {
    let until: Date
    let onDone: () -> Void

    @State private var confetti = 0
    @State private var risen = false

    private var daysLeft: Int {
        max(1, Int(ceil(until.timeIntervalSinceNow / 86_400)))
    }

    private var endDate: String {
        let f = DateFormatter()
        f.locale = LanguageStore.shared.current.locale
        f.setLocalizedDateFormatFromTemplate("d MMMM")
        return f.string(from: until)
    }

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            SparkleField(count: 16, size: 12)
            FancyConfetti(trigger: confetti)

            VStack(spacing: 18) {
                Spacer(minLength: 10)
                Text("🎁")
                    .font(.system(size: 96))
                    .shadow(color: AppColor.starGold.opacity(0.6), radius: 24)
                    .offset(y: risen ? 0 : 24)
                    .opacity(risen ? 1 : 0)

                Text(tr("קיבלתם את טופי+ במתנה!"))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)

                // The number is the gift.
                VStack(spacing: 0) {
                    Text("\(daysLeft)")
                        .font(.system(size: 76, weight: .black, design: .rounded))
                        .foregroundStyle(AppGradient.gold)
                        .monospacedDigit()
                    Text(daysLeft >= 29 ? tr("ימים של כל העולמות") : tr("ימים נשארו במתנה"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 10) {
                    perk("🌍", tr("כל העולמות פתוחים לכל הילדים במשפחה"))
                    perk("💳", tr("בלי כרטיס אשראי, ולא מתחדש אוטומטית"))
                    perk("📅", tr("המתנה מסתיימת ב-\(endDate)"))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassPane(radius: 22)

                Spacer(minLength: 10)

                Button {
                    Haptic.success()
                    onDone()
                } label: {
                    Text(tr("יאללה, מתחילים"))
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppGradient.gold, in: Capsule())
                        .glow(AppColor.starGold, radius: 14)
                }
                .buttonStyle(.juicy)
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: 520)
        }
        .environment(\.layoutDirection, .app)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { risen = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { confetti &+= 1 }
        }
    }

    private func perk(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji).font(.system(size: 22))
            Text(text)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// When to show it: a running gift this device has not welcomed yet.
enum GiftWelcome {
    private static func key(_ hh: Household) -> String {
        "giftWelcome.shown.\(hh.id).\(Int(hh.giftStartedAt?.timeIntervalSince1970 ?? 0))"
    }
    static func isDue(_ hh: Household?) -> Bool {
        guard let hh, hh.premiumSource == "gift", hh.giftStartedAt != nil,
              let until = hh.giftUntil ?? hh.premiumUntil, until > Date() else { return false }
        return !UserDefaults.standard.bool(forKey: key(hh))
    }
    static func markShown(_ hh: Household?) {
        guard let hh else { return }
        UserDefaults.standard.set(true, forKey: key(hh))
    }
}
