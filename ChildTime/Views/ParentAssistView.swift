import SwiftUI

/// Shown mid-session when a child is clearly stuck (2 wrong picks). The child
/// picks a linked parent → an interactive push goes to that parent with the
/// question and two answer buttons; one tap from the notification removes a
/// wrong option from the child's screen. Warm, no-pressure, never shaming.
struct ParentAssistView: View {
    /// The question the child needs help with.
    let question: Question
    let topic: Topic
    let onContinue: () -> Void

    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sent = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text("🤔").font(.system(size: 72))
            Text("רוֹצֶה עֶזְרָה בַּשְּׁאֵלָה הַזּוֹ?")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if sent {
                Text("שָׁלַחְנוּ בַּקָּשַׁת עֶזְרָה 💌")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.successMint)
            } else if household.linkedParents.isEmpty {
                // No linked parent on file — fall back to a general nudge.
                assistButton("💌 בַּקֵּשׁ עֶזְרָה מֵהוֹרֶה") { askGeneral() }
            } else {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(household.linkedParents, id: \.uid) { parent in
                        assistButton("👨‍👩‍👧 בַּקֵּשׁ עֶזְרָה מ\(parent.name)") {
                            askParent(uid: parent.uid)
                        }
                    }
                }
            }

            Button {
                onContinue(); dismiss()
            } label: {
                Text("🚀 אַמְשִׁיךְ לְבַד")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.juicy)
            .padding(.top, AppSpacing.sm)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 460)
        .background(AppGradient.dreamy.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func assistButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppGradient.gold, in: Capsule())
                .glow(AppColor.starGold, radius: 8)
        }
        .buttonStyle(.juicy)
    }

    /// The correct answer + one random wrong option — the two choices the parent
    /// will see in the notification.
    private var correctAnswer: String {
        question.correctIndex < question.options.count ? question.options[question.correctIndex] : ""
    }
    private var distractor: String {
        question.options.enumerated()
            .filter { $0.offset != question.correctIndex }
            .map(\.element)
            .randomElement() ?? ""
    }

    private func askParent(uid: String) {
        Haptic.light()
        guard let childID = ProfileStore.shared.activeID?.uuidString,
              let householdID = household.household?.id else { askGeneral(); return }
        let childName = ProfileStore.shared.active?.name ?? "הילד"
        ParentHelpManager.shared.requestHelp(
            childID: childID, childName: childName, parentUID: uid,
            householdID: householdID, topic: topic,
            question: question.prompt, correctAnswer: correctAnswer, distractor: distractor)
        finish()
    }

    /// Fallback when no specific parent is linked: the legacy "a parent device
    /// gets a generic nudge" path (no interactive answer buttons).
    private func askGeneral() {
        Haptic.light()
        LiveEventReporter.report(.assistRequest)
        finish()
    }

    private func finish() {
        withAnimation { sent = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            onContinue(); dismiss()
        }
    }
}
