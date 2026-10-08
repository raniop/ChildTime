import SwiftUI

/// 🚀 Band ב of the approved onboarding mockup (`reports/games/onboarding-mockup.html`):
/// the ONE question that splits the whole setup, and the list that brings back a
/// parent who stopped half way.
///
/// "הבלבול הכי גדול שלנו — נפתר בשאלה אחת": does the child have a device of
/// their own? Everything after it differs — a code scan and a lock on the
/// child's phone, or the parent's own phone handed over with "תנו ל… לשחק כאן".
///
/// Parent-facing copy: no niqqud. Everything here is LOCAL to the parent's
/// device (what they answered, what they tried) — nothing is written to the
/// cloud, and a parent can always change their mind: a device that gets
/// connected later simply turns the list into the device list.
enum SetupProgress {
    enum DevicePlan: String { case own, here }

    private static func key(_ what: String, _ id: UUID) -> String { "setup.\(what).\(id.uuidString)" }

    static func plan(_ id: UUID) -> DevicePlan? {
        UserDefaults.standard.string(forKey: key("device", id)).flatMap(DevicePlan.init(rawValue:))
    }
    static func setPlan(_ plan: DevicePlan, _ id: UUID) {
        UserDefaults.standard.set(plan.rawValue, forKey: key("device", id))
    }
    static func isHidden(_ id: UUID) -> Bool { UserDefaults.standard.bool(forKey: key("hidden", id)) }
    static func hide(_ id: UUID) { UserDefaults.standard.set(true, forKey: key("hidden", id)) }
}

/// One line of the list: done (✓) or still to do (its number).
struct SetupStep: Identifiable {
    let id: String
    let title: String
    let done: Bool
}

/// "עוד קצת וסיימנו" — what is done, what is left, and one button to the next.
struct SetupChecklistCard: View {
    let steps: [SetupStep]
    let continueTitle: String
    let onContinue: () -> Void
    let onHide: () -> Void

    private var doneCount: Int { steps.filter(\.done).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(tr("🚀 עוד קצת וסיימנו"))
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(tr("\(doneCount) מתוך \(steps.count)"))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
                    .monospacedDigit()
                Button(action: onHide) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(.white.opacity(0.14)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("הסתרה"))
            }

            // Two steps per row (Rani: "1 2 / 3 4") — half the height of a list.
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10, alignment: .leading),
                                GridItem(.flexible(), spacing: 10, alignment: .leading)],
                      alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { n, step in
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(step.done ? AppColor.successMint : .white.opacity(0.16))
                                .frame(width: 24, height: 24)
                            if step.done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .black))
                                    .foregroundStyle(Color(hex: "1F2A44"))
                            } else {
                                Text("\(n + 1)")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                        }
                        Text(step.title)
                            .font(.system(size: 14, weight: step.done ? .semibold : .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(step.done ? 0.62 : 1))
                            .lineLimit(2).minimumScaleFactor(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            Button {
                Haptic.light()
                onContinue()
            } label: {
                // The same shape and height as every other button on the home
                // (Rani: a capsule here "looked different all of a sudden").
                Text(continueTitle)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "2A1E5C"))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.juicy)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPane(radius: 16, tint: AppColor.starGold)
        .environment(\.layoutDirection, .app)
    }
}

/// "לנועה יש מכשיר משלה?" — the first question after a child is added.
struct DeviceQuestionView: View {
    let child: Profile
    let onOwnDevice: () -> Void
    let onPlaysHere: () -> Void

    private var name: String { Question.stripNiqqud(child.name) }
    private var girl: Bool { child.gender == .girl }

    var body: some View {
        ZStack {
            GlassBackdrop().ignoresSafeArea()
            VStack(spacing: 18) {
                if ParentOnboarding.isActive {
                    OnboardingStepsBar(current: 3)
                        .padding(.top, 8)
                }
                Spacer(minLength: 12)
                if !ParentOnboarding.isActive {
                    Text(tr("שאלה אחת"))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                }
                Text(girl ? tr("ל\(name) יש מכשיר משלה?") : tr("ל\(name) יש מכשיר משלו?"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                // Rani: the line says what the answer DOES — which device this child plays on.
                Text(girl ? tr("זה מגדיר באיזה מכשיר \(name) משחקת") : tr("זה מגדיר באיזה מכשיר \(name) משחק"))
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                VStack(spacing: 12) {
                    option("📱",
                           title: girl ? tr("כן, יש לה טלפון או אייפד") : tr("כן, יש לו טלפון או אייפד"),
                           subtitle: tr("נחבר אותו עכשיו בסריקת קוד"),
                           action: onOwnDevice)
                    option("🧒",
                           title: girl ? tr("לא, היא תשחק בטלפון שלי") : tr("לא, הוא ישחק בטלפון שלי"),
                           subtitle: girl ? tr("\(name) תשחק כאן, במצב ילד") : tr("\(name) ישחק כאן, במצב ילד"),
                           action: onPlaysHere)
                }
                .padding(.top, 6)

                Spacer(minLength: 12)
                Text(tr("ניתן לחבר מכשיר של ילד במועד מאוחר יותר"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 520)
        }
        .environment(\.layoutDirection, .app)
    }

    private func option(_ emoji: String, title: String, subtitle: String,
                        action: @escaping () -> Void) -> some View {
        Button {
            Haptic.light()
            action()
        } label: {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 30))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassPane(radius: 16)
        }
        .buttonStyle(.juicy)
    }
}
