import SwiftUI

// MARK: - Leaderboard

/// A bright, kid-friendly friends leaderboard: a top-3 podium + a ranked list,
/// each showing the friend's character, name, and star count. The child is
/// highlighted. "Add friend" opens the QR / link / code flow.
struct LeaderboardView: View {
    @ObservedObject private var friends = FriendsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showAdd = false
    @State private var friendToRemove: FriendCard?
    @State private var selectedCard: FriendCard?
    @State private var showRequests = false
    @State private var tab: Board = .friends

    /// Which leaderboard the child is looking at.
    private enum Board { case friends, global }

    private var meID: String? { ProfileStore.shared.activeID?.uuidString }

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            FloatingOrbs(colors: [AppColor.starGold, AppColor.gemPurple, AppColor.companionGlow],
                         count: 6, maxSize: 260, opacity: 0.35)
            SparkleField(count: 22, size: 14)

            VStack(spacing: 0) {
                header
                tabPicker
                switch tab {
                case .friends: friendsContent
                case .global:  globalContent
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task {
            await friends.startLive()   // real-time: new friends + live stars
            if let code = friends.pendingFriendCode {
                friends.pendingFriendCode = nil
                _ = await friends.addFriend(code: code)
            }
        }
        .onDisappear { friends.stopLive() }
        .sheet(isPresented: $showAdd) {
            AddFriendView().environment(\.layoutDirection, .rightToLeft)
        }
        .sheet(item: $selectedCard) { card in
            FriendProfileView(card: card).environment(\.layoutDirection, .rightToLeft)
        }
        .sheet(isPresented: $showRequests) {
            FriendRequestsView().environment(\.layoutDirection, .rightToLeft)
        }
        .confirmationDialog("לְהָסִיר חָבֵר?",
                            isPresented: Binding(get: { friendToRemove != nil },
                                                 set: { if !$0 { friendToRemove = nil } }),
                            titleVisibility: .visible,
                            presenting: friendToRemove) { f in
            Button("הָסִירוּ אֶת \(f.name)", role: .destructive) {
                Task { await friends.removeFriend(f.id); friendToRemove = nil }
            }
            Button("בִּטּוּל", role: .cancel) { friendToRemove = nil }
        } message: { f in
            Text("\(f.name) יֵצֵא מִלּוּחַ הַחֲבֵרִים שֶׁלְּךָ. תָּמִיד אֶפְשָׁר לְהוֹסִיף שׁוּב.")
        }
    }

    /// Long-press remove — only for friends, never your own card.
    @ViewBuilder private func removeMenu(for card: FriendCard, isMe: Bool) -> some View {
        if !isMe {
            Button(role: .destructive) { friendToRemove = card } label: {
                Label("הָסִירוּ חָבֵר", systemImage: "person.badge.minus")
            }
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
                Button {
                    // Start a live game with friends — hand off to the home screen,
                    // which presents the setup + game over the world map.
                    LiveGameManager.shared.wantsNewGame = true
                    dismiss()
                } label: {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(AppColor.gemPurple.opacity(0.9), in: Circle())
                }
                Button { showRequests = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 38, height: 38).background(.white.opacity(0.18), in: Circle())
                        if !friends.incomingRequests.isEmpty {
                            Text("\(friends.incomingRequests.count)")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Circle().fill(AppColor.almostWarm))
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                .offset(x: 4, y: -4)
                        }
                    }
                }
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

