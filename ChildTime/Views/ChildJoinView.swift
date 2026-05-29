import SwiftUI

/// Shown on a CHILD's device that hasn't joined yet: scan (or type) the code the
/// parent created for this child. On success the device joins the family and
/// lands straight on that child, ready to play.
struct ChildJoinView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @EnvironmentObject var profiles: ProfileStore
    @State private var companion = CompanionController()
    @State private var code = ""
    @State private var showScanner = false
    @State private var working = false
    @State private var message: String?

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs.home()
            SparkleField(count: 22, size: 14)

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    CompanionView(controller: companion, size: 120)
                    Text("הֵיי! בּוֹאוּ נִתְחַבֵּר")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("בַּקְּשׁוּ מֵהַהוֹרֶה אֶת הַקּוֹד שֶׁלָּכֶם, וְסִרְקוּ אוֹתוֹ כָּאן.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)

                    Button { showScanner = true } label: {
                        Label("סְרֹק קוֹד QR", systemImage: "qrcode.viewfinder")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(AppGradient.gold, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .glow(AppColor.starGold, radius: 12)
                    }
                    .buttonStyle(.juicy)

                    VStack(spacing: 8) {
                        TextField("…אוֹ הַקְלִידוּ קוֹד", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                        Button { join(code) } label: {
                            Text("הִתְחַבְּרוּ")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .disabled(working || code.count < 6)
                        .opacity(code.count < 6 ? 0.5 : 1)
                    }

                    if let message {
                        Text(message)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.vertical, AppSpacing.xl)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showScanner) {
            NavigationStack {
                QRScannerView { scanned in
                    showScanner = false
                    join(scanned)
                }
                .ignoresSafeArea()
                .navigationTitle("סריקת קוד")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("ביטול") { showScanner = false } } }
            }
        }
    }

    /// Payload is "CODE|childID". Redeem the code (join the family), then land on
    /// that specific child.
    private func join(_ raw: String) {
        let payload = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = payload.split(separator: "|", maxSplits: 1).map(String.init)
        guard let codePart = parts.first, codePart.count >= 6 else { return }
        let childID = parts.count > 1 ? UUID(uuidString: parts[1]) : nil
        Task {
            working = true
            message = "מִתְחַבְּרִים…"
            let ok = await household.redeemInvite(code: codePart)
            if ok, let cid = childID { profiles.setActiveID(cid) }
            message = ok ? "הִתְחַבַּרְתֶּם! 🎉" : (household.lastError ?? "קוֹד לֹא תָּקִין")
            working = false
        }
    }
}

#Preview {
    ChildJoinView()
        .environmentObject(ProfileStore.shared)
        .environment(\.layoutDirection, .rightToLeft)
}
