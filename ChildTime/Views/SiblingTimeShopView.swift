import SwiftUI

/// "זְמַן מֵאָח" — a child either BUYS play-minutes from a sibling with 💎 diamonds
/// or GIVES minutes to a sibling for free. Picks a sibling + an amount, then sends
/// the request for a parent to approve. Status of their requests shows below.
struct SiblingTimeShopView: View {
    var onClose: () -> Void

    @ObservedObject private var transfers = TimeTransferManager.shared
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var settings = ParentSettings.shared

    private enum Mode { case buy, gift }
    @State private var mode: Mode = .buy
    @State private var selectedID: UUID?
    @State private var minutes = 5
    @State private var banner: String?
    @State private var bannerGood = false
    @State private var appeared = false

    private let minuteOptions = [5, 10, 15]

    private var myID: UUID? { transfers.currentChildID }
    private var siblings: [Profile] { profiles.profiles.filter { $0.id != myID } }
    private var selected: Profile? { profiles.profiles.first { $0.id == selectedID } }
    private var cost: Int { transfers.price(forMinutes: minutes) }

    /// In buy mode, how many minutes the selected sibling has available to sell.
    private func sellerMinutes(_ id: UUID) -> Int { transfers.availableMinutes(of: id) }

    private var canAct: Bool {
        guard let sel = selected else { return false }
        if mode == .buy {
            return progress.diamonds >= cost && sellerMinutes(sel.id) >= minutes
        }
        return progress.pendingMinutes >= minutes
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "06D6A0"), Color(hex: "118AB2"), Color(hex: "5B6CFF")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            FloatingOrbs.home().opacity(0.45)
            SparkleField(count: 18, size: 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    if !transfers.incomingForSeller.isEmpty { incomingSection }
                    if siblings.isEmpty {
                        emptyState
                    } else {
                        modePicker
                        siblingPicker
                        amountPicker
                        if mode == .buy { priceCard }
                        actionButton
                    }
                    if !transfers.myTransfers.isEmpty { statusSection }
                }
                .padding(.horizontal, 20)
                .padding(.top, 78)
                .padding(.bottom, 28)
            }

            closeButton
            if let banner { bannerView(banner) }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            if selectedID == nil { selectedID = siblings.first?.id }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { appeared = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Text("זְמַן מֵאָח 🛒")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Text(mode == .buy ? "💎 \(progress.diamonds)" : "🎮 \(progress.pendingMinutes)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(mode == .buy ? "בָּאַרְנָק שֶׁלְּךָ" : "דַּקּוֹת בָּאַרְנָק")
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.18)))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🙂").font(.system(size: 54))
            Text("אֵין עֲדַיִן אַחִים בַּמִּשְׁפָּחָה")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white).multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Mode (buy / gift)

    private var modePicker: some View {
        HStack(spacing: 10) {
            modeTab("קְנֵה 💎", on: mode == .buy) { mode = .buy }
            modeTab("תֵּן בְּמַתָּנָה 🎁", on: mode == .gift) { mode = .gift }
        }
    }

    private func modeTab(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptic.light(); withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() } } label: {
            Text(title)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(on ? AppColor.textOnLight : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(on ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.14)), in: Capsule())
        }
        .buttonStyle(.juicy)
    }

    // MARK: - Sibling picker

    private var siblingPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle(mode == .buy ? "מִמִּי לִקְנוֹת?" : "לְמִי לָתֵת?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(siblings) { sib in siblingChip(sib) }
                }
                .padding(.horizontal, 2).padding(.vertical, 4)
            }
        }
    }

    private func siblingChip(_ sib: Profile) -> some View {
        let isSel = sib.id == selectedID
        // In buy mode a sibling with no minutes can't sell — show it dimmed/disabled.
        let avail = sellerMinutes(sib.id)
        let sellable = mode == .buy ? avail > 0 : true
        return Button {
            Haptic.light(); selectedID = sib.id
        } label: {
            VStack(spacing: 8) {
                CharacterView(character: Character3DCatalog.find(sib.character3DID))
                    .frame(width: 64, height: 64)
                Text(sib.name)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                if mode == .buy {
                    Text(avail > 0 ? "יֵשׁ \(avail) דַּקּוֹת" : "אֵין דַּקּוֹת")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(avail > 0 ? AppColor.successMint : .white.opacity(0.6))
                }
            }
            .frame(width: 96)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(isSel ? 0.28 : 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(isSel ? 0.9 : 0.3), lineWidth: isSel ? 2.5 : 1))
            .glow(isSel ? AppColor.starGold : .clear, radius: isSel ? 10 : 0)
            .opacity(sellable ? 1 : 0.45)
        }
        .buttonStyle(.juicy)
        .disabled(!sellable)
    }

    // MARK: - Amount

    private var amountPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("כַּמָּה דַּקּוֹת?")
            HStack(spacing: 12) {
                ForEach(minuteOptions, id: \.self) { m in
                    let isSel = m == minutes
                    Button {
                        Haptic.light(); minutes = m
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(m)").font(.system(size: 26, weight: .heavy, design: .rounded))
                            Text("דַּקּוֹת").font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(isSel ? 0.28 : 0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(isSel ? 0.9 : 0.3), lineWidth: isSel ? 2.5 : 1))
                    }
                    .buttonStyle(.juicy)
                }
            }
        }
    }

    private var priceCard: some View {
        HStack {
            Text("מְחִיר")
                .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            Spacer()
            Text("💎 \(cost)")
                .font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    private var actionButton: some View {
        let title: String
        if canAct {
            title = mode == .buy ? "שְׁלַח בַּקָּשָׁה לְאִשּׁוּר הוֹרֶה 🛒" : "שְׁלַח מַתָּנָה לְאִשּׁוּר הוֹרֶה 🎁"
        } else if mode == .buy, let sel = selected, sellerMinutes(sel.id) < minutes {
            title = "לְ\(sel.name) אֵין מַסְפִּיק דַּקּוֹת"
        } else if mode == .buy {
            title = "אֵין לְךָ מַסְפִּיק יְהָלוֹמִים 💎"
        } else {
            title = "אֵין לְךָ מַסְפִּיק דַּקּוֹת 🎮"
        }
        return Button {
            attemptAction()
        } label: {
            Text(title)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(canAct ? AppColor.textOnLight : .white.opacity(0.8))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(canAct ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.15)), in: Capsule())
        }
        .buttonStyle(.juicy)
        .disabled(!canAct)
    }

    // MARK: - Requests waiting for ME to sell

    private var incomingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("בַּקָּשׁוֹת אֵלַי 🔔")
            ForEach(transfers.incomingForSeller) { t in
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(t.toName) רוֹצֶה לִקְנוֹת מִמְּךָ \(t.minutes) דַּקּוֹת תְּמוּרַת \(t.diamondPrice) 💎")
                        .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 10) {
                        Button { transfers.sellerDecline(t); Haptic.light() } label: {
                            Text("לֹא")
                                .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(.white.opacity(0.16), in: Capsule())
                        }
                        .buttonStyle(.juicy)
                        Button { transfers.sellerApprove(t); Haptic.success() } label: {
                            Text("כֵּן, לִמְכֹּר ✅")
                                .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.textOnLight)
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(AppColor.successMint, in: Capsule())
                        }
                        .buttonStyle(.juicy)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.16)))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppColor.starGold.opacity(0.7), lineWidth: 1.5))
            }
        }
    }

    // MARK: - Status of my requests

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("הַבַּקָּשׁוֹת שֶׁלִּי")
            ForEach(transfers.myTransfers) { t in statusRow(t) }
        }
        .padding(.top, 6)
    }

    private func statusRow(_ t: TimeTransfer) -> some View {
        let mine = myID?.uuidString
        let iAmRecipient = t.toChildID == mine          // gains minutes
        let iAmInitiator = t.isGift ? (t.fromChildID == mine) : (t.toChildID == mine)
        let label: String
        if t.isGift {
            label = iAmRecipient
                ? "\(t.fromName) נוֹתֵן לְךָ \(t.minutes) דַּקּוֹת 🎁"
                : "נָתַתָּ \(t.minutes) דַּקּוֹת לְ\(t.toName) 🎁"
        } else {
            label = iAmRecipient
                ? "קָנִיתָ \(t.minutes) דַּקּוֹת מֵ\(t.fromName)"
                : "\(t.toName) קָנָה מִמְּךָ \(t.minutes) דַּקּוֹת"
        }
        return HStack(spacing: 12) {
            Text(statusEmoji(t.status)).font(.system(size: 26))
            VStack(alignment: .trailing, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(statusText(t.status, isGift: t.isGift))
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if iAmInitiator && (t.status == .pendingSeller || t.status == .pendingParent) {
                Button { transfers.cancel(t) } label: {
                    Text("בַּטֵּל").font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white).padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.2)))
                }
                .buttonStyle(.juicy)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.12)))
    }

    private func statusEmoji(_ s: TimeTransfer.Status) -> String {
        switch s {
        case .pendingSeller:    return "⏳"
        case .pendingParent:    return "⏳"
        case .approved:         return "✅"
        case .completed:        return "🎉"
        case .declinedBySeller: return "🙅"
        case .rejected:         return "🚫"
        case .canceled:         return "↩️"
        case .failed:           return "⚠️"
        }
    }

    private func statusText(_ s: TimeTransfer.Status, isGift: Bool) -> String {
        let back = isGift ? "" : " — הַיְהָלוֹמִים הוּחְזְרוּ"
        switch s {
        case .pendingSeller:    return "מְחַכֶּה שֶׁהָאָח יְאַשֵּׁר"
        case .declinedBySeller: return "הָאָח לֹא רָצָה לִמְכֹּר\(back)"
        case .pendingParent: return "מְחַכֶּה לְאִשּׁוּר הוֹרֶה"
        case .approved:      return "אֻשַּׁר — מַעֲבִיר…"
        case .completed:     return "הוּשְׁלַם!"
        case .rejected:      return "הַהוֹרֶה דָּחָה\(back)"
        case .canceled:      return "בֻּטַּל\(back)"
        case .failed:        return "לֹא הִסְתַּדֵּר\(back)"
        }
    }

    // MARK: - Bits

    private func sectionTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.2)))
                }
                Spacer()
            }
            Spacer()
        }
        .padding(20)
    }

    private func bannerView(_ text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).multilineTextAlignment(.center)
                .padding(.horizontal, 20).padding(.vertical, 14)
                .background(Capsule().fill((bannerGood ? AppColor.successMint : Color(hex: "EF476F")).opacity(0.95)))
                .padding(.bottom, 40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func attemptAction() {
        guard let sib = selected else { return }
        let err = mode == .buy
            ? transfers.requestPurchase(from: sib, minutes: minutes)
            : transfers.requestGift(to: sib, minutes: minutes)
        if let err {
            show(err, good: false)
        } else {
            SoundPlayer.shared.play(.chestOpen); Haptic.success()
            show(mode == .buy
                 ? "הַבַּקָּשָׁה נִשְׁלְחָה! מְחַכִּים לְאִשּׁוּר הַהוֹרֶה 🎉"
                 : "הַמַּתָּנָה נִשְׁלְחָה! מְחַכִּים לְאִשּׁוּר הַהוֹרֶה 🎁", good: true)
        }
    }

    private func show(_ text: String, good: Bool) {
        bannerGood = good
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { banner = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation { banner = nil }
        }
    }
}