    // Two tabs: my friends vs. everyone in the app.
    private var tabPicker: some View {
        HStack(spacing: 6) {
            tabButton("הַחֲבֵרִים שֶׁלִּי", .friends)
            tabButton("כָּל הַשַּׂחְקָנִים", .global)
        }
        .padding(4)
        .background(Capsule().fill(.white.opacity(0.12)))
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, AppSpacing.sm)
    }

    private func tabButton(_ title: String, _ value: Board) -> some View {
        let active = tab == value
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { tab = value }
            if value == .global { Task { await friends.loadGlobal() } }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .background(Capsule().fill(active ? AppColor.starGold.opacity(0.9) : .clear))
        }
    }

    // MARK: Friends tab

    @ViewBuilder private var friendsContent: some View {
        if friends.leaderboard.count <= 1 {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    podium(friends.leaderboard, removable: true)
                    restList(friends.leaderboard, removable: true)
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .refreshable { await friends.refresh() }
        }
    }

    // MARK: Global tab

    @ViewBuilder private var globalContent: some View {
        if friends.globalBoard.isEmpty {
            VStack { Spacer(); ProgressView().tint(.white); Spacer(); Spacer() }
        } else {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    myRankBanner
                    podium(friends.globalBoard, removable: false)
                    restList(friends.globalBoard, removable: false)
                    myGlobalFooter
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xxxl)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            .refreshable { await friends.loadGlobal() }
        }
    }

    /// My place among ALL players — always positive, never failure language.
    @ViewBuilder private var myRankBanner: some View {
        if let rank = friends.myGlobalRank {
            VStack(spacing: 2) {
                Text("הַמָּקוֹם שֶׁלְּךָ בְּכָל הָעוֹלָם")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                Text("#\(rank.formatted())")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("כָּל כּוֹכָב מְקַדֵּם אוֹתְךָ לְמַעְלָה! ⭐")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
            }
            .frame(maxWidth: .infinity).padding(AppSpacing.md)
            .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(AppColor.starGold.opacity(0.18)))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.large).stroke(AppColor.starGold.opacity(0.5), lineWidth: 1.5))
            .padding(.top, AppSpacing.sm)
        }
    }

    /// If I'm outside the top 100, show my own highlighted row at the bottom with
    /// my real rank — so I always see myself on the board.
    @ViewBuilder private var myGlobalFooter: some View {
        if let rank = friends.myGlobalRank, let meID,
           !friends.globalBoard.contains(where: { $0.id == meID }) {
            let me = FriendCard(id: meID,
                                name: ProfileStore.shared.active?.name ?? "אֲנִי",
                                character3DID: ProfileStore.shared.active?.character3DID,
                                stars: ProgressStore.shared.stars,
                                code: friends.myCode)
            VStack(spacing: 8) {
                Text("• • •").font(.system(size: 20, weight: .heavy)).foregroundStyle(.white.opacity(0.45))
                row(rank: rank, card: me, removable: false)
            }
        }
    }

    // Top 3 podium: #1 center & tallest.
    private func podium(_ board: [FriendCard], removable: Bool) -> some View {
        let top = Array(board.prefix(3))
        let ordered: [(rank: Int, card: FriendCard)] = {
            var a: [(Int, FriendCard)] = []
            if top.count > 1 { a.append((2, top[1])) }      // left
            if top.count > 0 { a.append((1, top[0])) }      // center
            if top.count > 2 { a.append((3, top[2])) }      // right
            return a
        }()
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(ordered, id: \.card.id) { item in
                podiumColumn(rank: item.rank, card: item.card, removable: removable)
            }
        }
        .padding(.top, AppSpacing.sm)
    }

    private func podiumColumn(rank: Int, card: FriendCard, removable: Bool) -> some View {
        let isMe = card.id == meID
        let size: CGFloat = rank == 1 ? 96 : 76
        let medal = rank == 1 ? "🥇" : rank == 2 ? "🥈" : "🥉"
        let podiumH: CGFloat = rank == 1 ? 96 : rank == 2 ? 70 : 54
        return VStack(spacing: 6) {
            if rank == 1 { Text("👑").font(.system(size: 26)) }
            CharacterView(character: card.character, portrait: true)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .glow(isMe ? AppColor.starGold : .clear, radius: isMe ? 14 : 0)
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
        .contentShape(Rectangle())
        .onTapGesture { Haptic.light(); selectedCard = card }
        .contextMenu { if removable { removeMenu(for: card, isMe: isMe) } }
    }

    // Ranks 4+.
    private func restList(_ board: [FriendCard], removable: Bool) -> some View {
        let rest = Array(board.enumerated()).dropFirst(3)
        return VStack(spacing: 10) {
            ForEach(Array(rest), id: \.element.id) { idx, card in
                row(rank: idx + 1, card: card, removable: removable)
            }
        }
    }

    private func row(rank: Int, card: FriendCard, removable: Bool) -> some View {
        let isMe = card.id == meID
        return HStack(spacing: 12) {
            Text("\(rank)").font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.7)).frame(width: 28)
            CharacterView(character: card.character, portrait: true)
                .frame(width: 46, height: 46)
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
        .contentShape(Rectangle())
        .onTapGesture { Haptic.light(); selectedCard = card }
        .contextMenu { if removable { removeMenu(for: card, isMe: isMe) } }
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
    @State private var celebrate: FriendCard?
    @State private var confettiTrigger = 0
    /// Friend IDs known when the sheet opened — so a NEW one arriving (someone
    /// scanned MY code) is detected and the sheet auto-closes, just like the
    /// scanning side does.
    @State private var knownFriendIDs: Set<String> = []

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

            // 🎉 New-friend celebration.
            if let f = celebrate {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: AppSpacing.md) {
                    Text("🎉").font(.system(size: 56))
                    CharacterView(character: f.character)
                        .frame(width: 130, height: 130)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    Text(f.name)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    Text("אַתֶּם חֲבֵרִים עַכְשָׁיו! 🤝")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.starGold)
                }
                .transition(.scale.combined(with: .opacity))
            }
            Confetti(trigger: confettiTrigger)
                .allowsHitTesting(false)
        }
        .environment(\.layoutDirection, .rightToLeft)
        // Live so the inbound listener fires the instant someone scans MY code.
        .task { await friends.startLive() }
        .onAppear { knownFriendIDs = Set(friends.leaderboard.map(\.id)) }
        .onChangeCompat(of: friends.leaderboard.map(\.id)) { _, ids in
            // A new friend appeared while this sheet is open (someone connected to
            // me) → celebrate and auto-close, like the scanning side already does.
            let fresh = Set(ids).subtracting(knownFriendIDs)
            knownFriendIDs = Set(ids)
            guard celebrate == nil, let newID = fresh.first,
                  newID != ProfileStore.shared.activeID?.uuidString,
                  let card = friends.leaderboard.first(where: { $0.id == newID }) else { return }
            added = true
            message = "הִתְחַבַּרְתֶּם! 🎉"
            Haptic.success(); SoundPlayer.shared.play(.chestOpen)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { celebrate = card }
            confettiTrigger += 1
            Task { try? await Task.sleep(nanoseconds: 2_000_000_000); dismiss() }
        }
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
            Text("חֲבֵרִים סוֹרְקִים אֶת הַקּוֹד אוֹ פּוֹתְחִים אֶת הַקִּישּׁוּר — וְאַתֶּם מְחוּבָּרִים!")
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
                Label("סִרְקוּ חָבֵר", systemImage: "qrcode.viewfinder")
                    .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.purpleDream, in: Capsule())
            }
            Text("אוֹ הַקְלִידוּ קוֹד שֶׁל חָבֵר").font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            TextField("", text: $typed, prompt: Text("קוֹד").foregroundColor(.white.opacity(0.5)))
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
            if ok {
                typed = ""; Haptic.success()
                SoundPlayer.shared.play(.chestOpen)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    celebrate = friends.lastAddedFriend
                }
                confettiTrigger += 1
                // Celebrate, then return to the (now-updated) leaderboard.
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                dismiss()
            } else {
                Haptic.warning()
            }
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

