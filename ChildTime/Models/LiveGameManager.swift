import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

// MARK: - Tunables

/// Tunable rules for the live friends quiz. Kept in one place so pacing + rewards
/// are easy to adjust without hunting through the engine.
enum LiveGameRules {
    static let questionDurationMs = 12_000      // time to answer each question
    static let revealDurationMs   = 4_000       // how long the answer + scores show
    static let roundBreakMs       = 4_500       // pause between rounds (show round result)
    static let countdownSeconds   = 3           // 3·2·1 before the first question
    static let basePoints         = 100         // max points for an instant correct answer
    static let minPlayers         = 2           // host + at least one friend to start
    static let maxPlayers         = 6
    static let winnerDiamonds     = 20          // 💎 bonus for the winner
    static let participationDiamonds = 5        // 💎 everyone earns for playing
    // A match is BEST OF 3 rounds, each round 5 questions. First to win 2 rounds
    // takes the match (so it can end after 2 rounds, or go the full 3).
    static let totalRounds        = 3
    static let roundQuestions     = 5
    static var roundsToWin: Int { totalRounds / 2 + 1 }   // best-of-3 → 2

    /// Points for a CORRECT answer, scaled by how fast it came in (server-measured):
    /// an instant answer ≈ `basePoints`, the slowest-but-correct ≈ half. Clamped so
    /// no one who got it right ever drops below half — everyone-earns by design.
    static func points(responseMs: Double, durationMs: Double) -> Int {
        guard durationMs > 0 else { return basePoints }
        let frac = max(0, min(1, responseMs / durationMs))
        let factor = max(0.5, 1.0 - 0.5 * frac)
        return Int((Double(basePoints) * factor).rounded())
    }
}

// MARK: - Models (UI-facing, no Firebase types)

enum LiveGameState: String {
    case lobby, countdown, question, reveal, roundBreak, final, cancelled
}

struct LiveGameQuestion: Equatable {
    var prompt: String
    var options: [String]
    var spoken: String?
}

struct LiveGamePlayer: Identifiable, Equatable {
    var id: String              // childID
    var name: String
    var character3DID: String?
    var score: Int = 0          // cumulative points across the match
    var roundWins: Int = 0      // rounds won (best-of-3)
    var character: Character3D { Character3DCatalog.find(character3DID) }
}

/// A live game's PUBLIC state, mirrored from `liveGames/{id}`. Intentionally
/// minimal — the answer key is NEVER stored here (the host keeps it locally) so
/// a curious player can't read the correct answer from Firestore before reveal.
struct LiveGame: Equatable {
    var id: String
    var hostID: String
    var hostName: String
    var state: LiveGameState
    var topic: String
    var difficulty: String
    var totalQuestions: Int
    var currentIndex: Int
    var questions: [LiveGameQuestion]
    var questionStartedAt: Date?
    var questionDurationMs: Int
    /// The correct option for the CURRENT question — written by the host only at
    /// reveal time, nil while the question is live.
    var revealCorrectIndex: Int?
    var scores: [String: Int]
    var invited: [String]
    // Best-of-3 rounds.
    var totalRounds: Int
    var roundQuestions: Int
    var roundWins: [String: Int]        // playerID → rounds won
    var lastRoundWinnerID: String?      // who took the round just finished (nil = draw)

    var currentQuestion: LiveGameQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }
    /// 0-based round the current question belongs to.
    var currentRound: Int { roundQuestions > 0 ? currentIndex / roundQuestions : 0 }
    /// 0-based position of the current question within its round.
    var questionInRound: Int { roundQuestions > 0 ? currentIndex % roundQuestions : currentIndex }

    /// The match winner: most rounds won, tie-broken by total points. nil only on a
    /// genuine dead heat (same wins AND same points).
    var matchWinnerID: String? { LiveGame.matchWinnerID(roundWins: roundWins, scores: scores) }

    static func matchWinnerID(roundWins: [String: Int], scores: [String: Int]) -> String? {
        let maxWins = roundWins.values.max() ?? 0
        let contenders: [String]
        if maxWins > 0 {
            contenders = roundWins.filter { $0.value == maxWins }.map(\.key)
        } else {
            // No decided rounds (all draws) → fall back to total points.
            let maxScore = scores.values.max() ?? 0
            guard maxScore > 0 else { return nil }
            contenders = scores.filter { $0.value == maxScore }.map(\.key)
        }
        if contenders.count == 1 { return contenders.first }
        // Tie-break the contenders by total points.
        let maxScore = contenders.map { scores[$0] ?? 0 }.max() ?? 0
        let top = contenders.filter { (scores[$0] ?? 0) == maxScore }
        return top.count == 1 ? top.first : nil
    }
}

