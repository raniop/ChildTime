import SwiftUI

/// Link two devices into one family — by a 6-character code or by scanning its
/// QR. Whoever scans/enters the code joins the other's family and brings their
/// kids along, so a parent can absorb a child who registered separately, and
/// co-parents end up sharing the same children and analytics.
struct FamilyLinkingView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var generatedCode: String?
    @State private var joinCode = ""
    @State private var working = false
    @State private var message: String?
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            Form {
                linkedParentsSection
                generateSection
                joinSection
                if let message {
                    Section { Text(message).font(.caption).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("קישור משפחה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("סיום") { dismiss() } }
            }
            .sheet(isPresented: $showScanner) {
                scannerSheet
            }
        }
    }

    // MARK: - Who's linked

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

    // MARK: - Generate a code + QR

    private var generateSection: some View {
        Section {
            if let code = generatedCode {
                VStack(spacing: 12) {
                    QRCodeView(text: code, size: 200)
                        .frame(maxWidth: .infinity)
                    Text(code)
                        .font(.system(size: 30, weight: .heavy, design: .monospaced))
                        .kerning(6)
                    ShareLink(item: "הצטרפו אליי באפליקציית טופי! קוד המשפחה: \(code)") {
                        Label("שיתוף הקוד", systemImage: "square.and.arrow.up")
                    }
                }
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, .leftToRight)
            }
            Button {
                Task {
                    working = true
                    generatedCode = await household.createInvite()
                    message = generatedCode == nil
                        ? (household.lastError ?? "לא ניתן ליצור קוד כרגע")
                        : "הציגו את ה-QR או מסרו את הקוד למכשיר השני. תקף ל-7 ימים."
                    working = false
                }
            } label: {
                Label(generatedCode == nil ? "צור קוד קישור" : "צור קוד חדש", systemImage: "qrcode")
            }
            .disabled(working)
        } header: {
            Text("צרו קוד במכשיר אחד")
        } footer: {
            Text("צרו קוד כאן, ובמכשיר השני סרקו את ה-QR או הקלידו את הקוד — וכך תתקשרו לאותה משפחה (כולל הילדים).")
        }
    }

    // MARK: - Join by scanning or typing a code

    private var joinSection: some View {
        Section {
            Button {
                showScanner = true
            } label: {
                Label("סרוק קוד QR", systemImage: "qrcode.viewfinder")
            }

            TextField("…או הקלידו קוד (6 תווים)", text: $joinCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
            Button {
                redeem(joinCode)
            } label: {
                Label("הצטרף לפי קוד", systemImage: "person.badge.plus")
            }
            .disabled(working || joinCode.count < 6)
        } header: {
            Text("הצטרפות במכשיר השני")
        } footer: {
            Text("סריקה/הקלדה של הקוד מצרפת את המכשיר הזה למשפחה — והפרופילים של הילד יעברו תחת המשפחה המשותפת.")
        }
    }

    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView { scanned in
                showScanner = false
                redeem(scanned)
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                Text("כוונו את המצלמה לקוד ה-QR")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 40)
            }
            .navigationTitle("סריקת קוד")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("ביטול") { showScanner = false } }
            }
        }
    }

    // MARK: - Redeem

    private func redeem(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return }
        Task {
            working = true
            let ok = await household.redeemInvite(code: trimmed)
            message = ok ? "התחברתם למשפחה! 🎉 הילדים יופיעו תוך כמה שניות."
                         : (household.lastError ?? "קוד לא תקין")
            if ok { joinCode = "" }
            working = false
        }
    }
}