// MARK: - Friend profile (tap a card on the board)

/// Tapping any avatar on the leaderboard opens this read-only mini-profile —
/// character, name, ⭐ stars — plus a friend-request action. Shows ONLY the
/// public card data (no contact info, no shaming stats). A request is pending by
/// design: the other child accepts it from their inbox. If THEY already asked me,
/// the button becomes a one-tap accept instead.
struct FriendProfileView: View {
    let card: FriendCard
    @ObservedObject private var friends = FriendsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var sending = false
    @State private var sent = false

    private var meID: String? { ProfileStore.shared.activeID?.uuidString }
    private var isMe: Bool { card.id == meID }
    private var incoming: FriendRequest? { friends.incomingRequests.first { $0.fromID == card.id } }

    var body: some View {
        ZStack {
            AppGradient.galaxy.ignoresSafeArea()
            SparkleField(count: 12, size: 10)

            // A fixed dismiss bar over a scrollable body, so the action button is
            // always reachable — even at the .medium detent on a short screen.
            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(.white.opacity(0.18), in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.md)

                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        CharacterView(character: card.character, portrait: true)
                            .frame(width: 140, height: 140)
                            .glow(AppColor.starGold, radius: 22)

                        Text(card.name.isEmpty ? "שַׂחְקָן" : card.name)
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Label("\(card.stars) כּוֹכָבִים", systemImage: "star.fill")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 9)
                            .background(AppGradient.gold, in: Capsule())

                        actionArea.padding(.top, AppSpacing.sm)
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.md).padding(.bottom, AppSpacing.xl)
                    .frame(maxWidth: 460).frame(maxWidth: .infinity)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        // A fixed height sized to the content (avatar + name + stars + button), so
        // the action button is fully visible without scrolling — `.medium` left it
        // clipped below the fold, especially on iPad's centered card sheet.
        .presentationDetents([.height(480), .large])
        .task { sent = await friends.hasOutgoingRequest(to: card.id) }
    }

    @ViewBuilder private var actionArea: some View {
        if isMe {
            Label("זֶה אַתָּה 🙂", systemImage: "person.fill")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        } else if friends.isFriend(card.id) {
            Label("חָבֵר שֶׁלְּךָ", systemImage: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.successMint)
        } else if let incoming {
            // They asked first — one tap to become friends.
            Button {
                Task { await friends.acceptRequest(incoming); Haptic.success(); dismiss() }
            } label: {
                HStack(spacing: 8) { Image(systemName: "checkmark.circle.fill"); Text("אַשְּׁרוּ בַּקָּשַׁת חֲבֵרוּת") }
                    .font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(AppGradient.gold, in: Capsule())
            }
        } else if sent {
            Label("בַּקָּשָׁה נִשְׁלְחָה ⏳", systemImage: "paperplane.fill")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Capsule().fill(.white.opacity(0.12)))
        } else {
            Button {
                sending = true
                Task {
                    let ok = await friends.sendRequest(to: card)
                    sending = false
                    if ok { sent = true; Haptic.success() } else { Haptic.warning() }
                }
            } label: {
                HStack(spacing: 8) {
                    if sending { ProgressView().tint(.white) }
                    else { Image(systemName: "person.badge.plus") }
                    Text("שִׁלְחוּ בַּקָּשַׁת חֲבֵרוּת")
                }
                .font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(AppGradient.purpleDream, in: Capsule())
            }
            .disabled(sending)
        }
    }
}