/// A pending invite surfaced in-app (a friend started a game I'm invited to).
struct LiveGameInvite: Identifiable, Equatable {
    var id: String          // gameID
    var hostName: String
}

// MARK: - Manager

/// Drives the live friends quiz. HOST-AUTHORITATIVE, no Cloud Functions for the
/// gameplay itself: the creator's device advances the state machine (pacing is
/// the host's local clock) while SCORING uses Firestore SERVER timestamps so
/// "who answered fastest" is fair regardless of any device's clock.
///
/// Topology — `liveGames/{id}` (host writes), `players/{playerID}` (each player
/// writes only their own), `answers/{index}_{playerID}` (create-once, immutable).
@MainActor
final class LiveGameManager: ObservableObject {
    static let shared = LiveGameManager()

    @Published private(set) var game: LiveGame?
    @Published private(set) var players: [LiveGamePlayer] = []   // roster, sorted by score
    @Published private(set) var invites: [LiveGameInvite] = []   // in-app "join" prompts
    /// My chosen option for the current question (nil = not answered yet).
    @Published private(set) var myChoiceIndex: Int?
    /// Set from a game deep link / push tap; consumed by the home screen.
    @Published var pendingGameID: String?
    /// Flipped by the leaderboard's "create game" button so the home screen opens
    /// the setup sheet (the game UI is presented at the home level).
    @Published var wantsNewGame = false
    /// True while the topic-pick screen should show. Together with `game != nil`
    /// this drives ONE full-screen flow (setup → lobby → game), so there's never
    /// a second presentation racing the first (which used to flash the lobby shut).
    @Published var isSettingUp = false
    @Published var lastError: String?

    private var isHost = false
    private var answerKey: [Int] = []        // host-only: correct option per question
    private var rewardedFinal = false
    private var rosterRaw: [LiveGamePlayer] = []

    private var myID: String? { ProfileStore.shared.activeID?.uuidString }

    private init() {}

    private func log(_ s: String) { print("[LiveGame] \(s)") }

    /// DEMO only (DEMO_SCREEN=gameinvite): seed a sample invite to preview the
    /// home-screen invite banner. Never used in production.
    func seedDemoInvite() { invites = [LiveGameInvite(id: "demo", hostName: "דָּן הַמֶּלֶךְ")] }

    /// Open the topic-pick screen (home screen presents the flow).
    func openSetup() { lastError = nil; isSettingUp = true }
    /// Close the topic-pick screen without creating a game.
    func closeSetup() { isSettingUp = false }

    // MARK: Public API

