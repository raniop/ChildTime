import SwiftUI
import StoreKit

/// ⚽ A question pack's page on the PARENT's device: what the child learns, for
/// whom, and the one button that buys it (behind the parent gate) and sends it
/// to the chosen children. Approved mockup: notifications-and-packs.html.
struct PackDetailView: View {
    let pack: QuestionPack
    var preselected: UUID? = nil
    var onClose: () -> Void

    @EnvironmentObject private var profiles: ProfileStore
    @ObservedObject private var store = PackStore.shared
    @State private var selected: Set<String> = []
    @State private var gateOpen = false
    @State private var granted: [String] = []      // names just sent to, for the success state
    @State private var purchaseFailed: String?
    /// 🌍 Pass page: the second door — Tofy+ for the whole family (gated paywall).
    @State private var showTofyPlus = false
    /// Pass page: which door is chosen. Tofy+ hides the child picker (Rani) —
    /// the subscription is for the whole family.
    @State private var choosingTofyPlus = false
    @ObservedObject private var subs = SubscriptionManager.shared

    private var kids: [Profile] { profiles.profiles }
    private var selectedIDs: [String] { kids.filter { selected.contains($0.id.uuidString) }.map { $0.id.uuidString } }
    private var priceLabel: String? { store.priceLabel(for: pack, childIDs: selectedIDs) }

    var body: some View {
        ZStack {
            GlassBackdrop()
            ScrollView {
                VStack(spacing: 12) {
                    header
                    if subs.isPremium && !pack.isPass { includedInTofyPlus }
                    else if granted.isEmpty { chooser } else { success }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .foregroundStyle(GlassInk.primary)
        .onAppear {
            CampaignTracker.shared.record("page")
            if let preselected { selected = [preselected.uuidString] }
            else if let first = kids.first(where: { !$0.owns(pack) }) { selected = [first.id.uuidString] }
        }
        .fullScreenCover(isPresented: $gateOpen) {
            ParentGateView(allowClose: true, gateTitle: "אֵזוֹר הוֹרִים",
                           gateReason: "כְּדֵי לִרְכֹּשׁ אֶת הַשְּׁאֵלוֹן — הַזִּינוּ אֶת הַקּוֹד",
                           useFaceID: true, respectSession: false) {
                purchasing
            }
        }
        .fullScreenCover(isPresented: $showTofyPlus) {
            ParentGateView(allowClose: true, gateTitle: "אֵזוֹר הוֹרִים",
                           gateReason: "כְּדֵי לִפְתּוֹחַ אֶת הַמִּנּוּי לַמִּשְׁפָּחָה — הַזִּינוּ אֶת הַקּוֹד",
                           useFaceID: true, respectSession: false) {
                PaywallView().environmentObject(subs).environment(\.layoutDirection, .rightToLeft)
            }
        }
        .alert("הָרְכִישָׁה לֹא הֻשְׁלְמָה", isPresented: Binding(get: { purchaseFailed != nil }, set: { if !$0 { purchaseFailed = nil } })) {
            Button("סָגוּר", role: .cancel) {}
        } message: { Text(purchaseFailed ?? "") }
    }

    // MARK: pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { Haptic.light(); onClose() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(pack.isPass ? "עוֹלָם בְּסִיסִי · כָּלוּל בְּטוֹפִי+" : "כָּלוּל בְּטוֹפִי+ · אוֹ רְכִישָׁה חַד־פַּעֲמִית")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
            Text(pack.emoji)
                .font(.system(size: 64))
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(pack.heroGradient.opacity(0.45)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.3), lineWidth: 1))
            Text(pack.name)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
            Text(pack.tagline)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
            Text("מָה הַיֶּלֶד יִלְמַד")
                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                .padding(.top, 6)
            Text(pack.description)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(pack.learns, id: \.self) { line in
                    HStack(alignment: .top, spacing: 8) {
                        Text("✓").font(.system(size: 13, weight: .heavy)).foregroundStyle(GlassInk.good)
                        Text(line).font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    }
                }
            }
            .padding(.top, 2)
            HStack(spacing: 6) {
                chip("מֻמְלָץ \(pack.gradesLabel)")
                chip(pack.questionsLabel)
                chip(pack.isPass ? "\(pack.durationLabel) · בְּלִי חִדּוּשׁ" : "עִדְכּוּנִים חִנָּם")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassPane(radius: 22)
    }

