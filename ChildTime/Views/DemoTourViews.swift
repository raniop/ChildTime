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
// The direction after phase A: a first launch opens a short guided tour for
// the PARENT — the child's home, then a question, then what stands behind
// them (every grade, the lock, the parent's own phone) — and ends with "בואו
// תנסו בעצמכם": from there they play freely, as the child would. The cards
// speak to the parent, so they carry no niqqud; the screens under the first
// two stay exactly the child's.
//
// PREVIEW ONLY: these are the screens for approval. Nothing shows them yet.

struct FirstRunCoach: View {
    /// 0 = over the child's home · 1 = over a question · 2…4 = a picture of the
    /// subject on a screen of its own · 5 = "try it yourselves".
    let step: Int
    var onNext: () -> Void = {}
    var onCreateFamily: () -> Void = {}
    var onHaveFamily: () -> Void = {}
    @StateObject private var companion = CompanionController()

    private struct Card { let title: String, line: String }

    private var card: Card? {
        switch step {
        case 0: return Card(title: tr("זה המסך של הילד"),
                            line: tr("כאן בוחרים עולם — חשבון, עברית, אנגלית ועוד — ויוצאים להרפתקה של שאלות."))
        case 1: return Card(title: tr("עונים על שאלות ומרוויחים זמן מסך"),
                            line: tr("כל תשובה נכונה מוסיפה זמן. הילדים לומדים כדי לשחק, בלי ויכוחים על עוד חמש דקות."))
        case 2: return Card(title: tr("שאלות לפי הכיתה של הילד"),
                            line: tr("מגן חובה ועד כיתה ח׳, בכל המקצועות. הרמה מתאימה את עצמה לכל ילד."))
        case 3: return Card(title: tr("נגמרו הדקות? האפליקציות ננעלות"),
                            line: tr("יוטיוב, משחקים וכל מה שתבחרו ננעלים לבד. כדי לפתוח שוב, עונים על עוד שאלות."))
        case 4: return Card(title: tr("ואתם רואים הכול מהטלפון שלכם"),
                            line: tr("מה הילדים למדו, כמה שיחקו ואיפה הם צריכים עזרה, בלי לקחת להם את המכשיר."))
        default: return nil
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            if step <= 1 {
                // The child's own screens ARE the picture — lit on top, the
                // card over the lower half.
                LinearGradient(stops: [.init(color: .black.opacity(0), location: 0),
                                       .init(color: .black.opacity(0.1), location: 0.38),
                                       .init(color: .black.opacity(0.82), location: 0.56),
                                       .init(color: .black.opacity(0.88), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                if let card { coach(card).padding(.bottom, 20) }
            } else {
                // Every later card has a picture of ITS subject in the top half,
                // on a screen of its own — never the same dimmed question again.
                GlassBackdrop().ignoresSafeArea()
                VStack(spacing: 0) {
                    picture
                        .frame(maxWidth: 360)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 22)
                        .padding(.top, 8)
                    if let card { coach(card) } else { finish }
                }
                .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    // MARK: The pictures

    @ViewBuilder private var picture: some View {
        switch step {
        case 2: gradesPicture
        case 3: lockPicture
        case 4: parentPicture
        default: tryPicture
        }
    }

    /// 🦁 Their turn.
    private var tryPicture: some View {
        VStack(spacing: 6) {
            CompanionView(controller: companion, size: 190)
            Text(tr("עכשיו תורכם"))
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(AppGradient.gold)
        }
    }

    /// 🎯 Every grade, every subject.
    private var gradesPicture: some View {
        let grades = [tr("גן"), "א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳"]
        let topics: [(String, String)] = [("🔢", tr("חשבון")), ("✍️", tr("עברית")), ("🔤", tr("אנגלית")),
                                          ("🔬", tr("מדעים")), ("🌍", tr("גאוגרפיה")), ("🧩", tr("חשיבה"))]
        return VStack(spacing: 14) {
            HStack(spacing: 5) {
                ForEach(Array(grades.enumerated()), id: \.offset) { i, g in
                    Text(g)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(i == 3 ? Color(hex: "2A1E5C") : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(i == 3 ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(.white.opacity(0.14))))
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(topics, id: \.1) { emoji, name in
                    VStack(spacing: 6) {
                        Text(emoji).font(.system(size: 34))
                        Text(name)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .glassPane(radius: 16, shadow: false)
                }
            }
        }
    }

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

    // MARK: The cards

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
        VStack(spacing: 9) {
            HStack {
                Text(tr("הסבר קצר להורים"))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2B1C04"))
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppGradient.gold))
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0...5, id: \.self) { i in
                        Circle().fill(.white.opacity(i <= step ? 0.95 : 0.3)).frame(width: 7, height: 7)
                    }
                }
            }
            Text(c.title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)
            Text(c.line)
                .font(.system(size: 15.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onNext) {
                Text(tr("הבא"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .glassFill(AppGradient.gold, radius: 16)
            }
            .buttonStyle(.juicy)
            .padding(.top, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "4A3AB0").opacity(0.98)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 18, y: 6)
        .frame(maxWidth: 440)
        .padding(.horizontal, 14)
    }

    private var finish: some View {
        VStack(spacing: 10) {
            Text(tr("בואו תנסו בעצמכם"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(tr("שחקו כמה שאלות, בדיוק כמו הילדים. כשתרצו, יוצרים משפחה ומוסיפים אותם — ההרשמה לוקחת כדקה."))
                .font(.system(size: 15.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onNext) {
                Text(tr("יאללה, לשחק"))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .glassFill(AppGradient.gold, radius: 16)
            }
            .buttonStyle(.juicy)
            .padding(.top, 4)
            Button(action: onCreateFamily) {
                Text(tr("ליצור משפחה עכשיו"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.juicy)
            haveFamilyLink
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: 440)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "4A3AB0").opacity(0.98)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 20, y: -10)
        .padding(.horizontal, 12)
    }
}
