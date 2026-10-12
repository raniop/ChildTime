import SwiftUI

// 🎬 סיור הדגמה — a family to look around in before signing up (Rani,
// 2026-10-12: parents say "show us an example" and won't install → sign up →
// create children just to see one).
//
// PREVIEW ONLY for now: the three pieces Rani approves from real screenshots
// before anything is wired — the entry row, the band that stays on top, and
// the invitation to sign up. The demo itself (its own storage, no account,
// the cloud layer off) is not built yet.
enum DemoTour {
    /// True while the demo family is on screen. For now only a DEBUG launch
    /// with DEMO_TOUR=1 turns it on; the real switch comes with the demo.
    static var isOn: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["DEMO_TOUR"] != nil
        #else
        return false
        #endif
    }
}

#if DEBUG

/// The third row on the first screen, under the two role cards. Quieter than
/// them on purpose: it is a look around, not a way to set the device up.
struct DemoTourEntryRow: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Text("👀").font(.system(size: 26))
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("רוֹצִים רַק לִרְאוֹת אֵיךְ זֶה עוֹבֵד?"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(tr("כְּנִיסָה לְהַדְגָּמָה · בְּלִי הַרְשָׁמָה"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        }
        .buttonStyle(.juicy)
    }
}

/// The strip that stays above every screen of the demo, the parent's and the
/// child's: says this is a demo, and is the one standing way to sign up.
struct DemoTourBand: View {
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.sm) {
                Text(tr("🎬 זו הדגמה"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: AppSpacing.sm)
                Text(tr("להתחיל עם הילדים שלכם"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
            }
            .padding(.leading, AppSpacing.lg)
            .padding(.trailing, AppSpacing.sm)
            .padding(.vertical, 6)
            .clearOfBar()
            .background(Color(hex: "2A1E5C").opacity(0.92).ignoresSafeArea(edges: .top))
        }
        .buttonStyle(.plain)
    }
}

/// "בואו נירשם" — what the band opens, and what a closed feature shows instead
/// of an error. Leaving it is always one tap: back to the demo, or out of it.
struct DemoTourInviteSheet: View {
    var onSignUp: () -> Void = {}
    var onStay: () -> Void = {}
    var onLeave: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onStay() }
            VStack(spacing: 10) {
                Text("🎉").font(.system(size: 44))
                Text(tr("עכשיו עם הילדים שלכם"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(tr("מה שראיתם הוא משפחה לדוגמה. ההרשמה לוקחת כדקה, ואחריה מוסיפים את הילדים ומתחילים."))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    point("🎁", tr("30 יום של טופי+ במתנה"))
                    point("🧹", tr("ההדגמה נמחקת מהמכשיר, ומתחילים נקי"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.1)))
                Button(action: onSignUp) {
                    Text(tr("להירשם ולהתחיל"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .glassFill(AppGradient.gold, radius: 16)
                }
                .buttonStyle(.juicy)
                .padding(.top, 4)
                Button(action: onStay) {
                    Text(tr("להמשיך בהדגמה"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.juicy)
                Button(action: onLeave) {
                    Text(tr("יציאה מההדגמה"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: 440)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "4A3AB0").opacity(0.97)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 20, y: -10)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    private func point(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(emoji).font(.system(size: 16))
            Text(text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// DEMO_SCREEN=demotour | demoinvite — the parent home as the demo shows it.
struct DemoTourPreview: View {
    var invite = false

    var body: some View {
        VStack(spacing: 0) {
            DemoTourBand()
            ParentDashboardView(isRoot: true)
        }
        .background(GlassBackdrop())
        .overlay { if invite { DemoTourInviteSheet() } }
    }
}

#endif