    /// Create a game I host: generate the questions + answer key, write the lobby
    /// doc, join myself, and start listening. Returns the new game id (or nil).
    @discardableResult
    func createGame(topic: Topic, difficulty: Difficulty) async -> String? {
        #if canImport(FirebaseFirestore)
        guard let myID, AuthManager.shared.isSignedIn, let uid = AuthManager.shared.userID else {
            lastError = "צָרִיךְ לְהִתְחַבֵּר כְּדֵי לְשַׂחֵק עִם חֲבֵרִים"; return nil
        }
        let profile = ProfileStore.shared.active

        // Generate the whole match up-front (best-of-3 → 3 rounds × 5) so everyone
        // gets the SAME questions. The public doc carries prompt+options only — the
        // answer key stays local on the host (anti-cheat).
        let target = LiveGameRules.totalRounds * LiveGameRules.roundQuestions
        var wireQuestions: [[String: Any]] = []
        var seenPrompts = Set<String>()
        answerKey = []
        var safety = 0
        while wireQuestions.count < target && safety < target * 8 {
            safety += 1
            let q = QuestionGenerator.generate(topic: topic, difficulty: difficulty)
            guard !seenPrompts.contains(q.prompt) else { continue }
            seenPrompts.insert(q.prompt)
            answerKey.append(q.correctIndex)
            var qd: [String: Any] = ["prompt": q.prompt, "options": q.options]
            if let spoken = q.spoken { qd["spoken"] = spoken }
            wireQuestions.append(qd)
        }
        guard !wireQuestions.isEmpty else { lastError = "לֹא הִצְלַחְנוּ לְהָכִין שְׁאֵלוֹת"; return nil }

        // Make sure my friend list is loaded so the auto-invite actually reaches
        // everyone (otherwise `invited` could be empty if the board wasn't opened).
        if FriendsManager.shared.leaderboard.count <= 1 { await FriendsManager.shared.refresh() }
        // Invite my current friends (the leaderboard graph) — they get a push.
        let invited = FriendsManager.shared.leaderboard.map(\.id).filter { $0 != myID }

        let gameID = UUID().uuidString
        let doc: [String: Any] = [
            "id": gameID,
            "hostID": myID,
            "hostName": profile?.name ?? "",
            "hostOwnerUID": uid,
            "state": LiveGameState.lobby.rawValue,
            "topic": topic.rawValue,
            "difficulty": difficulty.rawValue,
            "totalQuestions": wireQuestions.count,
            "currentIndex": -1,
            "questions": wireQuestions,
            "questionDurationMs": LiveGameRules.questionDurationMs,
            "scores": [String: Int](),
            "invited": invited,
            "totalRounds": LiveGameRules.totalRounds,
            "roundQuestions": LiveGameRules.roundQuestions,
            "roundWins": [String: Int](),
            "createdAt": FieldValue.serverTimestamp(),
        ]
        do {
            try await db.collection("liveGames").document(gameID).setData(doc)
            isHost = true
            rewardedFinal = false
            await joinAsPlayer(gameID: gameID)
            startLive(gameID: gameID)
            log("created \(gameID) with \(wireQuestions.count) questions, invited \(invited.count)")
            return gameID
        } catch {
            lastError = error.localizedDescription
            log("❌ createGame failed: \(error.localizedDescription)")
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Join a game I was invited to (from a deep link / push / in-app banner).
    func joinGame(_ gameID: String) async {
        #if canImport(FirebaseFirestore)
        guard AuthManager.shared.isSignedIn else { lastError = "צָרִיךְ לְהִתְחַבֵּר"; return }
        // Only join while the lobby is still open — no jumping into a game already
        // in progress or finished (the round timing wouldn't be fair).
        guard let snap = try? await db.collection("liveGames").document(gameID).getDocument(),
              let state = snap.data()?["state"] as? String,
              state == LiveGameState.lobby.rawValue || state == LiveGameState.countdown.rawValue else {
            lastError = "הַמִּשְׂחָק כְּבָר הִתְחִיל אוֹ הִסְתַּיֵּם"
            return
        }
        isHost = false
        rewardedFinal = false
        await joinAsPlayer(gameID: gameID)
        startLive(gameID: gameID)
        #endif
    }

    /// Send a direct device invite (push) to a specific friend — used from the
    /// lobby's friends list so the host can nudge someone who hasn't joined yet.
    /// Writes a `nudges` doc that a Cloud Function turns into a push.
    func invite(friendID: String) async {
        #if canImport(FirebaseFirestore)
        guard isHost, let g = game, let uid = AuthManager.shared.userID else { return }
        let hostName = ProfileStore.shared.active?.name ?? ""
        // Ensure they're on the invited list too (drives the in-app banner).
        try? await db.collection("liveGames").document(g.id)
            .setData(["invited": FieldValue.arrayUnion([friendID])], merge: true)
        try? await db.collection("liveGames").document(g.id)
            .collection("nudges").document(UUID().uuidString).setData([
                "targetID": friendID,
                "hostName": hostName,
                "ownerUID": uid,
                "createdAt": FieldValue.serverTimestamp(),
            ])
        #endif
    }

    /// The host kicks off the match: countdown → questions → reveals → final.
    func startGame() {
        #if canImport(FirebaseFirestore)
        guard isHost, hostTask == nil, let gameID = game?.id else { return }
        hostTask = Task { await runHostLoop(gameID: gameID) }
        #endif
    }

    /// Submit my answer for the current question (first answer only — immutable).
    func submitAnswer(_ choiceIndex: Int) async {
        #if canImport(FirebaseFirestore)
        guard let g = game, g.state == .question, myChoiceIndex == nil,
              let myID, let uid = AuthManager.shared.userID else { return }
        myChoiceIndex = choiceIndex
        Haptic.light()
        let docID = "\(g.currentIndex)_\(myID)"
        do {
            try await db.collection("liveGames").document(g.id)
                .collection("answers").document(docID).setData([
                    "index": g.currentIndex,
                    "playerID": myID,
                    "choiceIndex": choiceIndex,
                    "ownerUID": uid,
                    "answeredAt": FieldValue.serverTimestamp(),
                ])
        } catch {
            log("answer write failed: \(error.localizedDescription)")
        }
        #endif
    }

    /// Leave / close the game. If I'm the host and it's still in progress, mark it
    /// cancelled so my friends see a gentle "the game ended" instead of a freeze.
    func leaveGame() async {
        #if canImport(FirebaseFirestore)
        if isHost, let g = game, g.state != .final, g.state != .cancelled {
            // Host bailing mid-match → end it gently for everyone.
            await patch(g.id, ["state": LiveGameState.cancelled.rawValue])
        } else if !isHost, let g = game, g.state != .final, g.state != .cancelled, let myID {
            // A player who quits mid-game drops out of the roster, so the host
            // stops waiting for their answer on every remaining question.
            try? await db.collection("liveGames").document(g.id)
                .collection("players").document(myID).delete()
        }
        #endif
        hostTask?.cancel(); hostTask = nil
        stopLive()
        game = nil; players = []; rosterRaw = []
        myChoiceIndex = nil; isHost = false; rewardedFinal = false; answerKey = []
        isSettingUp = false
    }

    // MARK: Firestore

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var gameListener: ListenerRegistration?
    private var playersListener: ListenerRegistration?
    private var invitesListener: ListenerRegistration?
    private var hostTask: Task<Void, Never>?

    private func patch(_ gameID: String, _ fields: [String: Any]) async {
        do { try await db.collection("liveGames").document(gameID).setData(fields, merge: true) }
        catch { log("patch failed: \(error.localizedDescription)") }
    }

    private func joinAsPlayer(gameID: String) async {
        guard let myID, let uid = AuthManager.shared.userID else { return }
        let profile = ProfileStore.shared.active
        var data: [String: Any] = [
            "id": myID,
            "name": profile?.name ?? "",
            "ownerUID": uid,
            "joinedAt": FieldValue.serverTimestamp(),
        ]
        if let c = profile?.character3DID { data["character3DID"] = c }
        do {
            try await db.collection("liveGames").document(gameID)
                .collection("players").document(myID).setData(data, merge: true)
        } catch { log("join failed: \(error.localizedDescription)") }
    }

    private func startLive(gameID: String) {
        stopLive()
        gameListener = db.collection("liveGames").document(gameID)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    guard let data = snap?.data(), let g = LiveGame(from: data) else { return }
                    let prevIndex = self.game?.currentIndex
                    self.game = g
                    self.isSettingUp = false   // we have a game now → flow shows it
                    if g.currentIndex != prevIndex { self.myChoiceIndex = nil }
                    self.refreshRoster()
                    if g.state == .final { self.awardFinalRewardOnce() }
                }
            }
        playersListener = db.collection("liveGames").document(gameID)
            .collection("players")
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.rosterRaw = (snap?.documents ?? []).compactMap { LiveGamePlayer(from: $0.data()) }
                    self.refreshRoster()
                }
            }
    }

    private func stopLive() {
        gameListener?.remove(); gameListener = nil
        playersListener?.remove(); playersListener = nil
    }

    /// Recompute the published roster: each player's live score from the game doc.
    private func refreshRoster() {
        let scores = game?.scores ?? [:]
        let wins = game?.roundWins ?? [:]
        var list = rosterRaw
        for i in list.indices {
            list[i].score = scores[list[i].id] ?? 0
            list[i].roundWins = wins[list[i].id] ?? 0
        }
        players = list.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.name < $1.name
        }
    }

    // MARK: Host state machine

    private func runHostLoop(gameID: String) async {
        // Countdown.
        await patch(gameID, ["state": LiveGameState.countdown.rawValue, "currentIndex": -1])
        await sleepMs(LiveGameRules.countdownSeconds * 1000)

        let duration = game?.questionDurationMs ?? LiveGameRules.questionDurationMs
        let rounds = game?.totalRounds ?? LiveGameRules.totalRounds
        let perRound = max(1, game?.roundQuestions ?? LiveGameRules.roundQuestions)
        var roundWins: [String: Int] = [:]

        roundLoop: for r in 0..<rounds {
            var roundPoints: [String: Int] = [:]
            for q in 0..<perRound {
                let i = r * perRound + q
                guard answerKey.indices.contains(i) else { break }
                if Task.isCancelled { return }
                // Show the question with a fresh server timestamp; clear last reveal.
                await patch(gameID, [
                    "state": LiveGameState.question.rawValue,
                    "currentIndex": i,
                    "questionStartedAt": FieldValue.serverTimestamp(),
                    "revealCorrectIndex": FieldValue.delete(),
                ])
                // End the question as soon as EVERYONE has answered (no waiting out
                // the clock), otherwise cap at the timer + a small buzzer grace.
                await waitForAnswersOrTimeout(gameID: gameID, index: i,
                                              maxMs: duration + 600, expected: rosterRaw.count)
                if Task.isCancelled { return }
                // Tally this question; accumulate the round's points.
                let delta = await computeScores(gameID: gameID, index: i)
                for (pid, pts) in delta { roundPoints[pid, default: 0] += pts }
                await patch(gameID, [
                    "state": LiveGameState.reveal.rawValue,
                    "revealCorrectIndex": answerKey[i],
                ])
                await sleepMs(LiveGameRules.revealDurationMs)
            }
            if Task.isCancelled { return }

            // Round over → award the round to its top scorer (tie → no winner).
            let winner = roundWinner(roundPoints)
            if let winner { roundWins[winner, default: 0] += 1 }
            var fields: [String: Any] = ["roundWins": roundWins]
            fields["lastRoundWinnerID"] = winner ?? FieldValue.delete()
            await patch(gameID, fields)

            // Best-of-3: stop early once someone has clinched it.
            let clinched = (roundWins.values.max() ?? 0) >= LiveGameRules.roundsToWin
            if clinched || r == rounds - 1 { break roundLoop }

            // Otherwise show the round result, then start the next round.
            await patch(gameID, ["state": LiveGameState.roundBreak.rawValue])
            await sleepMs(LiveGameRules.roundBreakMs)
        }
        if Task.isCancelled { return }
        await patch(gameID, ["state": LiveGameState.final.rawValue])
        hostTask = nil
    }

    /// The round goes to its single top scorer; a tie awards no one (rare with
    /// millisecond timing), and the match's point tie-break still decides things.
    private func roundWinner(_ points: [String: Int]) -> String? {
        let maxP = points.values.max() ?? 0
        guard maxP > 0 else { return nil }
        let top = points.filter { $0.value == maxP }.map(\.key)
        return top.count == 1 ? top.first : nil
    }

    /// Award points for question `index`: correct answers earn points scaled by
    /// SERVER response time (fastest ≈ basePoints, slowest-correct ≈ half). Both
    /// the question start and each answer are server-stamped, so it's fair. Writes
    /// the new cumulative scores and RETURNS the points awarded this question (so
    /// the host can total each round).
    @discardableResult
    private func computeScores(gameID: String, index: Int) async -> [String: Int] {
        guard answerKey.indices.contains(index) else { return [:] }
        // The resolved server time the question went live.
        guard let gameSnap = try? await db.collection("liveGames").document(gameID).getDocument(),
              let startTS = gameSnap.data()?["questionStartedAt"] as? Timestamp else { return [:] }
        let start = startTS.dateValue()
        let correct = answerKey[index]
        let duration = Double(game?.questionDurationMs ?? LiveGameRules.questionDurationMs)

        let answersSnap = try? await db.collection("liveGames").document(gameID)
            .collection("answers").whereField("index", isEqualTo: index).getDocuments()

        // Accumulate onto the AUTHORITATIVE scores from the server doc (not the
        // possibly-stale local mirror), since the host is the only writer.
        var scores = LiveGameParse.intMap(gameSnap.data()?["scores"])
        var delta: [String: Int] = [:]
        for d in answersSnap?.documents ?? [] {
            let data = d.data()
            guard let pid = data["playerID"] as? String,
                  let choice = LiveGameParse.int(data["choiceIndex"]),
                  choice == correct else { continue }
            let answeredAt = (data["answeredAt"] as? Timestamp)?.dateValue() ?? start
            let responseMs = max(0, answeredAt.timeIntervalSince(start) * 1000)
            let pts = LiveGameRules.points(responseMs: responseMs, durationMs: duration)
            scores[pid, default: 0] += pts
            delta[pid, default: 0] += pts
        }
        await patch(gameID, ["scores": scores])
        return delta
    }

    private func sleepMs(_ ms: Int) async {
        try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
    }

    /// Wait until either EVERY player has answered question `index` (then a brief
    /// grace so the last tap registers) or the timer runs out — whichever first.
    /// Uses one answers-listener (not polling) and is cancellation-safe.
    private func waitForAnswersOrTimeout(gameID: String, index: Int, maxMs: Int, expected: Int) async {
        guard expected > 0 else { await sleepMs(maxMs); return }
        var finished = false
        var listener: ListenerRegistration?
        var continuation: CheckedContinuation<Void, Never>?
        func finish() {
            guard !finished else { return }
            finished = true
            listener?.remove(); listener = nil
            continuation?.resume(); continuation = nil
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                continuation = cont
                if finished { cont.resume(); continuation = nil; return }   // already cancelled
                listener = db.collection("liveGames").document(gameID)
                    .collection("answers").whereField("index", isEqualTo: index)
                    .addSnapshotListener { snap, _ in
                        let answered = Set((snap?.documents ?? []).compactMap { $0.data()["playerID"] as? String }).count
                        guard answered >= expected else { return }
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 600_000_000)   // brief grace
                            finish()
                        }
                    }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(maxMs) * 1_000_000)
                    finish()
                }
            }
        } onCancel: {
            Task { @MainActor in finish() }
        }
    }

    // MARK: In-app invites

    /// Listen for games my friends start that I'm invited to (in-app banner — a
    /// complement to the push invite). Lightweight: array-contains on my id.
    func startInvitesListener() {
        guard let myID, AuthManager.shared.isSignedIn, invitesListener == nil else { return }
        invitesListener = db.collection("liveGames")
            .whereField("invited", arrayContains: myID)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    let open: Set<String> = [LiveGameState.lobby.rawValue, LiveGameState.countdown.rawValue]
                    let cutoff = Date().addingTimeInterval(-30 * 60)   // ignore abandoned games
                    self.invites = (snap?.documents ?? []).compactMap { doc in
                        let d = doc.data()
                        guard let state = d["state"] as? String, open.contains(state),
                              let host = d["hostID"] as? String, host != myID else { return nil }
                        // Skip stale lobbies a host opened but never started.
                        if let created = (d["createdAt"] as? Timestamp)?.dateValue(), created < cutoff { return nil }
                        return LiveGameInvite(id: doc.documentID, hostName: d["hostName"] as? String ?? "חָבֵר")
                    }
                }
            }
    }

    func stopInvitesListener() {
        invitesListener?.remove(); invitesListener = nil
        invites = []
    }
    #endif

    // MARK: Rewards

    /// At the final screen, credit MY OWN wallet once (each device credits itself —
    /// respecting per-device wallet ownership). Everyone earns; the winner more.
    private func awardFinalRewardOnce() {
        guard !rewardedFinal, let myID else { return }
        rewardedFinal = true
        let isWinner = game?.matchWinnerID == myID
        let reward = isWinner ? LiveGameRules.winnerDiamonds : LiveGameRules.participationDiamonds
        if reward > 0 { ProgressStore.shared.addDiamonds(reward) }
    }
}

