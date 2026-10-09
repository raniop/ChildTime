import SwiftUI

/// 🔌 What a parent sees while their phone is NOT connected to the family in
/// the cloud — instead of an old local copy that looks current (Eli, 9.10: three
/// days disconnected behind a green ✓, then a second child on the way back).

/// Full screen, right after signing in, before the family has come down: there
/// is nothing true to show yet, and the dashboard's empty state would invite a
/// "צרו ילד/ה" that duplicates the family's real child.
struct FamilyConnectingView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @State private var slow = false
    /// After a minute, a way out — a load that fails for good (not the network)
    /// must not trap the parent on this screen with only "נסו שוב".
    @State private var stuck = false

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: AppSpacing.md) {
                Spacer()
                ProgressView().controlSize(.large).tint(.white)
                Text(tr("מתחברים למשפחה…"))
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(slow || household.familyLinkBroken
                     ? tr("זה לוקח יותר מהרגיל. בדקו שיש חיבור לאינטרנט — אנחנו ממשיכים לנסות לבד.")
                     : tr("מורידים את הילדים וההגדרות של המשפחה"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if slow || household.familyLinkBroken {
                    Button {
                        Haptic.light()
                        household.retryFamilyLoadIfNeeded()
                    } label: {
                        Text(tr("נסו שוב"))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "2A1E5C"))
                            .frame(maxWidth: 280).frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                    }
                    .buttonStyle(.juicy)
                    .padding(.top, AppSpacing.sm)
                }
                if stuck {
                    Button {
                        Haptic.light()
                        AuthManager.shared.signOut()   // the family stays in the cloud; sign in again
                    } label: {
                        Text(tr("התנתקות והתחברות מחדש"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.xl)
        }
        .task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            slow = true
            try? await Task.sleep(nanoseconds: 50_000_000_000)
            stuck = true
        }
    }
}

/// On the dashboard, while the family link is broken: one honest line and a
/// way to try again — something any family can do without calling us.
struct FamilyLinkBanner: View {
    @ObservedObject private var household = HouseholdManager.shared

    var body: some View {
        if household.familyLinkBroken {
            HStack(spacing: 10) {
                Text(verbatim: "⚠️").font(.system(size: 20))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("אין כרגע חיבור למשפחה"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text(tr("מה שמוצג עלול להיות ישן. מנסים להתחבר שוב לבד."))
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Button {
                    Haptic.light()
                    household.retryFamilyLoadIfNeeded()
                } label: {
                    Text(tr("נסו שוב"))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .padding(.horizontal, 12).frame(height: 36)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.white)
            .padding(12)
            .glassPane(radius: 16, tint: Color(hex: "FF8A3D"))
        }
    }
}

/// "מתחברים למשפחה…" — the answer to an edit refused while the family isn't
/// loaded. Attached to EVERY place such an edit can come from, sheets
/// included: an alert can't present from under a sheet, so one on the
/// settings page left a sheet's refused toggle springing back in silence.
struct FamilyConnectionAlert: ViewModifier {
    @ObservedObject private var household = HouseholdManager.shared

    func body(content: Content) -> some View {
        content
            .alert(tr("מתחברים למשפחה…"), isPresented: $household.connectionNotice) {
                Button(tr("נסו שוב")) { household.retryFamilyLoadIfNeeded() }
                Button(tr("הבנתי"), role: .cancel) {}
            } message: {
                Text(tr("הטלפון עדיין לא מחובר למשפחה, אז אי אפשר לעשות את זה כרגע. בדקו שיש אינטרנט — אנחנו מנסים להתחבר שוב לבד."))
            }
    }
}

extension View {
    func familyConnectionAlert() -> some View { modifier(FamilyConnectionAlert()) }
}
