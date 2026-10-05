import SwiftUI

/// 🧭 A first-run tour: one point per button, in order, on the REAL screen.
///
/// Approved in `reports/games/onboarding-mockup.html` (band ג), and widened by
/// Rani: "ולמה רק 3 נקודות הדרכה במצב הורים? צריך להסביר על כל כפתור מה עושה",
/// and "צריך גם פעם אחת על מסך של הילד".
///
/// How it fits together:
///  * A control marks itself with `.coachMark("p.bell")`. That publishes its
///    bounds as an `Anchor`, so the tour never needs to know where anything is
///    laid out — on an SE, an iPad or the Duo it points at what is really there.
///  * The screen owns a `.coachTour(...)` with the steps, in order. A step
///    whose control is not on screen right now (no device yet, below the fold,
///    a feature this family does not have) is simply skipped.
///  * Each tour runs ONCE per key, and can be replayed from the parent's
///    settings (`CoachTours.reset()`).
///
/// The overlay is drawn in a left-to-right space on purpose: anchors resolve to
/// physical points, and an RTL parent mirrors `position(x:)` — the same trap
/// that made the story's side taps run backwards. Text inside the card is set
/// back to the app's direction.
struct CoachStep: Identifiable, Equatable {
    let id: String
    let title: String
    let text: String
}

private struct CoachMarkKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// Mark this control as a stop on a tour.
    func coachMark(_ id: String) -> some View {
        anchorPreference(key: CoachMarkKey.self, value: .bounds) { [id: $0] }
    }

    /// Mark only one of a repeated control — the FIRST child's card, say. The
    /// condition is fixed per row, so it never flips a view's identity live.
    @ViewBuilder func coachMark(_ id: String, if on: Bool) -> some View {
        if on { coachMark(id) } else { self }
    }

    /// Run a tour over this screen while `isActive`. `onFinish` fires once,
    /// whether the tour ended on its last step or was skipped.
    /// `forKid` sets the card's own words with niqqud (the child's side) or
    /// without (the parent's).
    func coachTour(_ steps: [CoachStep], forKid: Bool, isActive: Binding<Bool>,
                   onFinish: @escaping () -> Void) -> some View {
        modifier(CoachTourModifier(steps: steps, forKid: forKid, isActive: isActive, onFinish: onFinish))
    }
}

/// Which tours have run, per device (and per child for the kid's).
enum CoachTours {
    static func key(_ tour: String) -> String { "coachTour.done.\(tour)" }
    static func isDone(_ tour: String) -> Bool { UserDefaults.standard.bool(forKey: key(tour)) }
    static func markDone(_ tour: String) { UserDefaults.standard.set(true, forKey: key(tour)) }
    /// "הַצִּיגוּ שׁוּב אֶת הַהַדְרָכָה" — every tour on this device runs again.
    static func reset() {
        for k in UserDefaults.standard.dictionaryRepresentation().keys where k.hasPrefix("coachTour.done.") {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
    /// Screenshot runs: `DEMO_COACH=1` forces the tour on.
    static var forcedInDemo: Bool { ProcessInfo.processInfo.environment["DEMO_COACH"] == "1" }
}

private struct CoachTourModifier: ViewModifier {
    let steps: [CoachStep]
    let forKid: Bool
    @Binding var isActive: Bool
    let onFinish: () -> Void
    @State private var index = 0

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(CoachMarkKey.self) { anchors in
            GeometryReader { geo in
                if isActive {
                    let bounds = CGRect(origin: .zero, size: geo.size)
                    // Only stops that are really on screen right now, in order.
                    let live: [(CoachStep, CGRect)] = steps.compactMap { step in
                        guard let a = anchors[step.id] else { return nil }
                        let r = geo[a]
                        guard r.width > 4, r.height > 4, bounds.intersects(r),
                              r.minY >= -4, r.maxY <= geo.size.height + 4 else { return nil }
                        return (step, r)
                    }
                    if live.isEmpty {
                        Color.clear.onAppear { finish() }
                    } else {
                        let i = min(index, live.count - 1)
                        CoachSpotlight(step: live[i].0, target: live[i].1, size: geo.size, forKid: forKid,
                                       number: i + 1, total: live.count,
                                       onNext: { i + 1 < live.count ? advance() : finish() },
                                       onSkip: finish)
                            .id(live[i].0.id)
                            .transition(.opacity)
                    }
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .ignoresSafeArea()
        }
    }

    private func advance() {
        Haptic.light()
        withAnimation(.easeInOut(duration: 0.22)) { index += 1 }
    }

    private func finish() {
        guard isActive else { return }
        withAnimation(.easeOut(duration: 0.2)) { isActive = false }
        index = 0
        onFinish()
    }
}

/// One stop: the screen dimmed, a hole around the control with a gold dashed
/// ring, and the card under (or over) it.
private struct CoachSpotlight: View {
    let step: CoachStep
    let target: CGRect
    let size: CGSize
    let forKid: Bool
    let number: Int
    let total: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    private var hole: CGRect { target.insetBy(dx: -8, dy: -8) }
    private var cardWidth: CGFloat { min(size.width - 32, 380) }
    /// Below the control when there is room for the card, otherwise above it.
    private var cardBelow: Bool { hole.maxY + 190 < size.height || hole.midY < size.height / 2 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The dim, with the control cut out of it. A tap anywhere moves on.
            Rectangle()
                .fill(Color.black.opacity(0.62))
                .mask {
                    Rectangle()
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .frame(width: hole.width, height: hole.height)
                                .position(x: hole.midX, y: hole.midY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onNext)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColor.starGold, style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
                .frame(width: hole.width, height: hole.height)
                .position(x: hole.midX, y: hole.midY)
                .allowsHitTesting(false)

            card
                .frame(width: cardWidth)
                .position(x: min(max(hole.midX, cardWidth / 2 + 16), size.width - cardWidth / 2 - 16),
                          y: cardBelow ? hole.maxY + 14 + cardHeight / 2 : hole.minY - 14 - cardHeight / 2)
        }
        .frame(width: size.width, height: size.height)
    }

    /// A generous estimate for placement; the card itself sizes to its text.
    private var cardHeight: CGFloat { 150 }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "2A1E5C"))
            Text(step.text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(hex: "2A1E5C").opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button(action: onNext) {
                    Text(number < total ? (forKid ? tr("הַבָּא") : tr("הבא"))
                                        : (forKid ? tr("סִיַּמְנוּ") : tr("סיימנו")))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 9)
                        .background(Capsule().fill(Color(hex: "6C4CF1")))
                }
                .buttonStyle(.plain)
                Text(forKid ? tr("\(number) מִתּוֹךְ \(total)") : tr("\(number) מתוך \(total)"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C").opacity(0.55))
                    .monospacedDigit()
                Spacer(minLength: 0)
                if number < total {
                    Button(action: onSkip) {
                        Text(forKid ? tr("דַּלְּגוּ") : tr("דלג"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "2A1E5C").opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
        .environment(\.layoutDirection, .app)
    }
}
