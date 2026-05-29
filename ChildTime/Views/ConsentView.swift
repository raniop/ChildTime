import SwiftUI

/// Parental consent + privacy summary, shown once after sign-in and before any
/// child profile is created (Privacy by Design). Records the accepted consent
/// version locally and on the parent's account record.
struct ConsentView: View {
    @EnvironmentObject var settings: ParentSettings
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 18, size: 12)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Text("🔒").font(.system(size: 64)).padding(.top, AppSpacing.xl)
                    Text("הפרטיות של הילד שלכם — קודם כול")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .trailing, spacing: 14) {
                        principle("👨‍👩‍👧", "הפרדה מלאה בין משפחות", "הנתונים של כל משפחה מבודדים. אף משפחה אחרת לא יכולה לראות את הילד שלכם.")
                        principle("📉", "איסוף נתונים מינימלי", "אנחנו אוספים רק את מה שדרוש כדי להציג התקדמות למידה — בלי פרסום מבוסס פרופיל ובלי מכירת נתונים.")
                        principle("🔐", "מאובטח", "ההתקדמות מסונכרנת בצורה מאובטחת, והקוד ההורי נשמר מוצפן במכשיר.")
                        principle("🗑️", "בשליטתכם", "אפשר לייצא את כל הנתונים או למחוק אותם לחלוטין בכל רגע, מתוך הגדרות ההורה.")
                    }
                    .padding(AppSpacing.md)
                    .frame(maxWidth: 460)
                    .background(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .fill(.white.opacity(0.12)))

                    Link("קראו את מדיניות הפרטיות המלאה",
                         destination: URL(string: "https://github.com/raniop/ChildTime/blob/main/distribution/PRIVACY_POLICY.html")!)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))

                    Button {
                        accept()
                    } label: {
                        Text("אני מסכים/ה ומאשר/ת כהורה")
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: 460)
                            .padding(.vertical, 16)
                            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .glow(AppColor.starGold, radius: 12)
                    }
                    .buttonStyle(.juicy)
                    .padding(.bottom, AppSpacing.xl)
                }
                .padding(.horizontal, AppSpacing.lg)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func principle(_ emoji: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(body).font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            Text(emoji).font(.system(size: 28))
        }
    }

    private func accept() {
        Haptic.success()
        settings.consentVersionAccepted = Consent.currentVersion
        HouseholdManager.shared.recordConsent(version: Consent.currentVersion)
    }
}
