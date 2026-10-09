import SwiftUI
import UIKit
#if canImport(DeclaredAgeRange)
import DeclaredAgeRange
#endif

/// 🧒🚫 Before a device becomes a PARENT device: is a grown-up holding it?
/// Twice a child installed Tofy from the store and opened a family as its
/// "parent" (Rani, 2026-10-08). First Apple is asked (Declared Age Range,
/// iOS 26+) — for a child in Family Sharing the parent set that age, so it
/// can't be bluffed. No answer → a neutral birth-year wheel that starts on a
/// child's year. Under 18 → a friendly screen with the ways forward instead
/// of the sign-up. Only the verdict is kept, never the year or the range.
enum AgeGate {
    enum Verdict: String { case adult, minor }

    private static let key = "ageGate.verdict"

    /// Kept for this install only — a reinstall starts clean, like everything else.
    static var verdict: Verdict? {
        get { UserDefaults.standard.string(forKey: key).flatMap(Verdict.init(rawValue:)) }
        set { UserDefaults.standard.set(newValue?.rawValue, forKey: key) }
    }

    /// The wheel opens on a CHILD's year (Rani: "שיבלבל את הילדים") — a grown-up
    /// scrolls back to theirs, a child who just taps on is under 18.
    static let wheelStart = 2016

    static func verdict(forBirthYear year: Int, now: Date = Date()) -> Verdict {
        let thisYear = Calendar(identifier: .gregorian).component(.year, from: now)
        return thisYear - year >= 18 ? .adult : .minor
    }

    /// Apple's answer, or nil when there is none (older iOS, declined, not
    /// available, an error) — then the wheel asks instead.
    @MainActor
    static func askApple() async -> Verdict? {
        #if canImport(DeclaredAgeRange)
        if #available(iOS 26.0, *) {
            guard let vc = topViewController() else { return nil }
            do {
                switch try await AgeRangeService.shared.requestAgeRange(ageGates: 18, in: vc) {
                case .sharing(let range):
                    if let low = range.lowerBound, low >= 18 { return .adult }
                    if let high = range.upperBound, high < 18 { return .minor }
                    return nil
                case .declinedSharing:
                    return nil
                @unknown default:
                    return nil
                }
            } catch {
                NSLog("[AgeGate] Apple age range unavailable: %@", String(describing: error))
                return nil
            }
        }
        #endif
        return nil
    }

    @MainActor
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}

/// "מָה שְׁנַת הַלֵּידָה שֶׁלָּכֶם?" — the neutral question, when Apple gave no answer.
struct AgeGateYearView: View {
    let onAnswer: (AgeGate.Verdict) -> Void
    let onCancel: () -> Void
    @State private var year = AgeGate.wheelStart
    @Environment(\.horizontalSizeClass) private var hsc

    private var years: [Int] {
        let now = Calendar(identifier: .gregorian).component(.year, from: Date())
        return Array((1930...now).reversed())
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 10, size: 11)
            VStack(spacing: AppSpacing.md) {
                CharacterView(character: Character3DCatalog.find("lion"))
                    .frame(width: 104, height: 104)
                Text(tr("שְׁאֵלָה קְטַנָּה לִפְנֵי שֶׁמַּתְחִילִים"))
                    .font(.system(size: hsc == .compact ? 25 : 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(tr("מָה שְׁנַת הַלֵּידָה שֶׁלָּכֶם?"))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Picker(tr("שְׁנַת לֵידָה"), selection: $year) {
                    ForEach(years, id: \.self) { y in
                        Text(verbatim: String(y))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .tag(y)
                    }
                }
                .pickerStyle(.wheel)
                .environment(\.layoutDirection, .leftToRight)
                .frame(height: 190)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.28), lineWidth: 1))
                .padding(.top, AppSpacing.sm)
                Label(tr("הַשָּׁנָה לֹא נִשְׁמֶרֶת וְלֹא נִשְׁלַחַת לְשׁוּם מָקוֹם"), systemImage: "lock.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer(minLength: AppSpacing.md)
                Button {
                    Haptic.medium()
                    onAnswer(AgeGate.verdict(forBirthYear: year))
                } label: {
                    Text(tr("הַמְשֵׁךְ"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .glassFill(AppGradient.gold, radius: 16)
                }
                .buttonStyle(.juicy)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .padding(.top, 40)
        }
        // ✕ in the screen's own corner (away from the foldable's camera), not
        // the corner of the centred column.
        .overlay(alignment: .top) { AgeGateCloseRow(action: onCancel) }
    }
}

/// Under 18: no sign-up, no scolding — the two ways forward instead.
struct AgeGateMinorView: View {
    let onHaveCode: () -> Void
    let onClose: () -> Void
    @Environment(\.horizontalSizeClass) private var hsc

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 12, size: 11)
            VStack(spacing: AppSpacing.md) {
                CharacterView(character: Character3DCatalog.find("fox"))
                    .frame(width: 130, height: 130)
                Text(tr("נִרְאֶה שֶׁזֶּה הַמַּכְשִׁיר שֶׁל הַיֶּלֶד 😊"))
                    .font(.system(size: hsc == .compact ? 25 : 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(tr("אֶת הַמִּשְׁפָּחָה בְּטוֹפִי פּוֹתְחִים מֵהַטֶּלֶפוֹן שֶׁל אַבָּא אוֹ אִמָּא — וּמִשָּׁם מְחַבְּרִים גַּם אֶת הַמַּכְשִׁיר הַזֶּה, וּמַתְחִילִים לְשַׂחֵק וּלְהַרְוִיחַ דַּקּוֹת!"))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: AppSpacing.md)
                ShareLink(item: URL(string: "https://apps.apple.com/app/id6773805449")!) {
                    Text(tr("📨 לִשְׁלֹחַ קִשּׁוּר לְאַבָּא אוֹ לְאִמָּא"))
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "2A1E5C"))
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .glassFill(AppGradient.gold, radius: 16)
                }
                .buttonStyle(.juicy)
                Button(action: onHaveCode) {
                    Text(tr("🔑 יֵשׁ לִי קוֹד מֵהַהוֹרֶה"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.16)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.32), lineWidth: 1))
                }
                .buttonStyle(.juicy)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.md)
            .padding(.top, 40)
        }
        // ✕ in the screen's own corner (away from the foldable's camera), not
        // the corner of the centred column.
        .overlay(alignment: .top) { AgeGateCloseRow(action: onClose) }
    }
}

/// The ✕ row of the age screens: the screen's corner away from the camera.
private struct AgeGateCloseRow: View {
    let action: () -> Void
    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("סגירה"))
        }
        .awayFromBar(.trailing)
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.sm)
    }
}
