import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// A simple "tell us what you think" form for parents, reached from a floating
/// button on the family dashboard. Writes the message to Firestore so the team
/// can read suggestions / bug reports. Degrades gracefully (shows a thank-you)
/// even when Firebase isn't linked/configured.
struct ParentFeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var sending = false
    @State private var sent = false
    @FocusState private var focused: Bool

    private var canSend: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !sending
    }

    var body: some View {
        NavigationStack {
            Group {
                if sent {
                    thankYou
                } else {
                    form
                }
            }
            .navigationTitle("פִידְבֶּק")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("סְגוֹר") { dismiss() }
                }
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                Text("נִשְׂמַח לִשְׁמוֹעַ מָה דַּעְתְּכֶם — מָה לְשַׁפֵּר, מָה חָסֵר, אוֹ כָּל רַעְיוֹן שֶׁיֵּשׁ לָכֶם. כָּל מִלָּה עוֹזֶרֶת לָנוּ לְשַׁפֵּר אֶת ChildTime לַיְּלָדִים.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("הַהוֹדָעָה שֶׁלָּכֶם") {
                TextEditor(text: $text)
                    .frame(minHeight: 140)
                    .focused($focused)
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("כִּתְבוּ כָּאן…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            }
            Section {
                Button {
                    send()
                } label: {
                    HStack {
                        Spacer()
                        if sending { ProgressView() }
                        else { Label("שְׁלַח לָנוּ", systemImage: "paperplane.fill") }
                        Spacer()
                    }
                }
                .disabled(!canSend)
            }
        }
        .onAppear { focused = true }
    }

    private var thankYou: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("🙏")
                .font(.system(size: 60))
            Text("תּוֹדָה רַבָּה!")
                .font(.title2.weight(.bold))
            Text("קִבַּלְנוּ אֶת הַפִידְבֶּק שֶׁלָּכֶם — זֶה מְאוֹד עוֹזֵר לָנוּ.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("סְגוֹר") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func send() {
        let message = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.count >= 3 else { return }
        sending = true
        Self.submit(message)
        // The write is fire-and-forget; show the thank-you right away so the
        // parent isn't blocked on the network (and it works offline too).
        Haptic.success()
        sending = false
        sent = true
    }

    /// Persist the feedback. Fire-and-forget; safe to call without Firebase.
    static func submit(_ message: String) {
        #if canImport(FirebaseFirestore)
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "?"
        var payload: [String: Any] = [
            "message": message,
            "createdAt": Date().timeIntervalSince1970,
            "appVersion": "\(appVersion) (\(build))",
            "locale": Locale.current.identifier,
        ]
        payload["fromUID"] = AuthManager.shared.userID ?? "anonymous"
        if let hh = HouseholdManager.shared.household?.id { payload["householdID"] = hh }
        Firestore.firestore().collection("parentFeedback").addDocument(data: payload)
        #endif
        AppAnalytics.log("parent_feedback_sent")
    }
}
