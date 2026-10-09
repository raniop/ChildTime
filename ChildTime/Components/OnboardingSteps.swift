import SwiftUI

/// 🧭 A brand-new parent's way from sign-up to a working child, in four steps
/// with a bar on top (Rani, 2026-10-05: "פחות שלבים ושלבים למעלה שמראים
/// 1,2,3,4 התקדמות"). The walk-through of a new parent found 18 screens and a
/// lock that was never turned on; the approved flow is
///
///   ① משפחה  — the family's name, then the parent code
///   ② ילד    — one screen: name, girl/boy, grade, daily maximum
///   ③ מכשיר  — "does she have her own device?" → QR, or play on this phone
///   ④ נעילה  — on the child's phone: approve Screen Time, then its passcode
///
/// and only then "הכל מוכן" with the 30-day gift. A family that says the child
/// plays on the parent's phone ends at ③ and gets the home tour, which closes
/// by offering to hand the phone over right now.
///
/// The flow is ON only for a family created through it (`begin()` when the new
/// family is made). Existing families never see any of it.
enum ParentOnboarding {
    private static let activeKey = "onboarding.v2.active"
    /// The family chose "she plays on my phone" — after the tour, offer to start.
    private static let offerPlayKey = "onboarding.v2.offerPlay"

    static var isActive: Bool { UserDefaults.standard.bool(forKey: activeKey) }

    static func begin() {
        UserDefaults.standard.set(true, forKey: activeKey)
        UserDefaults.standard.removeObject(forKey: offerPlayKey)
    }

    /// The flow is over — whichever way it ended (done, or "later").
    static func finish() {
        UserDefaults.standard.set(false, forKey: activeKey)
    }

    /// The child who should be offered "play here now" when the tour ends.
    static var offerPlayChildID: UUID? {
        get { UserDefaults.standard.string(forKey: offerPlayKey).flatMap(UUID.init(uuidString:)) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: offerPlayKey) }
    }

    /// Step names, in order. Parent-facing: no niqqud.
    static var stepNames: [String] { [tr("משפחה"), tr("ילד"), tr("מכשיר"), tr("נעילה")] }
}

