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
    /// A child's own screen is showing (the first run starts there).
    var onKidScreen = false
    var onSignUp: () -> Void = {}
    /// "כבר יש לכם משפחה?" — out of the tour, to "who uses this device".
    var onHaveFamily: () -> Void = {}

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            if onKidScreen {
                // The two ways to a real family are always on screen: a parent
                // or a child who already has one must never be stuck in a demo.
                Button(action: onHaveFamily) {
                    Text(tr("כבר יש לכם משפחה?"))
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .underline()
                        .lineLimit(1).minimumScaleFactor(0.8)
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
                Text(onKidScreen ? tr("ליצור משפחה") : tr("להתחיל עם הילדים שלכם"))
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
        if tour.firstRunQuiz {
            FirstRunQuiz()
        } else {
            family
        }
    }

    /// The demo family's own screens (phase A): the band, and under it the
    /// parent's home or one child's screen.
    private var family: some View {
        VStack(spacing: 0) {
            DemoTourBand(onKidScreen: kid != nil,
                         onSignUp: { Haptic.light(); tour.invite = .band },
                         onHaveFamily: { Haptic.light(); tour.end(signUp: false) })
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

// MARK: - 🎬 First run: straight into the questions
//
// Rani's final shape (2026-10-12): a parent who has just installed Tofy lands
// on Tofy Time's questions. The first right answer and the first wrong one
// are explained by Tofy himself, in his speech bubble (see the quiz); after
// four answers (then every five) one question: "ליצור ילד" or "להמשיך לשחק".
// These speak to the parent: no niqqud.

/// The whole first run: the quiz, and the question over it.
struct FirstRunQuiz: View {
    @ObservedObject private var tour = DemoTour.shared
    @State private var quizOn = false
    /// How the quiz was left: "ליצור ילד" goes on to sign-up; ✕ (or the end of
    /// the round) just to "who uses this device".
    @State private var createChild = false

    var body: some View {
        GlassBackdrop().ignoresSafeArea()
            .onAppear { quizOn = true }
            .fullScreenCover(isPresented: $quizOn, onDismiss: { tour.end(signUp: createChild) }) {
                QuestionRunnerView(mode: .smartFeed, purpose: .earnTime)
                    .environment(\.layoutDirection, .app)   // a cover can arrive left-to-right
                    .overlay {
                        if tour.askToCreate {
                            FirstRunAsk(answered: tour.answered,
                                        onCreate: { Haptic.medium(); createChild = true; tour.askToCreate = false; quizOn = false },
                                        onPlay: { Haptic.light(); tour.askToCreate = false })
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.22), value: tour.askToCreate)
            }
    }
}

/// The one question of the first run: create a child's profile, or play on.
struct FirstRunAsk: View {
    let answered: Int
    var onCreate: () -> Void = {}
    var onPlay: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("🧒").font(.system(size: 46))
                Text(tr("רוצים ליצור פרופיל לילד שלכם?"))
                    .font(.system(size: 23, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(tr("ככה הילדים מרוויחים זמן מסך בטופי: עונים על שאלות, והשניות נצברות. ההרשמה לוקחת כדקה."))
                    .font(.system(size: 15.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onCreate) {
                    Text(tr("ליצור ילד"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .glassFill(AppGradient.gold, radius: 16)
                }
                .buttonStyle(.juicy)
                .padding(.top, 4)
                Button(action: onPlay) {
                    Text(tr("להמשיך לשחק"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.juicy)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: 440)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "4A3AB0").opacity(0.98)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 20, y: -10)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
}