// MARK: - Friend requests inbox

/// The inbox of pending requests others sent me — opened from the leaderboard's
/// tray button. Each row shows who's asking (character, name, ⭐ stars) with a
/// gentle accept / "not now". Accepting connects us (+ a little celebration);
/// declining quietly clears it, with no failure surfaced to anyone.
struct FriendRequestsView: View {
    @ObservedObject private var friends = FriendsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var celebrate: FriendCard?
    @State private var confettiTrigger = 0

    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            SparkleField(count: 16, size: 12)
            VStack(spacing: 0) {
                header
                if friends.incomingRequests.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: AppSpacing.md) {
                            ForEach(friends.incomingRequests) { requestRow($0) }
                        }
                        .padding(AppSpacing.lg).frame(maxWidth: 460).frame(maxWidth: .infinity)
                    }
                }
            }

            if let f = celebrate {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: AppSpacing.md) {
                    Text("🎉").font(.system(size: 56))
                    CharacterView(character: f.character)
                        .frame(width: 130, height: 130).shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                    Text(f.name).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    Text("אַתֶּם חֲבֵרִים עַכְשָׁיו! 🤝")
                        .font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(AppColor.starGold)
                }
                .transition(.scale.combined(with: .opacity))
            }
            Confetti(trigger: confettiTrigger).allowsHitTesting(false)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .task { await friends.startLive() }
    }

    private var header: some View {
        ZStack {
            Text("בַּקָּשׁוֹת חֲבֵרוּת").font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            HStack { Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36).background(.white.opacity(0.18), in: Circle())
                }.environment(\.layoutDirection, .leftToRight)
            }
        }
        .padding(.horizontal, AppSpacing.lg).padding(.vertical, AppSpacing.md)
    }

    private func requestRow(_ req: FriendRequest) -> some View {
        HStack(spacing: 12) {
            CharacterView(character: req.character, portrait: true)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(req.name.isEmpty ? "שַׂחְקָן" : req.name)
                    .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text("\(req.stars) ⭐").font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Spacer()
            Button { decline(req) } label: {
                Text("לֹא עַכְשָׁיו").font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
            Button { accept(req) } label: {
                Label("אַשְּׁרוּ", systemImage: "checkmark")
                    .font(.system(size: 14, weight: .black, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(AppGradient.gold, in: Capsule())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Text("📭").font(.system(size: 64))
            Text("אֵין בַּקָּשׁוֹת חֲדָשׁוֹת")
                .font(.system(size: 20, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text("כְּשֶׁמִּישֶׁהוּ יְבַקֵּשׁ לִהְיוֹת חָבֵר שֶׁלְּךָ — זֶה יוֹפִיעַ כָּאן.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer(); Spacer()
        }
    }

    private func accept(_ req: FriendRequest) {
        Task {
            await friends.acceptRequest(req)
            Haptic.success(); SoundPlayer.shared.play(.chestOpen)
            let card = FriendCard(id: req.fromID, name: req.name,
                                  character3DID: req.character3DID, stars: req.stars, code: "")
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { celebrate = card }
            confettiTrigger += 1
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation { celebrate = nil }
            if friends.incomingRequests.isEmpty { dismiss() }
        }
    }

    private func decline(_ req: FriendRequest) {
        Haptic.light()
        Task { await friends.declineRequest(req) }
    }
}
