import SwiftUI

/// Lets a parent link a co-parent to the same household: generate a share code,
/// or redeem a code to join an existing family. Both then see — and manage —
/// the same children and their analytics.
struct FamilyLinkingView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var generatedCode: String?
    @State private var joinCode = ""
    @State private var working = false
    @State private var message: String?
    @State private var childEmail = ""

    var body: some View {
        NavigationStack {
            Form {
                linkedParentsSection
                linkChildSection
                inviteSection
                joinSection
                if let message {
                    Section { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("הורים מקושרים")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("סיום") { dismiss() } }
            }
        }
    }

    private var linkedParentsSection: some View {
        Section("המשפחה") {
            if household.linkedParentSummaries.isEmpty {
                Text("רק אתם מחוברים כרגע.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(household.linkedParentSummaries, id: \.self) { parent in
                    Label(parent, systemImage: "person.fill")
                }
            }
        }
    }

    private var linkChildSection: some View {
        Section {
            TextField("אימייל של הילד/ה", text: $childEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
            Button {
                sendLink(to: childEmail)
            } label: {
                Label("צרף ילד/ה לפי אימייל", systemImage: "person.crop.circle.badge.plus")
            }
            .disabled(working || !childEmail.contains("@"))

            // Live status of requests already sent — each can be re-sent.
            ForEach(household.sentChildLinks) { req in
                HStack {
                    Image(systemName: statusIcon(req.status))
                        .foregroundStyle(statusColor(req.status))
                    Text(req.toEmail)
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    Text(statusLabel(req.status))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(statusColor(req.status))
                    Button("שְׁלַח שׁוּב") { sendLink(to: req.toEmail) }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderless)
                        .disabled(working)
                }
            }
        } header: {
            Text("צירוף ילד/ה")
        } footer: {
            Text("אם הילד/ה נרשמו בעצמם עם אימייל — הזינו אותו כאן. תישלח בקשה שתופיע במכשיר שלהם, ואחרי אישור הפרופילים שלהם יעברו תחת המשפחה שלכם.")
        }
    }

    private func sendLink(to email: String) {
        Task {
            working = true
            let ok = await household.requestChildLink(childEmail: email)
            message = ok
                ? "נשלחה בקשה ל-\(email). ברגע שהילד/ה יאשר/תאשר במכשיר שלהם — הם יופיעו אצלך."
                : (household.lastError ?? "לא ניתן לשלוח בקשה כרגע")
            working = false
        }
    }

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "approved": return "אושר ✅"
        case "declined": return "נדחה"
        default:         return "ממתין לאישור…"
        }
    }
    private func statusIcon(_ s: String) -> String {
        switch s {
        case "approved": return "checkmark.circle.fill"
        case "declined": return "xmark.circle.fill"
        default:         return "clock.fill"
        }
    }
    private func statusColor(_ s: String) -> Color {
        switch s {
        case "approved": return AppColor.successMint
        case "declined": return .secondary
        default:         return AppColor.starGold
        }
    }

    private var inviteSection: some View {
        Section {
            if let code = generatedCode {
                HStack {
                    Text(code)
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .kerning(4)
                    Spacer()
                    ShareLink(item: "הצטרפו אליי ב-טופי! קוד המשפחה: \(code)") {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            Button {
                Task {
                    working = true
                    generatedCode = await household.createInvite()
                    message = generatedCode == nil ? "לא ניתן ליצור קוד כרגע" : "הקוד תקף ל-7 ימים"
                    working = false
                }
            } label: {
                Label(generatedCode == nil ? "צור קוד הזמנה" : "צור קוד חדש", systemImage: "qrcode")
            }
            .disabled(working)
        } header: {
            Text("הזמינו הורה נוסף")
        } footer: {
            Text("שתפו את הקוד עם ההורה השני. אחרי שהוא יזין אותו, שניכם תראו את אותם הילדים והנתונים.")
        }
    }

    private var joinSection: some View {
        Section {
            TextField("קוד משפחה (6 תווים)", text: $joinCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
            Button {
                Task {
                    working = true
                    let ok = await household.redeemInvite(code: joinCode)
                    message = ok ? "הצטרפת למשפחה! 🎉" : (household.lastError ?? "קוד לא תקין")
                    if ok { joinCode = "" }
                    working = false
                }
            } label: {
                Label("הצטרף למשפחה קיימת", systemImage: "person.badge.plus")
            }
            .disabled(working || joinCode.count < 6)
        } header: {
            Text("הצטרפות למשפחה")
        }
    }
}
