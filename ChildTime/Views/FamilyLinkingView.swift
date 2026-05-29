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

    var body: some View {
        NavigationStack {
            Form {
                linkedParentsSection
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
