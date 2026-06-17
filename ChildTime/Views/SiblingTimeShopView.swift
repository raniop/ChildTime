import SwiftUI

/// "קְנִיַּת זְמַן מֵאָח" — a child buys play-minutes from a sibling with 💎 diamonds.
/// The buyer picks a sibling + an amount, sees the price, and sends the request
/// for a parent to approve. Status of their requests shows below.
struct SiblingTimeShopView: View {
    var onClose: () -> Void

    @ObservedObject private var transfers = TimeTransferManager.shared
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var profiles = ProfileStore.shared
    @ObservedObject private var settings = ParentSettings.shared

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
    private var canBuy: Bool { selected != nil && progress.diamonds >= cost }

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
                    if siblings.isEmpty {
                        emptyState
                    } else {
                        siblingPicker
                        amountPicker
                        priceCard
                        buyButton
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
            Text("קְנִיַּת זְמַן מֵאָח 🛒")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Text("💎 \(progress.diamonds)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text("בָּאַרְנָק שֶׁלְּךָ")
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.18)))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🙂").font(.system(size: 54))
            Text("אֵין עֲדַיִן אַחִים בַּמִּשְׁפָּחָה לִקְנוֹת מֵהֶם")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white).multilineTextAlignment(.center)
        }
        .padding(.top, 40)
    }

    // MARK: - Sibling picker

    private var siblingPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("מִמִּי לִקְנוֹת?")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(siblings) { sib in
                        siblingChip(sib)
                    }
                }
                .padding(.horizontal, 2).padding(.vertical, 4)
            }
        }
    }

    private func siblingChip(_ sib: Profile) -> some View {
        let isSel = sib.id == selectedID
        return Button {
            Haptic.light(); selectedID = sib.id
        } label: {
            VStack(spacing: 8) {
                CharacterView(character: Character3DCatalog.find(sib.character3DID))
                    .frame(width: 64, height: 64)
                Text(sib.name)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(width: 96)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(isSel ? 0.28 : 0.12)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(isSel ? 0.9 : 0.3), lineWidth: isSel ? 2.5 : 1))
            .glow(isSel ? AppColor.starGold : .clear, radius: isSel ? 10 : 0)
        }
        .buttonStyle(.juicy)
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

    private var buyButton: some View {
        Button {
            attemptBuy()
        } label: {
            Text(canBuy ? "שְׁלַח בַּקָּשָׁה לְאִשּׁוּר הוֹרֶה 🛒" : "אֵין מַסְפִּיק יְהָלוֹמִים 💎")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(canBuy ? AppColor.textOnLight : .white.opacity(0.8))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(canBuy ? AnyShapeStyle(AppGradient.gold) : AnyShapeStyle(Color.white.opacity(0.15)), in: Capsule())
        }
        .buttonStyle(.juicy)
        .disabled(!canBuy)
    }

    // MARK: - Status of my requests

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("הַבַּקָּשׁוֹת שֶׁלִּי")
            ForEach(transfers.myTransfers) { t in
                statusRow(t)
            }
        }
        .padding(.top, 6)
    }

    private func statusRow(_ t: TimeTransfer) -> some View {
        let iAmBuyer = t.toChildID == myID?.uuidString
        let label: String = iAmBuyer
            ? "קָנִיתָ \(t.minutes) דַּקּוֹת מֵ\(t.fromName)"
            : "\(t.toName) קָנָה מִמְּךָ \(t.minutes) דַּקּוֹת"
        return HStack(spacing: 12) {
            Text(statusEmoji(t.status)).font(.system(size: 26))
            VStack(alignment: .trailing, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(statusText(t.status))
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if iAmBuyer && t.status == .pendingParent {
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
        case .pendingParent: return "⏳"
        case .approved:      return "✅"
        case .completed:     return "🎉"
        case .rejected:      return "🚫"
        case .canceled:      return "↩️"
        case .failed:        return "⚠️"
        }
    }

    private func statusText(_ s: TimeTransfer.Status) -> String {
        switch s {
        case .pendingParent: return "מְחַכֶּה לְאִשּׁוּר הוֹרֶה"
        case .approved:      return "אֻשַּׁר — מַעֲבִיר…"
        case .completed:     return "הוּשְׁלַם!"
        case .rejected:      return "הַהוֹרֶה דָּחָה — הַיְהָלוֹמִים הוּחְזְרוּ"
        case .canceled:      return "בֻּטַּל — הַיְהָלוֹמִים הוּחְזְרוּ"
        case .failed:        return "לֹא הִסְתַּדֵּר — הַיְהָלוֹמִים הוּחְזְרוּ"
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

    private func attemptBuy() {
        guard let seller = selected else { return }
        if let err = transfers.requestPurchase(from: seller, minutes: minutes) {
            show(err, good: false)
        } else {
            SoundPlayer.shared.play(.chestOpen); Haptic.success()
            show("הַבַּקָּשָׁה נִשְׁלְחָה! מְחַכִּים לְאִשּׁוּר הַהוֹרֶה 🎉", good: true)
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
