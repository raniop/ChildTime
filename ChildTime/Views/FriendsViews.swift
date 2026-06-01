import SwiftUI

// MARK: - Leaderboard

/// A bright, kid-friendly friends leaderboard: a top-3 podium + a ranked list,
/// each showing the friend's character, name, and star count. The child is
/// highlighted. "Add friend" opens the QR / link / code flow.
struct LeaderboardView: View {
    @ObservedObject private var friends = FriendsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false

    private var meID: String? { ProfileStore.shared.activeID?.uuidString }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(colors: [AppColor.starGold, AppColor.gemPurple, AppColor.companionGlow],
                         count: 6, maxSize: 260, opacity: 0.35)
            SparkleField(count: 22, size: 14)

            VStack(spacing: 0) {
                header
                if friends.leaderboard.count <= 1 {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.lg) {
                            podium
                            restList
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xxxl)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    }
                    .refreshable { await friends.refresh() }
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            await friends.refresh()
            if let code = friends.pendingFriendCode {
                friends.pendingFriendCode = nil
                _ = await friends.addFriend(code: code)
            }
        }
        .sheet(isPresented: $showAdd) {
            AddFriendView().environment(\.layoutDirection, .rightToLeft)
        }
    }

    private var header: some View {
        ZStack {
            Text("לוּחַ הַחֲבֵרִים")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: AppColor.starGold.opacity(0.7), radius: 8)
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(.white.opacity(0.18), in: Circle())
                }
                Spacer()
                Button { showAdd = true } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(AppColor.starGold.opacity(0.9), in: Circle())
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.md)
    }

    // Top 3 podium: #1 center & tallest.
    private var podium: some View {
        let top = Array(friends.leaderboard.prefix(3))
        let ordered: [(rank: Int, card: FriendCard)] = {
            var a: [(Int, FriendCard)] = []
            if top.count > 1 { a.append((2, top[1])) }      // left
            if top.count > 0 { a.append((1, top[0])) }      // center
            if top.count > 2 { a.append((3, top[2])) }      // right
            return a
        }()
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(ordered, id: \.card.id) { item in
                podiumColumn(rank: item.rank, card: item.card)
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private func podiumColumn(rank: Int, card: FriendCard) -> some View {
        let isMe = card.id == meID
        let size: CGFloat = rank == 1 ? 96 : 76
        let medal = rank == 1 ? "🥇" : rank == 2 ? "🥈" : "🥉"
        let podiumH: CGFloat = rank == 1 ? 96 : rank == 2 ? 70 : 54
        return VStack(spacing: 6) {
            if rank == 1 { Text("👑").font(.system(size: 26)) }
            CharacterView(character: card.character, portrait: true)
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(isMe ? AppColor.starGold : .white.opacity(0.6),
                                         lineWidth: isMe ? 3 : 2))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            Text(card.name).font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).lineLimit(1)
            starsPill(card.stars)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [AppColor.starGold, Color(hex: "FFB84D")],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: podiumH)
                Text(medal).font(.system(size: 26)).padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // Ranks 4+.
    private var restList: some View {
        let rest = Array(friends.leaderboard.enumerated()).dropFirst(3)
        return VStack(spacing: 10) {
            ForEach(Array(rest), id: \.element.id) { idx, card in
                row(rank: idx + 1, card: card)
            }
        }
    }

    private func row(rank: Int, card: FriendCard) -> some View {
        let isMe = card.id == meID
        return HStack(spacing: 12) {
            Text("\(rank)").font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.7)).frame(width: 28)
            CharacterView(character: card.character, portrait: true)
                .frame(width: 46, height: 46).clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1.5))
            Text(card.name).font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            starsPill(card.stars)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: AppRadius.large)
            .fill(isMe ? AppColor.starGold.opacity(0.22) : .white.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.large)
            .stroke(isMe ? AppColor.starGold : .clear, lineWidth: 2))
    }

    private func starsPill(_ n: Int) -> some View {
        HStack(spacing: 3) {
            Text("⭐").font(.system(size: 13))
            Text("\(n)").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(.white.opacity(0.16)))
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Text("🏆").font(.system(size: 72))
            Text("עוֹד אֵין חֲבֵרִים")
                .font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text("הוֹסִיפוּ אֶת הֶחָבֵר הָרִאשׁוֹן וְתִרְאוּ מִי אָסַף הֲכִי הַרְבֵּה כּוֹכָבִים!")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Button { showAdd = true } label: {
                Label("הוֹסִיפוּ חָבֵר", systemImage: "person.badge.plus")
                    .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl).padding(.vertical, 14)
                    .background(AppGradient.gold, in: Capsule()).glow(AppColor.starGold, radius: 12)
            }
            .padding(.top, 6)
            Spacer(); Spacer()
        }
    }
}

// MARK: - Add friend

