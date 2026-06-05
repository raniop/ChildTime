import SwiftUI

// MARK: - Live game root

/// The live friends quiz, presented full-screen. Switches on the game's state:
/// lobby → countdown → question → reveal → final (or a gentle "cancelled").
struct LiveGameView: View {
    @ObservedObject private var lg = LiveGameManager.shared
    @ObservedObject private var friends = FriendsManager.shared
    @State private var confetti = 0
    @State private var celebrated = false   // fire the winner confetti once per screen appearance
    @State private var countdownValue = LiveGameRules.countdownSeconds
    @State private var nudged: Set<String> = []     // friends I just re-invited
    @State private var showQuit = false             // "leave the game?" confirm
    @State private var peekPlayer: LiveGamePlayer?  // tapped player → profile peek

    private var meID: String? { ProfileStore.shared.activeID?.uuidString }
    private var amHost: Bool { lg.game?.hostID == meID }

    var body: some View {
        ZStack {
            AppGradient.galaxy.ignoresSafeArea()
            FloatingOrbs(colors: [AppColor.gemPurple, AppColor.starGold, AppColor.diamondBlue],
                         count: 6, maxSize: 240, opacity: 0.32)
            SparkleField(count: 18, size: 12)

            if let g = lg.game {
                switch g.state {
                case .lobby:     lobby(g)
                case .countdown: countdown
                case .question:  questionView(g)
                case .reveal:    revealView(g)
                case .roundBreak: roundBreakView(g)
                case .final:     finalView(g)
                case .cancelled: endedView(title: "הַמִּשְׂחָק הִסְתַּיֵּם 🎈",
                                           subtitle: "תָּמִיד אֶפְשָׁר לְהַתְחִיל מִשְׂחָק חָדָשׁ!")
                }
            } else {
                ProgressView().tint(.white)
            }

            // A persistent "leave" button during live play (lobby + final have
            // their own close button), so anyone can bow out mid-match.
            if let g = lg.game,
               [.countdown, .question, .reveal, .roundBreak].contains(g.state) {
                quitOverlay
            }

            Confetti(trigger: confetti).allowsHitTesting(false)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .confirmationDialog("לָצֵאת מֵהַמִּשְׂחָק?", isPresented: $showQuit, titleVisibility: .visible) {
            Button(amHost ? "כֵּן, לְסַיֵּם לְכֻלָּם" : "כֵּן, לָצֵאת", role: .destructive) {
                Task { await lg.leaveGame() }
            }
            Button("נִשְׁאָרִים בַּמִּשְׂחָק", role: .cancel) {}
        } message: {
            Text(amHost ? "אַתָּה הַמַּנְהִיג — הַמִּשְׂחָק יִסְתַּיֵּם לְכָל הַחֲבֵרִים."
                        : "אֶפְשָׁר תָּמִיד לְהִצְטָרֵף לְמִשְׂחָק חָדָשׁ אַחַר כָּךְ.")
        }
        .sheet(item: $peekPlayer) { p in
            PlayerPeekView(player: p)
                .environment(\.layoutDirection, .rightToLeft)
        }
        .onDisappear { Task { await lg.leaveGame() } }
    }

    /// Floating leave button (top-left in LTR terms) shown throughout live play.
    private var quitOverlay: some View {
        VStack {
            HStack {
                Button { Haptic.light(); showQuit = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .heavy)).foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.black.opacity(0.30), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                }
                Spacer()
            }
            Spacer()
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.md)
    }

    private var closeButton: some View {
        HStack {
            Button { Task { await lg.leaveGame() } } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.white.opacity(0.18), in: Circle())
            }
            Spacer()
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.md)
    }

    // MARK: Lobby

    private func lobby(_ g: LiveGame) -> some View {
        let isHost = g.hostID == meID
        let canStart = lg.players.count >= LiveGameRules.minPlayers
        return VStack(spacing: AppSpacing.lg) {
            closeButton
            Text("🎮").font(.system(size: 56))
            Text(isHost ? "מִי מִצְטָרֵף?" : "\(g.hostName) פָּתַח/ה מִשְׂחָק!")
                .font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text("\(g.topicEmoji) \(g.topicName) · הַטּוֹב מִ-\(g.totalRounds) סִבּוּבִים")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            playerGrid

            if isHost { friendsInviteList(g) }

            Spacer()

            if isHost {
                if let url = URL(string: GameLink.url(forID: g.id)) {
                    ShareLink(item: url, message: Text("בּוֹא נְשַׂחֵק בְּטוֹפִי! 🎮")) {
                        Label("הַזְמִינוּ עוֹד חֲבֵרִים", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(AppColor.gemPurple, in: Capsule())
                    }
                }
                Button { lg.startGame() } label: {
                    Text(canStart ? "מַתְחִילִים! 🚀" : "מְחַכִּים לְעוֹד שַׂחְקָן אֶחָד לְפָחוֹת…")
                        .font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(AppGradient.gold, in: Capsule())
                        .glow(canStart ? AppColor.starGold : .clear, radius: 12)
                }
                .disabled(!canStart).opacity(canStart ? 1 : 0.55)
                .padding(.horizontal, AppSpacing.xl)
            } else {
                Text("מְחַכִּים שֶׁ\(g.hostName) יַתְחִיל… ⏳")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.bottom, AppSpacing.lg)
            }
        }
        .padding(.bottom, AppSpacing.xl)
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
    }

    private var playerGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 14)], spacing: 18) {
                ForEach(lg.players) { p in
                    Button { Haptic.light(); peekPlayer = p } label: {
                        VStack(spacing: 6) {
                            CharacterView(character: p.character, portrait: true)
                                .frame(width: 64, height: 64)
                                .glow(p.id == meID ? AppColor.starGold : .clear, radius: 18)
                            Text(p.name).font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white).lineLimit(1)
                        }
                        .padding(.top, 8)   // room so the glow isn't clipped by the scroll edge
                    }
                    .buttonStyle(.plain)
                }
            }
            // Generous vertical padding so the soft glow has room to breathe top
            // and bottom instead of being cut off at the ScrollView's edge.
            .padding(.horizontal, AppSpacing.lg)
            .padding(.vertical, AppSpacing.lg)
        }
    }

    /// The host's friends with their join status + a direct "invite" (push) button —
    /// so you can call specific friends to the game, not just share a link.
    @ViewBuilder private func friendsInviteList(_ g: LiveGame) -> some View {
        let joinedIDs = Set(lg.players.map(\.id))
        let myFriends = friends.leaderboard.filter { $0.id != meID }
        if !myFriends.isEmpty {
            // RTL: .leading is the RIGHT edge, so the title sits flush right above
            // the rows (instead of floating to the left under .trailing).
            VStack(alignment: .leading, spacing: 8) {
                Text("הַחֲבֵרִים שֶׁלִּי")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(myFriends) { f in
                            HStack(spacing: 10) {
                                CharacterView(character: f.character, portrait: true).frame(width: 36, height: 36)
                                Text(f.name).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                                Spacer()
                                if joinedIDs.contains(f.id) {
                                    Label("הִצְטָרֵף", systemImage: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AppColor.successMint).labelStyle(.titleAndIcon)
                                } else {
                                    Button {
                                        Haptic.light(); nudged.insert(f.id)
                                        Task { await lg.invite(friendID: f.id) }
                                    } label: {
                                        Label(nudged.contains(f.id) ? "נִשְׁלַח" : "הַזְמִינוּ",
                                              systemImage: nudged.contains(f.id) ? "paperplane.fill" : "bell.fill")
                                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12).padding(.vertical, 6)
                                            .background(Capsule().fill(nudged.contains(f.id) ? AppColor.successMint.opacity(0.6) : AppColor.gemPurple))
                                    }
                                    .disabled(nudged.contains(f.id))
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: AppRadius.medium).fill(.white.opacity(0.08)))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.sm)
        }
    }

    // MARK: Countdown

    private var countdown: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            Text(countdownValue > 0 ? "\(countdownValue)" : "🚀")
                .font(.system(size: 120, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .glow(AppColor.starGold, radius: 20)
                .id(countdownValue)
                .transition(.scale.combined(with: .opacity))
            Text("מִתְכּוֹנְנִים…").font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
        .onAppear {
            countdownValue = LiveGameRules.countdownSeconds
            tickCountdown()
        }
    }

    private func tickCountdown() {
        guard countdownValue > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                if countdownValue > 0 { countdownValue -= 1 }
            }
            if countdownValue > 0 { tickCountdown() }
        }
    }

    // MARK: Question

    private func questionView(_ g: LiveGame) -> some View {
        let q = g.currentQuestion
        return VStack(spacing: AppSpacing.lg) {
            // Header: big timer ring on one side, round/question pills on the other.
            HStack(alignment: .center) {
                timerRing(g)
                Spacer()
                progressPills(g)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, 64)   // clear the floating quit button

            headToHead(g)
                .padding(.horizontal, AppSpacing.lg)

            Spacer(minLength: AppSpacing.md)

            questionCard(q)
                .padding(.horizontal, AppSpacing.lg)
                .layoutPriority(1)   // win vertical space over the flexible spacers

            Spacer(minLength: AppSpacing.md)

            answerGrid(q)
                .padding(.horizontal, AppSpacing.lg)

            if lg.myChoiceIndex != nil {
                Label("עָנִיתָ! מְחַכִּים לַשְּׁאָר…", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
                    .padding(.top, AppSpacing.sm)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, AppSpacing.lg)
        .frame(maxWidth: 680).frame(maxWidth: .infinity)
    }

    /// Round + question position as bold gold pills.
    private func progressPills(_ g: LiveGame) -> some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("סִבּוּב \(g.currentRound + 1)/\(g.totalRounds)")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(AppGradient.gold, in: Capsule())
            Text("שְׁאֵלָה \(g.questionInRound + 1)/\(g.roundQuestions)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(.white.opacity(0.12), in: Capsule())
        }
    }

    /// The question in a big, glassy card so it pops off the galaxy background
    /// instead of floating as lonely text.
    private func questionCard(_ q: LiveGameQuestion?) -> some View {
        Text(q?.prompt ?? "")
            .font(.system(size: 42, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(5).minimumScaleFactor(0.6)
            .fixedSize(horizontal: false, vertical: true)   // claim full height — never drop the 2nd (Hebrew) line
            .shadow(color: .black.opacity(0.28), radius: 10, y: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44).padding(.horizontal, 26)
            .background(
                RoundedRectangle(cornerRadius: 40, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
            )
    }

    /// The live "כמה–כמה": a dramatic VS for a 2-player duel (round wins big in
    /// the middle, e.g. 1 — 0), or a compact chip row for 3+ players. Shown during
    /// the question so you always know the score. Display-only (no peek mid-play).
    @ViewBuilder
    private func headToHead(_ g: LiveGame) -> some View {
        let ps = lg.players
        if ps.count == 2 {
            // players are sorted by score; show ME on the right (RTL) when I'm in it.
            let ordered = ps.contains { $0.id == meID }
                ? ps.sorted { ($0.id == meID ? 1 : 0) > ($1.id == meID ? 1 : 0) }
                : ps
            let left = ordered[0], right = ordered[1]
            HStack(spacing: 12) {
                vsSide(left)
                VStack(spacing: 1) {
                    Text("\(left.roundWins) — \(right.roundWins)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white).monospacedDigit()
                    Text("🏆 סִבּוּבִים")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                vsSide(right)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10).padding(.horizontal, 16)
            .background(Capsule().fill(.white.opacity(0.10))
                .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1)))
        } else if ps.count > 2 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ps) { p in
                        HStack(spacing: 6) {
                            CharacterView(character: p.character, portrait: true).frame(width: 30, height: 30)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(p.name).font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white).lineLimit(1)
                                Text("🏆\(p.roundWins) · \(p.score)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(AppColor.starGold)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(p.id == meID ? AppColor.starGold.opacity(0.22) : .white.opacity(0.10)))
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    /// One side of the 2-player VS card.
    private func vsSide(_ p: LiveGamePlayer) -> some View {
        VStack(spacing: 3) {
            CharacterView(character: p.character, portrait: true)
                .frame(width: 50, height: 50)
                .glow(p.id == meID ? AppColor.starGold : .clear, radius: 10)
            Text(p.name).font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white).lineLimit(1)
            Text("\(p.score)").font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.starGold)
        }
        .frame(maxWidth: .infinity)
    }

    private func timerRing(_ g: LiveGame) -> some View {
        TimelineView(.animation) { timeline in
            let total = Double(g.questionDurationMs) / 1000.0
            let elapsed: Double = {
                guard let start = g.questionStartedAt else { return 0 }
                return max(0, timeline.date.timeIntervalSince(start))
            }()
            let remaining = max(0, total - elapsed)
            let frac = total > 0 ? remaining / total : 0
            let tint = frac > 0.3 ? AppColor.successMint : AppColor.almostWarm
            ZStack {
                Circle().stroke(.white.opacity(0.18), lineWidth: 8)
                Circle().trim(from: 0, to: frac)
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .glow(tint, radius: 8)
                Text("\(Int(remaining.rounded(.up)))")
                    .font(.system(size: 28, weight: .black, design: .rounded)).foregroundStyle(.white)
            }
            .frame(width: 72, height: 72)
        }
    }

    private let answerColors: [Color] = [
        Color(hex: "F25C54"), Color(hex: "4CC9F0"), Color(hex: "06D6A0"), Color(hex: "9B5DE5"),
    ]

    private func answerGrid(_ q: LiveGameQuestion?) -> some View {
        let options = q?.options ?? []
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, text in
                let answered = lg.myChoiceIndex != nil
                let mine = lg.myChoiceIndex == idx
                let color = answerColors[idx % answerColors.count]
                Button {
                    Task { await lg.submitAnswer(idx) }
                } label: {
                    Text(text)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, minHeight: 118)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .fill(color.opacity(answered && !mine ? 0.30 : 1))
                                .shadow(color: color.opacity(answered && !mine ? 0 : 0.45), radius: 14, y: 8)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(.white, lineWidth: mine ? 5 : 0))
                        .scaleEffect(mine ? 1.04 : 1)
                        .glow(mine ? .white : .clear, radius: 14)
                }
                .buttonStyle(.plain)
                .disabled(answered)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: mine)
            }
        }
    }

    // MARK: Reveal

    private func revealView(_ g: LiveGame) -> some View {
        let q = g.currentQuestion
        let correct = g.revealCorrectIndex
        let mine = lg.myChoiceIndex
        let gotIt = mine != nil && mine == correct
        return VStack(spacing: AppSpacing.lg) {
            Spacer()
            Text(gotIt ? "נֶהֱדָר! 🎉" : (mine == nil ? "הַשְּׁאֵלָה הַבָּאָה תַּגִּיעַ 💫" : "כִּמְעַט! 🌟"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(gotIt ? AppColor.successMint : .white)

            VStack(spacing: 12) {
                ForEach(Array((q?.options ?? []).enumerated()), id: \.offset) { idx, text in
                    let isCorrect = idx == correct
                    let isMine = idx == mine
                    HStack {
                        Text(text).font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.6)
                        Spacer()
                        if isCorrect { Text("✓").font(.system(size: 26, weight: .black)).foregroundStyle(.white) }
                        else if isMine { Text("בָּחַרְתָּ").font(.system(size: 14, weight: .bold)).foregroundStyle(.white.opacity(0.8)) }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 16)
                    .background(RoundedRectangle(cornerRadius: AppRadius.large)
                        .fill(isCorrect ? AppColor.successMint.opacity(0.9)
                              : (isMine ? AppColor.almostWarm.opacity(0.5) : .white.opacity(0.10))))
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .frame(maxWidth: 600)

            Spacer()
            scoreStrip
            Spacer()
        }
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .onAppear {
            // Celebrate a correct answer; otherwise stay gentle (no "wrong" sound).
            if gotIt { SoundPlayer.shared.play(.correctBig); Haptic.success() }
            else { Haptic.soft() }
        }
    }

    /// Compact live standings shown between questions.
    private var scoreStrip: some View {
        VStack(spacing: 8) {
            Text("הַנִּקּוּד").font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            ForEach(Array(lg.players.prefix(6).enumerated()), id: \.element.id) { idx, p in
                Button { Haptic.light(); peekPlayer = p } label: {
                    HStack(spacing: 10) {
                        Text("\(idx + 1)").font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7)).frame(width: 20)
                        CharacterView(character: p.character, portrait: true).frame(width: 34, height: 34)
                        Text(p.name).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Spacer()
                        Text("\(p.score)").font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(AppColor.starGold)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(p.id == meID ? AppColor.starGold.opacity(0.20) : .white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: Round break

    private func roundBreakView(_ g: LiveGame) -> some View {
        let winner = lg.players.first(where: { $0.id == g.lastRoundWinnerID })
        return VStack(spacing: AppSpacing.lg) {
            Spacer()
            Text("🏁").font(.system(size: 56))
            Text("סִיַּמְנוּ סִבּוּב \(g.currentRound + 1)!")
                .font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            if let winner {
                Text("\(winner.name) לָקַח/ה אֶת הַסִּבּוּב! 🎉")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppColor.starGold)
            } else {
                Text("תֵּיקוּ בַּסִּבּוּב! 🤝")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }
            roundWinsTally
            Text("הַסִּבּוּב הַבָּא מַתְחִיל… ⏳")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
            Spacer(); Spacer()
        }
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        .onAppear { SoundPlayer.shared.play(.streakUp); Haptic.medium() }
    }

    /// 🏆 per player — the running best-of-3 tally.
    private var roundWinsTally: some View {
        VStack(spacing: 8) {
            ForEach(lg.players.sorted { $0.roundWins != $1.roundWins ? $0.roundWins > $1.roundWins : $0.score > $1.score }) { p in
                Button { Haptic.light(); peekPlayer = p } label: {
                    HStack(spacing: 10) {
                        CharacterView(character: p.character, portrait: true).frame(width: 36, height: 36)
                        Text(p.name).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        Spacer()
                        Text(String(repeating: "🏆", count: p.roundWins).isEmpty ? "—" : String(repeating: "🏆", count: p.roundWins))
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(p.id == meID ? AppColor.starGold.opacity(0.20) : .white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AppSpacing.xl)
    }

    // MARK: Final

    private func finalView(_ g: LiveGame) -> some View {
        // Match winner = most rounds won (tie-broken by points).
        let winnerID = g.matchWinnerID
        let iWon = winnerID == meID
        let myStars = iWon ? LiveGameRules.winnerStars : LiveGameRules.participationStars
        let myGems  = iWon ? LiveGameRules.winnerDiamonds : LiveGameRules.participationDiamonds
        let sorted = lg.players.sorted {
            $0.roundWins != $1.roundWins ? $0.roundWins > $1.roundWins : $0.score > $1.score
        }
        return VStack(spacing: AppSpacing.lg) {
            closeButton
            Text(iWon ? "🏆" : "🎉").font(.system(size: 76))
            Text(iWon ? "וָואו, נִצַּחְתָּ! 🤩" : "כָּל הַכָּבוֹד! 🎉")
                .font(.system(size: 32, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .glow(AppColor.starGold, radius: 14)
                .multilineTextAlignment(.center)
            Text("הַפְּרָסִים שֶׁלְּךָ:")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            HStack(spacing: 16) {
                prizePill("⭐", myStars, AppColor.starGold)
                prizePill("💎", myGems, AppColor.diamondBlue)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, p in
                        Button { Haptic.light(); peekPlayer = p } label: {
                            HStack(spacing: 12) {
                                Text(idx == 0 ? "🥇" : idx == 1 ? "🥈" : idx == 2 ? "🥉" : "\(idx + 1)")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white).frame(width: 32)
                                CharacterView(character: p.character, portrait: true).frame(width: 44, height: 44)
                                Text(p.name).font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(String(repeating: "🏆", count: p.roundWins)).font(.system(size: 14))
                                    Text("\(p.score) נְקֻדּוֹת").font(.system(size: 13, weight: .heavy, design: .rounded))
                                        .foregroundStyle(AppColor.starGold)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: AppRadius.large)
                                .fill(p.id == meID ? AppColor.starGold.opacity(0.20) : .white.opacity(0.10)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }

            VStack(spacing: 10) {
                Button { Haptic.light(); Task { await lg.leaveGame(); lg.wantsNewGame = true } } label: {
                    Text("שַׂחֵק שׁוּב 🔄").font(.system(size: 19, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15).background(AppGradient.gold, in: Capsule())
                }
                Button { Task { await lg.leaveGame() } } label: {
                    Text("סִיּוּם").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity).padding(.vertical, 13).background(.white.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, AppSpacing.xl).padding(.bottom, AppSpacing.lg)
        }
        .frame(maxWidth: 560).frame(maxWidth: .infinity)
        // One clean confetti burst per appearance — re-triggering it mid-fall made
        // the pieces snap above the screen, which read as "vanished then re-appeared".
        // The `celebrated` flag also shrugs off any duplicate onAppear.
        .onAppear {
            guard !celebrated else { return }
            celebrated = true
            confetti += 1
            SoundPlayer.shared.play(.levelUp)
            Haptic.success()
        }
        .onDisappear { celebrated = false }
    }

    private func prizePill(_ emoji: String, _ amount: Int, _ tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(emoji).font(.system(size: 36))
            Text("+\(amount)").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundStyle(tint)
        }
        .frame(width: 96, height: 96)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(tint.opacity(0.16)))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.large).stroke(tint.opacity(0.45), lineWidth: 1.5))
    }

    // MARK: Ended / cancelled

    private func endedView(title: String, subtitle: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            Text("🎈").font(.system(size: 64))
            Text(title).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Button { Task { await lg.leaveGame() } } label: {
                Text("סְגִירָה").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xl).padding(.vertical, 14)
                    .background(AppGradient.gold, in: Capsule())
            }
            .padding(.top, 6)
            Spacer(); Spacer()
        }
    }
}

private extension LiveGame {
    var topicName: String { Topic(rawValue: topic)?.displayName ?? "" }
    var topicEmoji: String { Topic(rawValue: topic)?.emoji ?? "🎯" }
}

// MARK: - Player peek

/// A tap on any player opens this kid-friendly mini-profile: their character,
/// name, ⭐ stars, and this-match stats — plus an "add friend" shortcut if we're
/// not friends yet. Shows ONLY the same public data as the friends leaderboard
/// (no contact info, and never any "losses"/shaming stats).
struct PlayerPeekView: View {
    let player: LiveGamePlayer
    @ObservedObject private var friends = FriendsManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var card: FriendCard?
    @State private var loading = true
    @State private var adding = false
    @State private var added = false

    private var meID: String? { ProfileStore.shared.activeID?.uuidString }
    private var isMe: Bool { player.id == meID }

    var body: some View {
        ZStack {
            AppGradient.galaxy.ignoresSafeArea()
            SparkleField(count: 12, size: 10)

            VStack(spacing: AppSpacing.lg) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(.white.opacity(0.18), in: Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.md)

                CharacterView(character: player.character, portrait: true)
                    .frame(width: 140, height: 140)
                    .glow(AppColor.starGold, radius: 22)

                Text(player.name.isEmpty ? "שַׂחְקָן" : player.name)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if let stars = card?.stars {
                    Label("\(stars) כּוֹכָבִים", systemImage: "star.fill")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(AppGradient.gold, in: Capsule())
                } else if loading {
                    ProgressView().tint(.white)
                }

                HStack(spacing: 14) {
                    statTile("🏆", "\(player.roundWins)", "סִבּוּבִים")
                    statTile("⚡️", "\(player.score)", "נְקֻדּוֹת")
                }
                .padding(.horizontal, AppSpacing.lg)
                Text("בַּמִּשְׂחָק הַזֶּה")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                addFriendArea
                    .padding(.horizontal, AppSpacing.xl).padding(.bottom, AppSpacing.xl)
            }
            .frame(maxWidth: 460).frame(maxWidth: .infinity)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .presentationDetents([.medium, .large])
        .task {
            card = await friends.card(for: player.id)
            loading = false
        }
    }

    private func statTile(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.system(size: 26))
            Text(value).font(.system(size: 24, weight: .black, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.10)))
    }

    @ViewBuilder private var addFriendArea: some View {
        if isMe {
            Label("זֶה אַתָּה 🙂", systemImage: "person.fill")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        } else if added || friends.isFriend(player.id) {
            Label("חָבֵר שֶׁלְּךָ", systemImage: "checkmark.circle.fill")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.successMint)
        } else if let code = card?.code, !code.isEmpty {
            Button {
                adding = true
                Task {
                    let ok = await friends.addFriend(code: code)
                    adding = false
                    if ok { added = true; Haptic.success() } else { Haptic.warning() }
                }
            } label: {
                HStack(spacing: 8) {
                    if adding { ProgressView().tint(.white) }
                    else { Image(systemName: "person.badge.plus") }
                    Text("הוֹסִיפוּ לַחֲבֵרִים")
                }
                .font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(AppGradient.purpleDream, in: Capsule())
            }
            .disabled(adding)
        }
    }
}

// MARK: - Flow wrapper

/// ONE full-screen flow for the whole live game: the topic-pick screen until a
/// game exists, then the lobby/game itself. Presenting both from a single cover
/// (instead of a sheet + a separate cover) avoids the SwiftUI presentation race
/// that briefly opened the lobby and slammed it shut.
struct LiveGameFlowView: View {
    @ObservedObject private var lg = LiveGameManager.shared
    var body: some View {
        if lg.game != nil {
            LiveGameView()
        } else {
            LiveGameSetupSheet()
        }
    }
}

/// DEMO_SCREEN=livegame — reproduces the EXACT presentation path the home screen
/// uses (the flow's full-screen cover), so a screenshot proves the setup opens
/// full-screen. Never used in production.
struct LiveGameDemoHost: View {
    @ObservedObject private var lg = LiveGameManager.shared
    var body: some View {
        ZStack {
            AppGradient.dreamy.ignoresSafeArea()
            Text("DEMO").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.3))
        }
        .fullScreenCover(isPresented: Binding(
            get: { lg.isSettingUp || lg.game != nil },
            set: { if !$0 { Task { await lg.leaveGame() } } })) {
            LiveGameFlowView()
        }
        .onAppear { lg.openSetup() }
    }
}

// MARK: - New-game setup

/// Kid-simple: ONE decision. Tap a big topic tile and the game starts — the
/// difficulty follows the child's own level and the length is a short 5
/// questions, so there are no extra menus to read.
struct LiveGameSetupSheet: View {
    @ObservedObject private var lg = LiveGameManager.shared
    @State private var creating = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ZStack {
            AppGradient.galaxy.ignoresSafeArea()
            SparkleField(count: 14, size: 11)
            VStack(spacing: AppSpacing.lg) {
                Text("בְּמָה מְשַׂחֲקִים? 🎮")
                    .font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .padding(.top, AppSpacing.xxl)
                Text("בַּחֲרוּ נוֹשֵׂא וְהַמִּשְׂחָק מַתְחִיל!")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Topic.allCases) { t in topicTile(t) }
                    }
                    .padding(.horizontal, AppSpacing.lg).padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.xxxl)
                }

                if let err = lg.lastError, creating == false {
                    Text(err).font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppColor.almostWarm).multilineTextAlignment(.center)
                        .padding(.bottom, AppSpacing.sm)
                }
            }
            .frame(maxWidth: 520).frame(maxWidth: .infinity)

            if creating {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: AppSpacing.md) {
                    Text("🚀").font(.system(size: 52))
                    Text("מַכְינִים אֶת הַמִּשְׂחָק…")
                        .font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .overlay(alignment: .topLeading) {
            Button { lg.closeSetup() } label: {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(.white.opacity(0.18), in: Circle())
            }
            .padding(AppSpacing.lg)
        }
    }

    /// A big, emoji-first tile. One tap creates the game at the child's own level.
    private func topicTile(_ t: Topic) -> some View {
        Button {
            guard !creating else { return }
            Haptic.medium(); SoundPlayer.shared.play(.uiTap)
            creating = true
            Task {
                let level = ProfileStore.shared.active?.difficulty(for: t) ?? .easy
                // On success, `game` becomes non-nil and the SAME flow cover swaps
                // to the lobby — no second presentation, so no flash-and-close.
                _ = await lg.createGame(topic: t, difficulty: level)
                creating = false
            }
        } label: {
            VStack(spacing: 8) {
                Text(t.emoji).font(.system(size: 52))
                Text(t.displayName).font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity).frame(height: 130)
            .background(RoundedRectangle(cornerRadius: AppRadius.large).fill(.white.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.large).stroke(.white.opacity(0.18), lineWidth: 1))
        }
        .disabled(creating)
    }
}
