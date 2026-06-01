import SwiftUI

// MARK: - Invite (existing parent shows a code)

/// The parent who ALREADY has the family taps "add a parent" and shows this:
/// a QR + code, with clear steps for what the other parent does. Detects when
/// the second parent joins and celebrates.
struct AddParentView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var code: String?
    @State private var working = false
    @State private var error: String?
    /// How many parents were linked when we opened — so we can detect a NEW join.
    @State private var baselineParents = 0
    @State private var justJoined = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: 0) {
                LinkHeader(title: "הוֹסָפַת הוֹרֶה") { dismiss() }
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if justJoined { joinedBanner } else { content }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            baselineParents = household.linkedParentSummaries.count
            if code == nil { generate() }
        }
        .onChange(of: household.linkedParentSummaries.count) { _, now in
            if now > baselineParents { withAnimation(.spring) { justJoined = true } }
        }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 8) {
            Text("👨‍👩‍👧‍👦").font(.system(size: 52))
            Text("הוֹסִיפוּ הוֹרֶה לַמִּשְׁפָּחָה")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("שְׁנֵיכֶם תִּרְאוּ אֶת אוֹתָם יְלָדִים וְאֶת אוֹתָהּ הַהִתְקַדְּמוּת.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }

        StepsCard(title: "בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה הַשֵּׁנִי:", steps: [
            "הַתְקִינוּ אֶת אַפְּלִיקַצְיַת טוֹפִי",
            "בְּמָסַךְ הַפְּתִיחָה הַקִּישׁוּ \u{201C}כְּבָר יֵשׁ לָכֶם מִשְׁפָּחָה? הִצְטָרְפוּ\u{201D}",
            "הִתְחַבְּרוּ, וְסִרְקוּ אֶת הַקּוֹד שֶׁכָּאן (אוֹ הַקְלִידוּ אוֹתוֹ)",
        ])

        codeCard
    }

    @ViewBuilder private var codeCard: some View {
        VStack(spacing: AppSpacing.md) {
            if let code {
                QRCodeView(text: code, size: 190)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white))
                Text(code)
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .kerning(6)
                    .foregroundStyle(.white)
                ShareLink(item: "הִצְטָרְפוּ אֵלַי בְּטוֹפִי! קוֹד הַמִּשְׁפָּחָה: \(code)") {
                    Label("שִׁתּוּף הַקּוֹד", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 9)
                        .background(.white.opacity(0.18), in: Capsule())
                }
                HStack(spacing: 6) {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text("מַמְתִּין שֶׁהַהוֹרֶה יִצְטָרֵף…")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 4)
            } else if working {
                ProgressView().tint(.white)
            } else if let error {
                Text(error).font(.caption).foregroundStyle(.white.opacity(0.8))
                Button("נַסּוּ שׁוּב") { generate() }.foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
        .environment(\.layoutDirection, .leftToRight)
    }

    private var joinedBanner: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🎉").font(.system(size: 64))
            Text("הוֹרֶה נוֹסָף לַמִּשְׁפָּחָה!")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("מֵעַכְשָׁיו שְׁנֵיכֶם רוֹאִים אֶת אוֹתָם הַיְּלָדִים.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button { dismiss() } label: {
                Text("סִיּוּם")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.success, in: Capsule())
            }
            .padding(.top, 6)
        }
        .padding(.top, 40)
    }

    private func generate() {
        Task {
            working = true; error = nil
            let c = await household.createInvite()
            code = c
            if c == nil { error = household.lastError ?? "לֹא נִיתָּן לִיצֹר קוֹד כָּעֵת" }
            working = false
        }
    }
}

// MARK: - Join (new parent enters a code)

/// The NEW parent (who chose "join an existing family") sees this right after
/// sign-in: clear steps + a code entry / QR scan. On success they enter the
/// shared family; they can also choose to start their own family instead.
struct JoinFamilyFlowView: View {
    @ObservedObject private var household = HouseholdManager.shared
    @EnvironmentObject private var settings: ParentSettings