struct AddFriendView: View {
    @ObservedObject private var friends = FriendsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showScanner = false
    @State private var typed = ""
    @State private var message: String?
    @State private var added = false

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)
            VStack(spacing: 0) {
                ZStack {
                    Text("הוֹסָפַת חָבֵר").font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    HStack { Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 36, height: 36).background(.white.opacity(0.18), in: Circle())
                        }.environment(\.layoutDirection, .leftToRight)
                    }
                }
                .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.md)

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        myCard
                        addCard
                        if let message {
                            Text(message).font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(added ? AppColor.successMint : AppColor.almostWarm)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(AppSpacing.lg).frame(maxWidth: 460).frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task { await friends.refresh() }
        .sheet(isPresented: $showScanner) { scannerSheet }
    }

    private var myCard: some View {
        VStack(spacing: AppSpacing.md) {
            Text("הַקּוֹד שֶׁלִּי").font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            if !friends.myCode.isEmpty {
                QRCodeView(text: FriendLink.url(forCode: friends.myCode), size: 170)
                    .padding(10).background(RoundedRectangle(cornerRadius: 14).fill(.white))
                Text(friends.myCode).font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .kerning(5).foregroundStyle(.white)
                if let url = friends.myInviteURL {
                    ShareLink(item: URL(string: url) ?? URL(string: "https://\(FriendLink.host)")!,
                              message: Text("בּוֹא נִהְיֶה חֲבֵרִים בְּטוֹפִי! 🌟")) {
                        Label("שַׁתְּפוּ קִישּׁוּר", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(AppColor.gemPurple, in: Capsule())
                    }
                }
            } else {
                ProgressView().tint(.white)
            }
            Text("חֲבֵרִים סוֹרְקִים אֶת הַקּוֹד אוֹ פּוֹתְחִים אֶת הַקִּישּׁוּר — וְאַתֶּם מְחֻבָּרִים!")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(AppSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
        .environment(\.layoutDirection, .leftToRight)
    }

    private var addCard: some View {
        VStack(spacing: AppSpacing.md) {
            Button { showScanner = true } label: {
                Label("סְרֹק חָבֵר", systemImage: "qrcode.viewfinder")
                    .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.purpleDream, in: Capsule())
            }
            Text("אוֹ הַקְלִידוּ קוֹד שֶׁל חָבֵר").font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            TextField("", text: $typed, prompt: Text("קוֹד").foregroundStyle(.white.opacity(0.5)))
                .textInputAutocapitalization(.characters).autocorrectionDisabled()
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .heavy, design: .monospaced)).kerning(5).foregroundStyle(.white)
                .padding(.vertical, 12).background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.12)))
                .environment(\.layoutDirection, .leftToRight)
            Button { add(typed) } label: {
                Text("הוֹסִיפוּ").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14).background(AppGradient.gold, in: Capsule())
            }
            .disabled(typed.trimmingCharacters(in: .whitespaces).count < 4)
            .opacity(typed.trimmingCharacters(in: .whitespaces).count < 4 ? 0.5 : 1)
        }
        .padding(AppSpacing.lg)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
    }

    private var scannerSheet: some View {
        NavigationStack {
            QRScannerView { scanned in showScanner = false; add(scanned) }
                .ignoresSafeArea()
                .navigationTitle("סְרִיקַת חָבֵר").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("בִּטּוּל") { showScanner = false } } }
        }
    }

    private func add(_ raw: String) {
        Task {
            let ok = await friends.addFriend(code: raw)
            added = ok
            message = ok ? "הִתְחַבַּרְתֶּם! 🎉" : (friends.lastError ?? "לֹא הִצְלַחְנוּ")
            if ok { typed = ""; Haptic.success() } else { Haptic.warning() }
        }
    }
}

// MARK: - Parent: see & remove a child's friends

/// Shown from the parent dashboard — the friends a child has, with a remove
/// action, so parents stay in control of who their kid is connected to.
struct ChildFriendsView: View {
    let childID: String
    let childName: String
    @Environment(\.dismiss) private var dismiss
    @State private var friends: [FriendCard] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if friends.isEmpty {
                    Text("עֲדַיִן אֵין חֲבֵרִים.").foregroundStyle(.secondary)
                } else {
                    ForEach(friends) { f in
                        HStack(spacing: 12) {
                            CharacterView(character: f.character, portrait: true)
                                .frame(width: 40, height: 40).clipShape(Circle())
                            Text(f.name).font(.system(size: 16, weight: .semibold, design: .rounded))
                            Spacer()
                            Text("\(f.stars) ⭐").font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("הָסֵר", role: .destructive) { remove(f) }
                        }
                    }
                }
            }
            .navigationTitle("הַחֲבֵרִים שֶׁל \(childName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("סִיּוּם") { dismiss() } } }
        }
        .task { await reload() }
    }

    private func reload() async {
        loading = true
        friends = await FriendsManager.shared.friends(ofChild: childID)
        loading = false
    }

    private func remove(_ f: FriendCard) {
        Task {
            await FriendsManager.shared.removeFriend(f.id, forChild: childID)
            await reload()
        }
    }
}
