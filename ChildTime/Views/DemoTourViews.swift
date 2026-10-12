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
            if let card = tour.card {
                FirstRunCard(kind: card,
                             onDone: { closeCard(card) },
                             onCreateFamily: { Haptic.medium(); tour.end(signUp: true) },
                             onParentView: { Haptic.light(); tour.mark(.closing); tour.card = nil; tour.backToParent() },
                             onHaveFamily: { Haptic.light(); tour.end(signUp: false) })
                    .transition(.opacity)
            }
        }
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
        .animation(.easeOut(duration: 0.25), value: tour.card)
        .animation(.easeOut(duration: 0.2), value: tour.kidID)
        .onReceive(ProgressStore.shared.objectWillChange.receive(on: DispatchQueue.main)) { _ in
            let open = ProgressStore.shared.isUnlocked || ProgressStore.shared.isOpeningWindow
            guard open != windowShowing else { return }
            windowShowing = open
            // 🎬 The minutes were opened for the first time: what that means
            // on the child's real phone — and what happens when they run out.
            if open, tour.needs(.window), tour.card == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if tour.needs(.window), tour.card == nil, tour.invite == nil { tour.card = .window }
                }
            }
        }
    }

    private func closeCard(_ card: DemoTour.Tip) {
        Haptic.light()
        tour.mark(card)
        // The lock is the last piece of the idea — the closing card follows it.
        tour.card = (card == .window && tour.closingIsDue) ? .closing : nil
    }
}

// MARK: - 🎬 First run: the two tips that are a picture
//
// Most first-run tips point at the thing itself (the spotlight of
// `CoachMarks`, driven from `DemoTour.Tip`). Two are about something that is
// NOT on this screen — the child's other apps locking, and the parent's own
// phone — so each gets a picture of its subject in the top half, and the
// words under it. They speak to the parent: no niqqud.

struct FirstRunCard: View {
    /// `.window` (the minutes were opened) or `.closing` (create a family).
    let kind: DemoTour.Tip
    var onDone: () -> Void = {}
    var onCreateFamily: () -> Void = {}
    var onParentView: () -> Void = {}
    var onHaveFamily: () -> Void = {}

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            VStack(spacing: 0) {
                Group { if kind == .window { lockPicture } else { parentPicture } }
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 8)
                if kind == .window { windowCard } else { closingCard }
            }
            .padding(.bottom, 14)
        }
    }

    // MARK: The pictures

    /// 🔒 The child's own screen once the minutes are gone: everything locked but Tofy.
    private var lockPicture: some View {
        let apps: [(String, String)] = [("▶️", "E5484D"), ("🎮", "7C5CFF"), ("📺", "2D9CDB"),
                                        ("🎵", "F2994A"), ("🦁", ""), ("💬", "27AE60"),
                                        ("🛒", "EB5757"), ("📷", "9B51E0"), ("🌐", "56CCF2")]
        return VStack(spacing: 14) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                ForEach(Array(apps.enumerated()), id: \.offset) { _, app in
                    let tofy = app.1.isEmpty
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(tofy ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color(hex: app.1)))
                            .aspectRatio(1, contentMode: .fit)
                            .opacity(tofy ? 1 : 0.55)
                            .overlay(Text(app.0).font(.system(size: 36)).opacity(tofy ? 1 : 0.7))
                        if !tofy {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Color(hex: "2A1E5C")))
                                .offset(x: 5, y: 5)
                        }
                    }
                }
            }
            .padding(.horizontal, 26)
            Text(tr("טופי נשאר פתוח — עונים, ומרוויחים זמן"))
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
        }
    }

    /// 📱 What the parent's own phone shows about one child.
    private var parentPicture: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text("👧").font(.system(size: 30))
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(.white.opacity(0.2)))
                    .overlay(Circle().stroke(AppColor.starGold, lineWidth: 2))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("דנה · כיתה ו׳"))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: "5CFF9D")).frame(width: 8, height: 8)
                        Text(tr("משחקת עכשיו · נשארו 23:38"))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Spacer(minLength: 4)
                Text(verbatim: "91%")
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "5CFF9D"))
            }
            HStack(spacing: 8) {
                stat("24", tr("דקות היום"))
                stat("22", tr("שאלות"))
                stat("20", tr("נכונות"))
            }
            HStack(spacing: 8) {
                chip(tr("📊 הדוח"))
                chip(tr("💝 מתנת דקות"))
                chip(tr("🔒 נעילה"))
            }
        }
        .padding(16)
        .glassPane(radius: 16)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value).font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 11.5, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1).minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.2)))
    }

    // MARK: The words

    private var tag: some View {
        HStack {
            Text(tr("הסבר קצר להורים"))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "2B1C04"))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
            Spacer()
        }
    }

    private func words(_ title: String, _ line: String) -> some View {
        VStack(spacing: 9) {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            Text(line)
                .font(.system(size: 15.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func gold(_ text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 17.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "2A1E5C"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassFill(AppGradient.gold, radius: 16)
        }
        .buttonStyle(.juicy)
        .padding(.top, 4)
    }

    private func plate<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack(spacing: 9) { content() }
            .padding(16)
            .frame(maxWidth: 440)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "4A3AB0").opacity(0.98)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 18, y: 6)
            .padding(.horizontal, 14)
    }

    private var windowCard: some View {
        plate {
            tag
            words(tr("כשהזמן נגמר, האפליקציות ננעלות"),
                  tr("עכשיו הן פתוחות לילד, והשעון רץ. כשהוא מגיע לאפס הן ננעלות לבד, וכדי לפתוח שוב עונים על עוד שאלות."))
            gold(tr("הבנתי"), action: onDone)
        }
    }

    private var closingCard: some View {
        plate {
            tag
            words(tr("ואתם רואים הכול מהטלפון שלכם"),
                  tr("מה הילדים למדו, כמה שיחקו ואיפה הם צריכים עזרה. ההרשמה לוקחת כדקה, ו־30 הימים הראשונים של טופי+ במתנה."))
            gold(tr("ליצור משפחה"), action: onCreateFamily)
            Button(action: onParentView) {
                Text(tr("לראות את המסך של ההורה"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.juicy)
            HStack(spacing: 18) {
                Button(action: onDone) {
                    Text(tr("להמשיך לשחק")).underline()
                }
                Button(action: onHaveFamily) {
                    Text(tr("כבר יש לכם משפחה?")).underline()
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.88))
            .padding(.top, 2)
        }
    }
}