    private func chip(_ t: String) -> some View {
        Text(t)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Capsule().fill(.white.opacity(0.10)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .lineLimit(1).minimumScaleFactor(0.8)
    }

    /// A Tofy+ family: nothing to buy — it's already open for every child.
    private var includedInTofyPlus: some View {
        VStack(spacing: 8) {
            Text("👑").font(.system(size: 40))
            Text("כָּלוּל בְּטוֹפִי+ — כְּבָר פָּתוּחַ לְכָל הַיְלָדִים")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text("הָעוֹלָם מְחַכֶּה בַּמָּסָךְ הָרָאשִׁי שֶׁל כָּל יֶלֶד, עִם סִימוּן \"חָדָשׁ\".")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
            Button { Haptic.light(); onClose() } label: {
                Text("מְעוּלֶה")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "4B3FBF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.92)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassPane(radius: 22)
    }

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 8) {
            if pack.isPass {
                // 🌍 Two doors: this world for 30 days, or Tofy+ for everything.
                Text("אֵיךְ לִפְתֹּחַ?")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                // Like the approved mockup: one option above the other, each with
                // its price and a line that says exactly what it buys.
                VStack(spacing: 8) {
                    optionRow(title: "רַק הָעוֹלָם הַזֶּה" + (selectedIDs.count == 1 && !choosingTofyPlus ? ", לְ\(kids.first { selected.contains($0.id.uuidString) }?.name ?? "")" : ""),
                              price: priceLabel ?? pack.plannedPriceLabel,
                              line: "\(pack.durationLabel) · לְיֶלֶד אֶחָד · בְּלִי מִנּוּי · בְּלִי חִדּוּשׁ אוֹטוֹמָטִי",
                              selected: !choosingTofyPlus, gold: false) { Haptic.light(); withAnimation(.easeInOut(duration: 0.2)) { choosingTofyPlus = false } }
                    optionRow(title: "👑 טוֹפִי+ לְכָל הַמִּשְׁפָּחָה",
                              price: tofyPlusPrice,
                              line: "כָּל \(WorldPasses.all.count) הָעוֹלָמוֹת, מִשְׂחָקִים, זִירָה וּמַטְלוֹת · לְכָל הַיְלָדִים" + (subs.yearlyIntroEligible ? " · 7 יָמִים חִנָּם" : ""),
                              selected: choosingTofyPlus, gold: true) { Haptic.light(); withAnimation(.easeInOut(duration: 0.2)) { choosingTofyPlus = true } }
                }
                .foregroundStyle(GlassInk.primary)
                .padding(.bottom, 4)
            }
            if choosingTofyPlus {
                // The family door: no child to pick — one subscription for everyone.
                Button { Haptic.light(); showTofyPlus = true } label: {
                    Text(subs.yearlyIntroEligible ? "הַתְחִילוּ 7 יָמִים חִנָּם" : "לְכָל הַפְּרָטִים שֶׁל טוֹפִי+")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: "4B3FBF"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.92)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                Text("מֵאֲחוֹרֵי קוֹד הוֹרֶה · Apple ID · נִפְתָּח לְכָל הַיְלָדִים בְּכָל הַמַּכְשִׁירִים")
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(GlassInk.tertiary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            } else {
            Text(pack.isPass ? "לְמִי?" : "לְמִי לִשְׁלֹחַ?")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            ForEach(kids) { kid in
                // A pass can be renewed — the child stays selectable.
                let owns = kid.owns(pack) && !pack.isPass
                let daysLeft = kid.passDaysLeft(pack)
                Button {
                    guard !owns else { return }
                    Haptic.light()
                    if selected.contains(kid.id.uuidString) { selected.remove(kid.id.uuidString) } else { selected.insert(kid.id.uuidString) }
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selected.contains(kid.id.uuidString) || owns ? Color.white : .clear)
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
                                .frame(width: 22, height: 22)
                            if selected.contains(kid.id.uuidString) || owns {
                                Text("✓").font(.system(size: 13, weight: .heavy)).foregroundStyle(Color(hex: "4B3FBF"))
                            }
                        }
                        ProfileAvatarView(profile: kid, size: 30)
                        Text(kid.name).font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        Text(Profile.gradeDisplayName(kid.effectiveGrade)).font(.system(size: 12.5, weight: .semibold, design: .rounded)).foregroundStyle(GlassInk.secondary)
                        Spacer()
                        if owns {
                            Text("כְּבָר יֵשׁ ✓").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(GlassInk.good)
                        } else if let daysLeft, kid.owns(pack) {
                            Text("עוֹד \(daysLeft) יוֹם · חִדּוּשׁ").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(GlassInk.good)
                        } else if kid.passExpired(pack) {
                            Text("נִגְמַר · לְהַמְשִׁיךְ").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(GlassInk.warn)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .glassInset(radius: 12)
                    .opacity(owns ? 0.75 : 1)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text(pack.isPass
                     ? (selectedIDs.count > 1 ? "לְ־\(selectedIDs.count) יְלָדִים · \(pack.durationLabel)" : "לְיֶלֶד אֶחָד · \(pack.durationLabel)")
                     : (selectedIDs.count > 1 ? "לְ־\(selectedIDs.count) יְלָדִים · פַּעַם אַחַת" : "לְיֶלֶד אֶחָד · פַּעַם אַחַת"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                Spacer()
                Text(priceLabel ?? (store.didAttemptLoad ? "—" : "…"))
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.top, 6)
            if !pack.isPass, HouseholdManager.shared.householdOwnsPack(pack.id), !selectedIDs.isEmpty {
                Text("הַמִּשְׁפָּחָה כְּבָר רָכְשָׁה — יֶלֶד נוֹסָף בַּחֲצִי מְחִיר")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.good)
            }
            Button {
                Haptic.light()
                CampaignTracker.shared.record("purchaseStarted")
                gateOpen = true
            } label: {
                Text(ctaTitle)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "4B3FBF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.92)))
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty || priceLabel == nil)
            .opacity(selectedIDs.isEmpty || priceLabel == nil ? 0.5 : 1)
            .padding(.top, 4)
            Text(pack.isPass ? "מֵאֲחוֹרֵי קוֹד הוֹרֶה · Apple ID · הָעוֹלָם נִפְתָּח לַיֶּלֶד מִיָּד · בְּלִי חִדּוּשׁ אוֹטוֹמָטִי" : "מֵאֲחוֹרֵי קוֹד הוֹרֶה · Apple ID · הַשְּׁאֵלוֹן נִכְנָס לַיֶּלֶד מִיָּד")
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(GlassInk.tertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassPane(radius: 22, strength: 0.09)
    }

    /// "₪24.90 / חודש" from StoreKit (planned price in the DEBUG demo).
    /// One currency on the page: both from StoreKit (the user's storefront), or —
    /// in the DEBUG demo without products — both planned in ₪. Never mixed.
    private var tofyPlusPrice: String {
        if store.allLoaded, let m = subs.products.first(where: { $0.id == SubscriptionManager.monthlyID }) { return m.pricePerPeriod }
        #if DEBUG
        return "₪24.90 / חוֹדֶשׁ"
        #else
        return subs.products.first(where: { $0.id == SubscriptionManager.monthlyID })?.pricePerPeriod ?? ""
        #endif
    }

    private func optionRow(title: String, price: String, line: String, selected: Bool, gold: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 14.5, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 6)
                    Text(price).font(.system(size: 15, weight: .heavy, design: .rounded)).monospacedDigit()
                }
                Text(line).font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(gold ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFE082").opacity(0.45), Color(hex: "FFB840").opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                           : AnyShapeStyle(Color.white.opacity(selected ? 0.16 : 0.08))))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(selected ? Color.white.opacity(0.9) : (gold ? Color(hex: "FFEBAA").opacity(0.7) : Color.white.opacity(0.2)), lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)   // stays enabled — a disabled plain button dims the chosen door
    }

    private var ctaTitle: String {
        let names = kids.filter { selected.contains($0.id.uuidString) }.map(\.name)
        switch names.count {
        case 0:  return "בַּחֲרוּ יֶלֶד"
        case 1:  return pack.isPass ? "פִּתְחוּ \(pack.durationLabel) לְ\(names[0])" : "רִכְשׁוּ וְשִׁלְחוּ לְ\(names[0])"
        default: return pack.isPass ? "פִּתְחוּ \(pack.durationLabel) לְ־\(names.count) יְלָדִים" : "רִכְשׁוּ וְשִׁלְחוּ לְ־\(names.count) יְלָדִים"
        }
    }

    /// Inside the gate: runs the StoreKit purchase right away, shows progress.
    private var purchasing: some View {
        ZStack {
            GlassBackdrop()
            VStack(spacing: 14) {
                Text(pack.emoji).font(.system(size: 54))
                Text(store.isPurchasing ? "מְאַשְּׁרִים מוּל Apple…" : "פּוֹתְחִים אֶת הָרְכִישָׁה…")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                ProgressView().tint(.white)
            }
            .foregroundStyle(GlassInk.primary)
        }
        .task {
            let ids = selectedIDs
            let ok = await store.purchase(pack, for: ids)
            if ok {
                granted = kids.filter { ids.contains($0.id.uuidString) }.map(\.name)
                Haptic.success()
            } else {
                purchaseFailed = store.lastError ?? "בִּטַּלְתֶּם אֶת הָרְכִישָׁה."
            }
            gateOpen = false
        }
    }

    private var success: some View {
        VStack(spacing: 10) {
            Text("🎉").font(.system(size: 44))
            Text(pack.isPass ? "✓ \(pack.name) פָּתוּחַ לְ\(ListFormatter.localizedString(byJoining: granted)) לְ־\(pack.durationLabel)" : "✓ נִשְׁלַח לְ\(ListFormatter.localizedString(byJoining: granted))")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.center)
            Text("\(pack.name) כְּבָר מְחַכֶּה בַּמָּסָךְ הָרָאשִׁי שֶׁל הַיֶּלֶד, עִם סִימוּן \"חָדָשׁ\". בַּפְּתִיחָה הַבָּאָה הוּא יְקַבֵּל הַפְתָּעָה קְטַנָּה 🎁")
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(GlassInk.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button { Haptic.light(); onClose() } label: {
                Text("סִיַּמְנוּ")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: "4B3FBF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.92)))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassPane(radius: 22)
    }
}

/// "✨ שאלונים חדשים לילדים" — the permanent shelf on the parent home. One card
/// per live pack: send it, or the status of the child who has it.
struct PacksHomeSection: View {
    @EnvironmentObject private var profiles: ProfileStore
    @ObservedObject private var store = PackStore.shared
    let onOpen: (QuestionPack) -> Void

    @ObservedObject private var subs = SubscriptionManager.shared
    @State private var worldsExpanded = false

    var body: some View {
        let packs = store.visiblePacks
        VStack(alignment: .leading, spacing: 8) {
            // 🌍 Without Tofy+: every base world, 30 days per child. (A family
            // with Tofy+ already has them all — the shelf disappears.)
            if !subs.isPremium {
                Text("🌍 הָעוֹלָמוֹת שֶׁל טוֹפִי · כְּלוּלִים בְּטוֹפִי+ · אוֹ 30 יוֹם לְיֶלֶד")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .padding(.horizontal, 4)
                    .lineLimit(1).minimumScaleFactor(0.8)
                let shown = worldsExpanded ? WorldPasses.all : Array(WorldPasses.all.prefix(3))
                ForEach(shown) { pass in
                    Button { Haptic.light(); onOpen(pass) } label: { card(pass) }
                        .buttonStyle(.plain)
                }
                if WorldPasses.all.count > 3 {
                    Button { Haptic.light(); withAnimation(.easeInOut(duration: 0.25)) { worldsExpanded.toggle() } } label: {
                        Text(worldsExpanded ? "פָּחוֹת ▴" : "+ עוֹד \(WorldPasses.all.count - 3) עוֹלָמוֹת ▾")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(GlassInk.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !packs.isEmpty {
                Text("✨ שְׁאֵלוֹנִים חֲדָשִׁים לַיְלָדִים")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(GlassInk.secondary)
                    .padding(.horizontal, 4)
                    .padding(.top, subs.isPremium ? 0 : 6)
                ForEach(packs) { pack in
                    Button { Haptic.light(); onOpen(pack) } label: { card(pack) }
                        .buttonStyle(.plain)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func card(_ pack: QuestionPack) -> some View {
        let owners = profiles.profiles.filter { PackAccess.has($0, pack) }
        return HStack(spacing: 12) {
            Text(pack.emoji)
                .font(.system(size: 30))
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(pack.heroGradient.opacity(0.45)))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(pack.name).font(.system(size: 15, weight: .heavy, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if !pack.isPass {
                        Text("חָדָשׁ")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "3B2E05"))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Color(hex: "FFD23F")))
                    }
                }
                if owners.isEmpty {
                    Text(pack.tagline)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GlassInk.secondary)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
                // After a purchase the status takes the tagline's place (two lines).
                Text(statusLine(pack, owners: owners))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(owners.isEmpty ? GlassInk.secondary : GlassInk.good)
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Text(pack.isPass ? (owners.isEmpty ? "30 יוֹם" : "חַדְּשׁוּ") : (subs.isPremium ? "✓ פָּתוּחַ" : (owners.count == profiles.profiles.count && !owners.isEmpty ? "✓" : "שִׁלְחוּ לַיֶּלֶד")))
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "4B3FBF"))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(.white.opacity(0.92)))
        }
        .foregroundStyle(GlassInk.primary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPane(radius: 18, shadow: false)
    }

    /// "כִּתּוֹת ב׳–ו׳ · ₪14.90" before a purchase; after it, what the child did:
    /// "✓ נשלח ליואב · התחיל · 18 שאלות · 83%".
    private func statusLine(_ pack: QuestionPack, owners: [Profile]) -> String {
        if owners.isEmpty {
            let price = store.displayPrice(for: pack)
            if pack.isPass {
                let expiredFor = profiles.profiles.filter { $0.passExpired(pack) }.map(\.name)
                if !expiredFor.isEmpty { return "נִגְמַר לְ\(ListFormatter.localizedString(byJoining: expiredFor)) · לְהַמְשִׁיךְ: \(price ?? "")" }
                return [price.map { "\($0) · 30 יוֹם לְיֶלֶד" }].compactMap { $0 }.joined()
            }
            return [pack.gradesLabel, price].compactMap { $0 }.joined(separator: " · ")
        }
        let first = owners[0]
        if subs.isPremium, !pack.isPass {
            let days = LearningHistoryStore.shared.history(for: first.id)
            let answered = days.reduce(0) { $0 + ($1.perTopic[pack.topic.rawValue]?.answered ?? 0) }
            return answered > 0 ? "כָּלוּל בְּטוֹפִי+ · \(first.name) \(first.gender == .girl ? "הִתְחִילָה" : "הִתְחִיל") · \(answered) שְׁאֵלוֹת" : "כָּלוּל בְּטוֹפִי+ · פָּתוּחַ לְכָל הַיְלָדִים"
        }
        if pack.isPass {
            let parts = owners.map { o in "\(o.name)\(o.passDaysLeft(pack).map { " · עוֹד \($0) יוֹם" } ?? "")" }
            return "✓ פָּתוּחַ לְ\(parts.joined(separator: ", "))"
        }
        let days = LearningHistoryStore.shared.history(for: first.id)
        let answered = days.reduce(0) { $0 + ($1.perTopic[pack.topic.rawValue]?.answered ?? 0) }
        let correct = days.reduce(0) { $0 + ($1.perTopic[pack.topic.rawValue]?.correct ?? 0) }
        var line = "✓ נִשְׁלַח לְ\(ListFormatter.localizedString(byJoining: owners.map(\.name)))"
        if answered > 0 {
            let pct = Int((Double(correct) / Double(answered) * 100).rounded())
            line += "\n\(first.gender == .girl ? "הִתְחִילָה" : "הִתְחִיל") · \(answered) שְׁאֵלוֹת · \(pct)%"
        }
        return line
    }
}
