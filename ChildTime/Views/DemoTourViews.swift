import SwiftUI
import Combine

// 🎬 סיור הדגמה — the screens of the demo tour (see `DemoTour` for what it is
// and why nothing of it leaves the device). Three pieces, approved by Rani from
// real screenshots (2026-10-12): the entry row on the first screen, the band
// that stays on top, and the invitation to sign up.

/// The row pinned to the bottom of the first screen, apart from the two role
/// cards: it is a look around, not a way to set the device up.
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

/// The strip above every screen of the tour, the parent's and the child's:
/// says this is a demo, and is the one standing way to sign up. On a child's
/// screen it is also the way back to the parent's.
struct DemoTourBand: View {
    /// The child whose screen is showing; nil on the parent's home.
    var kidName: String? = nil
    var onSignUp: () -> Void = {}
    var onBack: () -> Void = {}

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if kidName != nil {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.backward").font(.system(size: 13, weight: .heavy))
                        Text(tr("חזרה להורים"))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(tr("🎬 זו הדגמה"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer(minLength: AppSpacing.sm)
            Button(action: onSignUp) {
                Text(tr("להתחיל עם הילדים שלכם"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, AppSpacing.lg)
        .padding(.trailing, AppSpacing.sm)
        .padding(.vertical, 6)
        .clearOfBar()
        .background(Color(hex: "2A1E5C").opacity(0.92).ignoresSafeArea(edges: .top))
    }
}

/// "בואו נירשם" — what the band opens, and what something closed in the tour
/// shows instead of an error. Leaving it is always one tap: back to the demo,
/// or out of it.
struct DemoTourInviteSheet: View {
    var reason: DemoTour.Invite = .band
    var onSignUp: () -> Void = {}
    var onStay: () -> Void = {}
    var onLeave: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onStay() }
            VStack(spacing: 10) {
                Text(reason == .closed ? "🔑" : "🎉").font(.system(size: 44))
                Text(reason == .closed ? tr("זה נפתח אחרי ההרשמה") : tr("עכשיו עם הילדים שלכם"))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(reason == .closed
                     ? tr("בהדגמה אפשר להסתכל, לתת מתנת דקות ולשחק כמו הילד. את השאר עושים במשפחה שלכם, וההרשמה לוקחת כדקה.")
                     : tr("מה שראיתם הוא משפחה לדוגמה. ההרשמה לוקחת כדקה, ואחריה מוסיפים את הילדים ומתחילים."))
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

/// The whole app while the tour is on: the band, and under it the parent's
/// home of the demo family or one of its children's own screens.
struct DemoTourRoot: View {
    @ObservedObject private var tour = DemoTour.shared
    @EnvironmentObject var profiles: ProfileStore
    /// Mirrors the play window, like the app's own root does: the store
    /// publishes BEFORE it changes, so the value is read a beat later.
    @State private var windowShowing = false

    private var kid: Profile? { tour.kidID.flatMap { id in profiles.profiles.first { $0.id == id } } }

    var body: some View {
        VStack(spacing: 0) {
            DemoTourBand(kidName: kid?.name,
                         onSignUp: { Haptic.light(); tour.invite = .band },
                         onBack: { Haptic.light(); tour.backToParent() })
            if kid != nil {
                Group {
                    if windowShowing { UnlockedView() } else { WorldMapView() }
                }
                .transition(.opacity)
            } else {
                ParentDashboardView(isRoot: true)
                    .transition(.opacity)
            }
        }
        .background(GlassBackdrop())
        .overlay {
            if let reason = tour.invite {
                DemoTourInviteSheet(reason: reason,
                                    onSignUp: { Haptic.medium(); tour.end(signUp: true) },
                                    onStay: { tour.invite = nil },
                                    onLeave: { Haptic.light(); tour.end(signUp: false) })
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: tour.invite)
        .animation(.easeOut(duration: 0.2), value: tour.kidID)
        .onReceive(ProgressStore.shared.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            let open = ProgressStore.shared.isUnlocked || ProgressStore.shared.isOpeningWindow
            if open != windowShowing { windowShowing = open }
        }
    }
}

// MARK: - 🎬 First run: straight into a question (Rani, 2026-10-12 — preview)
//
// The direction after phase A: a first launch lands on a QUESTION, as the
// child would see it, and after each of the first answers a short card tells
// the parent what just happened — the minutes, the grade, the lock, their own
// phone — until the fifth answer brings "ליצור משפחה". The cards speak to the
// parent, so they carry no niqqud; the question under them stays the child's.
//
// PREVIEW ONLY: these are the screens for approval. Nothing shows them yet.

struct FirstRunCoach: View {
    /// 0 = the opening card, over the first question · 1…4 = after each answer · 5 = the finish.
    let step: Int
    /// What the first answer just paid — said in the first card.
    var earnedSeconds: Int = 24
    var onNext: () -> Void = {}
    var onCreateFamily: () -> Void = {}
    var onParentView: () -> Void = {}
    var onHaveFamily: () -> Void = {}

    /// The quiz shelf (streak, time, hint) — the first card points at it, so
    /// it is the one part of the screen left bright.
    private static let shelf: CGFloat = 158

    private struct Card { let emoji: String, title: String, line: String }

    private var card: Card? {
        switch step {
        case 0: return Card(emoji: "👋",
                            title: tr("ככה הילדים משחקים בטופי"),
                            line: tr("עונים על שאלות ומרוויחים זמן מסך. נסו בעצמכם: חמש שאלות, בערך דקה."))
        case 1: return Card(emoji: "⏱",
                            title: tr("הרווחתם \(earnedSeconds) שניות של זמן מסך"),
                            line: tr("כל תשובה נכונה מוסיפה זמן. הילדים לומדים כדי לשחק, בלי ויכוחים על עוד חמש דקות."))
        case 2: return Card(emoji: "🎯",
                            title: tr("שאלות לפי הכיתה של הילד"),
                            line: tr("מגן חובה ועד כיתה ח׳: חשבון, עברית, אנגלית, מדעים ועוד. הרמה מתאימה את עצמה לכל ילד."))
        case 3: return Card(emoji: "🔒",
                            title: tr("נגמרו הדקות? האפליקציות ננעלות"),
                            line: tr("יוטיוב, משחקים וכל מה שתבחרו ננעלים לבד. כדי לפתוח שוב, עונים על עוד שאלות."))
        case 4: return Card(emoji: "📱",
                            title: tr("ואתם רואים הכול מהטלפון שלכם"),
                            line: tr("מה הילדים למדו, כמה שיחקו ואיפה הם צריכים עזרה. אפשר גם לתת מתנת דקות או לנעול מרחוק."))
        default: return nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if step >= 0 {
                VStack(spacing: 0) {
                    Color.black.opacity(0.55)
                    if step == 1 { Color.clear.frame(height: Self.shelf) }
                }
                .ignoresSafeArea()
            }
            switch step {
            case 0...4: if let card { coach(card).padding(.bottom, step == 1 ? Self.shelf - 22 : 28) }
            default: finish.padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // The opening card also holds the quiet way out for a family that already exists.
    private var haveFamilyLink: some View {
        Button(action: onHaveFamily) {
            HStack(spacing: 5) {
                Text(tr("כבר יש לכם משפחה בטופי?"))
                    .foregroundStyle(.white.opacity(0.8))
                Text(tr("כניסה"))
                    .foregroundStyle(.white)
                    .underline()
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func coach(_ c: Card) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 9) {
                HStack {
                    Text(tr("הסבר קצר להורים"))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2B1C04"))
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                    Spacer()
                    HStack(spacing: 5) {
                        ForEach(0...4, id: \.self) { i in
                            Circle().fill(.white.opacity(i <= step ? 0.95 : 0.3)).frame(width: 7, height: 7)
                        }
                    }
                }
                Text(c.emoji).font(.system(size: 44))
                Text(c.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(c.line)
                    .font(.system(size: 15.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onNext) {
                    Text(step == 0 ? tr("לשאלה הראשונה") : (step == 4 ? tr("עוד שאלה אחת") : tr("לשאלה הבאה")))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .glassFill(AppGradient.gold, radius: 16)
                }
                .buttonStyle(.juicy)
                .padding(.top, 4)
                if step == 0 { haveFamilyLink }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "4A3AB0").opacity(0.98)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 18, y: 6)
            // The first card points down at the time that just grew on the shelf.
            if step == 1 {
                HStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(hex: "4A3AB0"))
                        .padding(.leading, 34)
                        .offset(y: -4)
                    Spacer()
                }
                .environment(\.layoutDirection, .leftToRight)
            }
        }
        .frame(maxWidth: 440)
        .padding(.horizontal, 14)
    }

    private var finish: some View {
        VStack(spacing: 10) {
            Text("🎉").font(.system(size: 46))
            Text(tr("5 שאלות, 2 דקות של זמן מסך"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(tr("עכשיו תורם של הילדים. יוצרים משפחה, מוסיפים את הילדים, והם מתחילים להרוויח."))
                .font(.system(size: 15.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                point("🎁", tr("30 יום של טופי+ במתנה"))
                point("⏳", tr("ההרשמה לוקחת כדקה"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.1)))
            Button(action: onCreateFamily) {
                Text(tr("ליצור משפחה"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .glassFill(AppGradient.gold, radius: 16)
            }
            .buttonStyle(.juicy)
            .padding(.top, 4)
            Button(action: onParentView) {
                Text(tr("לראות מה ההורה רואה"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.juicy)
            Button(action: onNext) {
                Text(tr("עוד כמה שאלות"))
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
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "4A3AB0").opacity(0.98)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 20, y: -10)
        .padding(.horizontal, 12)
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