/// The 1·2·3·4 bar. `current` 1…4 is the step on screen; 5 = all done.
struct OnboardingStepsBar: View {
    let current: Int
    /// Said under the bar, after "שלב N מתוך 4" — e.g. "בטלפון של הילד".
    var note: String? = nil

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                ForEach(Array(ParentOnboarding.stepNames.enumerated()), id: \.offset) { i, name in
                    let n = i + 1
                    VStack(spacing: 4) {
                        Capsule()
                            .fill(n < current ? AppColor.successMint
                                  : n == current ? AppColor.starGold : .white.opacity(0.25))
                            .frame(height: 5)
                        // The same words on every step; the colour says done / now / next.
                        Text("\(n) · \(name)")
                            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                            .foregroundStyle(n < current ? Color(hex: "C9FFE7")
                                             : n == current ? Color(hex: "FFE28A") : .white.opacity(0.6))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if current <= 4 {
                // The same line on every step (Rani: "אחד לאחד") — no per-screen note.
                Text(tr("שלב \(current) מתוך 4"))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        // ONE bar, identical on every step (Rani: "אחד לאחד") — the family
        // step's: full width up to 520, clear of the foldable's clock on both
        // sides. Callers place it at the top of the FULL glass, never inside a
        // narrowed column.
        .frame(maxWidth: 520)
        .clearOfBarBothSides()
        .environment(\.layoutDirection, .app)
        .accessibilityElement(children: .combine)
    }
}

/// 🎉 "הכל מוכן!" — the end of the flow, and the moment the 30-day gift is told.
/// `playsHere`: the child plays on this phone (no device to connect), so the
/// button leads into the home tour instead of straight home.
struct OnboardingDoneView: View {
    let child: Profile?
    let playsHere: Bool
    let onDone: () -> Void

    @ObservedObject private var household = HouseholdManager.shared
    @State private var confetti = 0

    private var name: String { child.map { Question.stripNiqqud($0.name) } ?? "" }
    private var girl: Bool { child?.gender == .girl }
    private var giftUntil: Date? {
        guard let hh = household.household, hh.premiumSource == "gift",
              let until = hh.giftUntil ?? hh.premiumUntil, until > Date() else { return nil }
        return until
    }

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            SparkleField(count: 14, size: 12)
            FancyConfetti(trigger: confetti)
            VStack(spacing: 16) {
                OnboardingStepsBar(current: 5)
                    .padding(.top, 8)
                Spacer(minLength: 8)
                Text("🎉").font(.system(size: 72))
                Text(tr("הכל מוכן!"))
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if giftUntil != nil { giftCard }
                Spacer(minLength: 8)
                OnboardingFooter(title: playsHere ? tr("בואו נכיר את המסך — 30 שניות") : tr("לבית של המשפחה")) {
                    Haptic.success()
                    GiftWelcome.markShown(household.household)
                    onDone()
                }
            }
            .padding(.horizontal, OnboardingFooter.sidePadding)
            .frame(maxWidth: 520)
        }
        .environment(\.layoutDirection, .app)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { confetti &+= 1 } }
    }

    private var subtitle: String {
        if playsHere {
            return girl ? tr("\(name) תשחק בטלפון הזה, במצב ילד") : tr("\(name) ישחק בטלפון הזה, במצב ילד")
        }
        return girl ? tr("הטלפון של \(name) נעול, והיא מרוויחה זמן מסך על כל תשובה נכונה")
                    : tr("הטלפון של \(name) נעול, והוא מרוויח זמן מסך על כל תשובה נכונה")
    }

    private var giftCard: some View {
        VStack(spacing: 4) {
            Text("🎁").font(.system(size: 38))
            Text(tr("ובונוס: 30 יום טופי+ במתנה"))
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(tr("כל העולמות פתוחים לכל הילדים"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassPane(radius: 16, tint: AppColor.starGold)
    }
}

/// 🧭 The one bottom every screen of the flow shares — Rani: "זה לא מוזר
/// שהכפתורים כל פעם במיקום אחר?". The gold button sits at the same height, the
/// same width and the same distance from the bottom on every screen, and the
/// text link under it always keeps its row (empty when there is none), so
/// moving from screen to screen never moves the thumb.
struct OnboardingFooter: View {
    let title: String
    var enabled: Bool = true
    var busy: Bool = false
    var link: String? = nil
    var onLink: (() -> Void)? = nil
    let action: () -> Void

    /// The flow's single column: screens use this padding so the button's
    /// edges line up too.
    static let sidePadding: CGFloat = 22

    var body: some View {
        VStack(spacing: 12) {
            Button {
                guard enabled, !busy else { return }
                action()
            } label: {
                ZStack {
                    if busy { ProgressView().tint(Color(hex: "2A1E5C")) }
                    else {
                        Text(title)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "2A1E5C"))
                            .lineLimit(1).minimumScaleFactor(0.75)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .glow(AppColor.starGold, radius: enabled ? 12 : 0)
                // Dimmed by colour, not by transparency: a see-through button
                // let the options scrolling underneath show through it (Rani,
                // on the closed Duo).
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(hex: "2A1E5C").opacity(enabled ? 0 : 0.35)))
            }
            .buttonStyle(.juicy)

            Button {
                Haptic.light()
                onLink?()
            } label: {
                Text(link ?? " ")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .underline(link != nil)
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(height: 20)
            }
            .buttonStyle(.plain)
            .opacity(link == nil ? 0 : 1)
            .disabled(link == nil)
        }
        .padding(.bottom, 10)
        .padding(.top, 14)
        // A soft floor under the footer, so content scrolling beneath it fades
        // out instead of running through the button.
        .background(
            LinearGradient(stops: [.init(color: .clear, location: 0),
                                   .init(color: Color(hex: "2A1E5C").opacity(0.55), location: 0.4),
                                   .init(color: Color(hex: "2A1E5C").opacity(0.7), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .padding(.horizontal, -40)
                .ignoresSafeArea(edges: .bottom)
                // Not on the open foldable: the form fits there, nothing scrolls
                // under the button, and the floor was only a dark box (Rani: "הרקע
                // הכחול כהה נראה מוזר").
                .opacity(DisplayGeometry.shared.isWideShort ? 0 : 1)
        )
    }
}
