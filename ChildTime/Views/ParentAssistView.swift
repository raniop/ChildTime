import SwiftUI

/// Opened from the 🙋 button on the question card. The child
/// picks a parent → that parent gets a push with the question and the two
/// options (and the same request shows as a banner in the parent app); one tap
/// removes a wrong option from the child's screen. Warm, no-pressure, never
/// shaming. Glass design like the rest of the kid side.
struct ParentAssistView: View {
    /// The question the child needs help with.
    let question: Question
    let topic: Topic
    let onContinue: () -> Void

    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sent = false

    private var isGirl: Bool { ProfileStore.shared.active?.gender == .girl }

    var body: some View {
        ZStack {
            GlassBackdrop()
            SparkleField(count: 14, size: 12)

            VStack(spacing: AppSpacing.lg) {
                VStack(spacing: 10) {
                    Text("🤔").font(.system(size: 64))
                    Text(isGirl ? "רוֹצָה עֶזְרָה בַּשְּׁאֵלָה הַזּוֹ?" : "רוֹצֶה עֶזְרָה בַּשְּׁאֵלָה הַזּוֹ?")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(isGirl ? "אַבָּא אוֹ אִמָּא יוֹרִידוּ תְּשׁוּבָה אַחַת לֹא נְכוֹנָה — וְאַתְּ עוֹנָה 😉"
                                : "אַבָּא אוֹ אִמָּא יוֹרִידוּ תְּשׁוּבָה אַחַת לֹא נְכוֹנָה — וְאַתָּה עוֹנֶה 😉")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: AppSpacing.sm) {
                    if sent {
                        HStack(spacing: 8) {
                            Text("💌")
                            Text("שָׁלַחְנוּ בַּקָּשַׁת עֶזְרָה!")
                        }
                        .font(.system(size: 19, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .glassInset(radius: 18)
                    } else if household.linkedParents.isEmpty {
                        // No named parent on file — every parent device in the family
                        // gets the same interactive request.
                        assistButton(isGirl ? "👨‍👩‍👧 בַּקְּשִׁי עֶזְרָה מֵאַבָּא אוֹ אִמָּא" : "👨‍👩‍👧 בַּקֵּשׁ עֶזְרָה מֵאַבָּא אוֹ אִמָּא") { askParent(uid: "all") }
                    } else {
                        ForEach(household.linkedParents, id: \.uid) { parent in
                            assistButton((isGirl ? "👋 בַּקְּשִׁי עֶזְרָה מ" : "👋 בַּקֵּשׁ עֶזְרָה מ") + parent.name) { askParent(uid: parent.uid) }
                        }
                    }
                }

                Button {
                    Haptic.light()
                    onContinue(); dismiss()
                } label: {
                    Text("🚀 אַמְשִׁיךְ לְבַד")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassInset(radius: 18)
                }
                .buttonStyle(.juicy)
                .disabled(sent)
                .opacity(sent ? 0.5 : 1)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 460)
            .glassPane(radius: 28)
            .padding(.horizontal, AppSpacing.lg)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func assistButton(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .ctaGlass(Color(hex: "5E60CE"), Color(hex: "3E8BF0"))
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

    /// `uid` = a specific linked parent, or "all" for every parent device.
    private func askParent(uid: String) {
        Haptic.light()
        guard let childID = ProfileStore.shared.activeID?.uuidString,
              let householdID = household.household?.id else {
            // No household at all (offline first run) — the legacy generic nudge.
            LiveEventReporter.report(.assistRequest)
            finish(); return
        }
        let active = ProfileStore.shared.active
        ParentHelpManager.shared.requestHelp(
            childID: childID, childName: active?.name ?? "הילד", parentUID: uid,
            householdID: householdID, topic: topic,
            question: question.prompt, correctAnswer: correctAnswer, distractor: distractor,
            gender: active?.gender == .girl ? "girl" : "boy")
        finish()
    }

    private func finish() {
        withAnimation { sent = true }
        Haptic.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            onContinue(); dismiss()
        }
    }
}

/// 👨‍👩‍👧 PARENT side: the in-app answer sheet for a child's help request — the
/// question and the two options as big buttons. The same request also arrives
/// as a notification with buttons; this is for a parent who is already in the
/// app, or who tapped the notification body instead of a button.
struct ParentHelpAnswerView: View {
    let request: HelpRequest
    @ObservedObject private var parentHelp = ParentHelpManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sending: String? = nil
    @State private var done = false

    private var childTitle: String {
        request.isGirl ? "\(request.childName) מבקשת עזרה 🧠" : "\(request.childName) מבקש עזרה 🧠"
    }

    var body: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 18) {
                VStack(spacing: 6) {
                    Text(childTitle)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("איזו תשובה נכונה? הלחיצה שלכם מורידה את התשובה השגויה מהמסך של \(request.childName).")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(request.question)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .glassInset(radius: 20)

                if done {
                    Text("✅ נשלח! התשובה השגויה ירדה מהמסך")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .glassInset(radius: 18)
                } else {
                    VStack(spacing: 10) {
                        optionButton(request.optionA, other: request.optionB)
                        optionButton(request.optionB, other: request.optionA)
                    }
                }

                Button {
                    Haptic.light()
                    if !done { parentHelp.dismiss(requestID: request.id) }
                    dismiss()
                } label: {
                    Text(done ? "סגור" : "לא עכשיו")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: 460)
            .glassPane(radius: 28)
            .padding(.horizontal, AppSpacing.lg)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func optionButton(_ option: String, other: String) -> some View {
        Button {
            guard sending == nil else { return }
            Haptic.light()
            sending = option
            Task {
                let ok = request.parentUID == "demo"
                    ? true
                    : await parentHelp.answer(requestID: request.id, kept: option, removed: other)
                sending = nil
                if ok {
                    Haptic.success()
                    withAnimation { done = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if sending == option { ProgressView().tint(.white) }
                Text(option)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .ctaGlass(Color(hex: "5E60CE"), Color(hex: "3E8BF0"))
        }
        .buttonStyle(.juicy)
        .disabled(sending != nil)
    }
}