    @State private var joinCode = ""
    @State private var working = false
    @State private var error: String?
    @State private var showScanner = false
    @State private var joined = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)

            VStack(spacing: 0) {
                LinkHeader(title: "הִצְטָרְפוּת לְמִשְׁפָּחָה", showClose: false) {}
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        if joined { joinedBanner } else { content }
                    }
                    .padding(AppSpacing.lg)
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $showScanner) { scannerSheet }
    }

    @ViewBuilder private var content: some View {
        VStack(spacing: 8) {
            Text("🔗").font(.system(size: 52))
            Text("הִצְטָרְפוּ לַמִּשְׁפָּחָה הַקַּיֶּמֶת")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }

        StepsCard(title: "בַּמַּכְשִׁיר שֶׁל הַהוֹרֶה שֶׁכְּבָר רָשׁוּם:", steps: [
            "פִּתְחוּ אֶת טוֹפִי → הַגְדָּרוֹת ⚙️",
            "הַקִּישׁוּ \u{201C}הוֹסִיפוּ הוֹרֶה\u{201D}",
            "יוֹפִיעַ קוֹד / QR — סִרְקוּ אוֹתוֹ כָּאן אוֹ הַקְלִידוּ:",
        ])

        // Scan + manual entry
        VStack(spacing: AppSpacing.md) {
            Button { showScanner = true } label: {
                Label("סְרֹק קוֹד QR", systemImage: "qrcode.viewfinder")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.purpleDream, in: Capsule())
            }

            Text("אוֹ הַקְלִידוּ אֶת הַקּוֹד").font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))

            TextField("", text: $joinCode, prompt: Text("6 תָּוִים").foregroundStyle(.white.opacity(0.5)))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                .kerning(6)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.12)))
                .environment(\.layoutDirection, .leftToRight)

            Button { redeem(joinCode) } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(.white) }
                    Text("הִצְטָרֵף")
                }
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(AppGradient.gold, in: Capsule())
            }
            .disabled(working || joinCode.trimmingCharacters(in: .whitespaces).count < 6)
            .opacity(joinCode.trimmingCharacters(in: .whitespaces).count < 6 ? 0.5 : 1)

            if let error {
                Text(error).font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColor.almostWarm).multilineTextAlignment(.center)
            }
        }
        .padding(AppSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))

        Button {
            settings.pendingJoinFamily = false   // fall through to their own dashboard
        } label: {
            Text("אֵין לִי קוֹד — אֶצֹּר מִשְׁפָּחָה מִשֶּׁלִּי")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85)).underline()
        }
        .padding(.top, 4)
    }

    private var joinedBanner: some View {
        VStack(spacing: AppSpacing.md) {
            Text("🎉").font(.system(size: 64))
            Text("הִצְטָרַפְתֶּם לַמִּשְׁפָּחָה!")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("הַיְּלָדִים וְהַהִתְקַדְּמוּת יוֹפִיעוּ תּוֹךְ כַּמָּה שְׁנִיּוֹת.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
            Button { settings.pendingJoinFamily = false } label: {
                Text("הַמְשֵׁךְ")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.success, in: Capsule())
            }
            .padding(.top, 6)
        }
        .padding(.top, 40)
    }

    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView { scanned in showScanner = false; redeem(scanned) }
                .ignoresSafeArea()
                .navigationTitle("סְרִיקַת קוֹד").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("בִּטּוּל") { showScanner = false } } }
        }
    }

    private func redeem(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6 else { return }
        Task {
            working = true; error = nil
            let ok = await household.redeemInvite(code: trimmed)
            if ok { Haptic.success(); withAnimation(.spring) { joined = true } }
            else { error = household.lastError ?? "קוֹד לֹא תָּקִין"; Haptic.warning() }
            working = false
        }
    }
}

// MARK: - Shared bits

private struct LinkHeader: View {
    let title: String
    var showClose: Bool = true
    let onClose: () -> Void
    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppColor.starGold.opacity(0.6), radius: 8)
            if showClose {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(.white.opacity(0.18), in: Circle())
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.md)
    }
}

private struct StepsCard: View {
    let title: String
    let steps: [String]
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
                .frame(maxWidth: .infinity, alignment: .trailing)
            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                HStack(alignment: .top, spacing: 10) {
                    Text(step)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    ZStack {
                        Circle().fill(AppColor.starGold).frame(width: 26, height: 26)
                        Text("\(i + 1)").font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
    }
}