// MARK: - Parsing helpers

/// Firestore bridges numbers as NSNumber/Int64/Double depending on the path;
/// normalize them so model parsing is robust.
enum LiveGameParse {
    static func int(_ v: Any?) -> Int? {
        if let i = v as? Int { return i }
        if let i = v as? Int64 { return Int(i) }
        if let n = v as? NSNumber { return n.intValue }
        if let d = v as? Double { return Int(d) }
        return nil
    }

    static func intMap(_ v: Any?) -> [String: Int] {
        guard let raw = v as? [String: Any] else { return [:] }
        var out: [String: Int] = [:]
        for (k, val) in raw { if let i = int(val) { out[k] = i } }
        return out
    }
}

extension LiveGamePlayer {
    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String else { return nil }
        self.init(id: id,
                  name: data["name"] as? String ?? "",
                  character3DID: data["character3DID"] as? String,
                  score: 0)
    }
}

extension LiveGame {
    init?(from data: [String: Any]) {
        guard let id = data["id"] as? String,
              let hostID = data["hostID"] as? String,
              let stateRaw = data["state"] as? String,
              let state = LiveGameState(rawValue: stateRaw) else { return nil }
        self.id = id
        self.hostID = hostID
        self.hostName = data["hostName"] as? String ?? ""
        self.state = state
        self.topic = data["topic"] as? String ?? ""
        self.difficulty = data["difficulty"] as? String ?? ""
        self.totalQuestions = LiveGameParse.int(data["totalQuestions"]) ?? 0
        self.currentIndex = LiveGameParse.int(data["currentIndex"]) ?? -1
        self.questionDurationMs = LiveGameParse.int(data["questionDurationMs"]) ?? LiveGameRules.questionDurationMs
        self.questions = (data["questions"] as? [[String: Any]] ?? []).map {
            LiveGameQuestion(prompt: $0["prompt"] as? String ?? "",
                             options: $0["options"] as? [String] ?? [],
                             spoken: $0["spoken"] as? String)
        }
        self.revealCorrectIndex = LiveGameParse.int(data["revealCorrectIndex"])
        self.scores = LiveGameParse.intMap(data["scores"])
        self.invited = data["invited"] as? [String] ?? []
        self.totalRounds = LiveGameParse.int(data["totalRounds"]) ?? LiveGameRules.totalRounds
        self.roundQuestions = LiveGameParse.int(data["roundQuestions"]) ?? LiveGameRules.roundQuestions
        self.roundWins = LiveGameParse.intMap(data["roundWins"])
        self.lastRoundWinnerID = data["lastRoundWinnerID"] as? String
        #if canImport(FirebaseFirestore)
        self.questionStartedAt = (data["questionStartedAt"] as? Timestamp)?.dateValue()
        #else
        self.questionStartedAt = nil
        #endif
    }
}

// MARK: - Deep link

/// Turns a game id into a shareable / push deep link and back — mirrors
/// `FriendLink` (https Universal Link + `tofy://game?g=ID` custom scheme).
enum GameLink {
    static let host = JoinLink.host
    static let scheme = "tofy"

    static func url(forID id: String) -> String {
        var c = URLComponents()
        c.scheme = "https"; c.host = host; c.path = "/game"
        c.queryItems = [URLQueryItem(name: "g", value: id)]
        return c.url?.absoluteString ?? id
    }

    static func appURL(forID id: String) -> String { "\(scheme)://game?g=\(id)" }

    static func id(from raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let comps = URLComponents(string: s), comps.scheme != nil,
           let g = comps.queryItems?.first(where: { $0.name == "g" })?.value, !g.isEmpty {
            return g
        }
        return nil
    }

    static func isGameURL(_ url: URL) -> Bool {
        if url.scheme == scheme, url.host == "game" { return true }
        return (url.host == host || url.host == "www.\(host)") && url.path.hasPrefix("/game")
    }
}
