import Foundation
import Combine

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// A child's PUBLIC mini-card for the friends leaderboard. Intentionally minimal
/// — first name, chosen character, and star count only. No chat, no photos, no
/// contact info, no last name.
struct FriendCard: Codable, Identifiable, Equatable {
    var id: String                 // childID
    var name: String
    var character3DID: String?
    var stars: Int
    var code: String               // short friend code (for QR / invite link)
    var ownerUID: String = ""      // the device uid that owns this card (write gate)
    var friendIDs: [String] = []   // friends THIS child added
    var hiddenIDs: [String] = []   // friends removed by this child / their parent
    var updatedAt: Date = .now

    var character: Character3D { Character3DCatalog.find(character3DID) }
}

extension FriendCard {
    enum CodingKeys: String, CodingKey {
        case id, name, character3DID, stars, code, ownerUID, friendIDs, hiddenIDs, updatedAt
    }
    // Resilient decode: cards on the server may omit fields (e.g. friendIDs /
    // hiddenIDs are stripped on upsert; older docs lack ownerUID). Swift's default
    // values do NOT apply to Decodable, so decode each tolerantly — otherwise a
    // card with a missing field silently fails to decode ("no card matches").
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(String.self, forKey: .id)
        name          = (try? c.decode(String.self, forKey: .name)) ?? ""
        character3DID = try? c.decodeIfPresent(String.self, forKey: .character3DID)
        stars         = (try? c.decode(Int.self, forKey: .stars)) ?? 0
        code          = (try? c.decode(String.self, forKey: .code)) ?? ""
        ownerUID      = (try? c.decode(String.self, forKey: .ownerUID)) ?? ""
        friendIDs     = (try? c.decode([String].self, forKey: .friendIDs)) ?? []
        hiddenIDs     = (try? c.decode([String].self, forKey: .hiddenIDs)) ?? []
        updatedAt     = (try? c.decode(Date.self, forKey: .updatedAt)) ?? .distantPast
    }
}

/// Backs the kid-friendly friends leaderboard. Each child keeps a public
/// `friendCards/{childID}` doc; friendship is mutual-by-union: A adds B to A's
/// list, and B sees A because B queries the cards that array-contain B. Removal
/// hides the edge from the remover's side. No cross-household writes, no Cloud
/// Functions — every device only writes its OWN card.
@MainActor
final class FriendsManager: ObservableObject {
    static let shared = FriendsManager()

    /// Me + my friends, sorted by stars (desc) — the leaderboard rows.
    @Published private(set) var leaderboard: [FriendCard] = []
    @Published private(set) var myCode: String = ""
    @Published private(set) var isLoading = false
    @Published var lastError: String?
    /// Set from an incoming friend Universal Link; consumed by the leaderboard.
    @Published var pendingFriendCode: String?
    /// The friend just added — so the UI can celebrate (confetti + their character).
    @Published var lastAddedFriend: FriendCard?

    private let defaults = UserDefaults.standard
    private var myID: String? { ProfileStore.shared.activeID?.uuidString }

    private init() {}

    private func log(_ s: String) { print("[Friends] \(s)") }

    /// Sample board for screenshots (DEMO_SCREEN). Never used in production.
    func seedDemo() {
        let meID = ProfileStore.shared.activeID?.uuidString ?? "me"
        leaderboard = [
            FriendCard(id: "f1", name: "יוֹאָב", character3DID: "lion",    stars: 1890, code: "AAA"),
            FriendCard(id: "f2", name: "מָאיָה", character3DID: "panda",   stars: 1530, code: "BBB"),
            FriendCard(id: meID, name: "דָּנָה", character3DID: "unicorn", stars: 1240, code: "ABC234"),
            FriendCard(id: "f3", name: "אִיתַי", character3DID: "dragon",  stars: 980,  code: "CCC"),
            FriendCard(id: "f4", name: "נֹעָה",  character3DID: "fox",     stars: 640,  code: "DDD"),
            FriendCard(id: "f5", name: "עֹמֶר",  character3DID: "tiger",   stars: 410,  code: "EEE"),
        ].sorted { $0.stars > $1.stars }
        myCode = "ABC234"
    }

    // MARK: - My code / invite link

    /// Stable per-child friend code, derived deterministically from the child id
    /// (the first 6 UUID bytes → an unambiguous alphabet), so it's the SAME code
    /// every launch and even after a reinstall.
    private func codeForActiveChild() -> String {
        guard let id = myID else { return "" }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") // no ambiguous chars
        let hex = id.replacingOccurrences(of: "-", with: "")
        guard hex.count >= 12 else { return "" }
        var c = ""
        for i in stride(from: 0, to: 12, by: 2) {
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end = hex.index(start, offsetBy: 2)
            let byte = Int(hex[start..<end], radix: 16) ?? 0
            c.append(alphabet[byte % alphabet.count])
        }
        return c
    }

    var myInviteURL: String? {
        guard !myCode.isEmpty else { return nil }
        return FriendLink.url(forCode: myCode)
    }

    // MARK: - Public API

    /// Push my current card (name, character, stars, code) and reload the board.
    func refresh() async {
        // The code is LOCAL (derived from the child id) — always show it so the
        // QR + share link work even offline / before sign-in.
        guard let id = myID else { return }
        myCode = codeForActiveChild()
        #if canImport(FirebaseFirestore)
        guard AuthManager.shared.isSignedIn else { return }
        isLoading = true
        defer { isLoading = false }
        await upsertMyCard(id: id)
        await loadLeaderboard(myID: id)
        #endif
    }

    /// Add a friend by their code (typed, scanned, or from an invite link).
    @discardableResult
    func addFriend(code raw: String) async -> Bool {
        #if canImport(FirebaseFirestore)
        guard let myID else { lastError = "אֵין פְּרוֹפִיל פָּעִיל"; return false }
        guard AuthManager.shared.isSignedIn else {
            lastError = "צָרִיךְ לְהִתְחַבֵּר לְחֶשְׁבּוֹן כְּדֵי לְהוֹסִיף חֲבֵרִים"
            return false
        }
        let code = FriendLink.code(from: raw).uppercased()
        log("addFriend raw=\(raw) → code=\(code), myCode=\(myCode), myID=\(myID)")
        guard !code.isEmpty, code != myCode else {
            lastError = code == myCode ? "זֶה הַקּוֹד שֶׁלְּךָ 🙂" : "קוֹד לֹא תָּקִין"
            log("rejected: \(lastError ?? "")")
            return false
        }
        do {
            let snap = try await db.collection("friendCards")
                .whereField("code", isEqualTo: code).limit(to: 1).getDocuments()
            log("query code=\(code) → \(snap.documents.count) result(s)")
            guard let doc = snap.documents.first, let card = Self.decode(doc.data()) else {
                lastError = "לֹא מָצָאנוּ חָבֵר עִם הַקּוֹד הַזֶּה"
                log("no card matches code=\(code)")
                return false
            }
            guard card.id != myID else { lastError = "זֶה אַתָּה 🙂"; return false }
            log("found friend id=\(card.id) name=\(card.name); writing to my card…")
            // Add to MY card's friend list (+ un-hide if previously removed).
            // Include ownerUID so the write passes the owner gate even if this is
            // the first write to my card.
            try await db.collection("friendCards").document(myID).setData([
                "ownerUID": AuthManager.shared.userID ?? "",
                "friendIDs": FieldValue.arrayUnion([card.id]),
                "hiddenIDs": FieldValue.arrayRemove([card.id]),
            ], merge: true)
            log("✅ write OK — added \(card.id)")
            lastError = nil
            lastAddedFriend = card
            await loadLeaderboard(myID: myID)
            return true
        } catch {
            lastError = error.localizedDescription
            log("❌ FIRESTORE ERROR: \((error as NSError).domain) #\((error as NSError).code): \(error.localizedDescription)")
            return false
        }
        #else
        return false
        #endif
    }

    /// Remove a friend from THIS child's board (mutual: hides the edge for me).
    func removeFriend(_ friendID: String, forChild childID: String? = nil) async {
        #if canImport(FirebaseFirestore)
        let id = childID ?? myID
        guard let id else { return }
        try? await db.collection("friendCards").document(id).setData([
            "friendIDs": FieldValue.arrayRemove([friendID]),
            "hiddenIDs": FieldValue.arrayUnion([friendID]),
        ], merge: true)
        if id == myID { await loadLeaderboard(myID: id) }
        #endif
    }

    // MARK: - Firestore

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }

    // Live listeners: my card + the inbound query (who added me) + one per friend.
    private var myCardListener: ListenerRegistration?
    private var inboundListener: ListenerRegistration?
    private var friendListeners: [String: ListenerRegistration] = [:]
    private var cardCache: [String: FriendCard] = [:]

    /// Start real-time updates: upsert my card, then listen so the board reflects
    /// new friends + friends' star changes instantly on every device.
    func startLive() async {
        guard let id = myID, AuthManager.shared.isSignedIn else { return }
        myCode = codeForActiveChild()
        await upsertMyCard(id: id)
        stopLive()

        myCardListener = db.collection("friendCards").document(id)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if let c = Self.decode(snap?.data() ?? [:]) { self.cardCache[id] = c }
                    self.rebuild(myID: id)
                }
            }
        inboundListener = db.collection("friendCards")
            .whereField("friendIDs", arrayContains: id)
            .addSnapshotListener { [weak self] snap, _ in
                Task { @MainActor in
                    guard let self else { return }
                    for d in snap?.documents ?? [] { if let c = Self.decode(d.data()) { self.cardCache[d.documentID] = c } }
                    self.rebuild(myID: id)
                }
            }
    }

    func stopLive() {
        myCardListener?.remove(); myCardListener = nil
        inboundListener?.remove(); inboundListener = nil
        friendListeners.values.forEach { $0.remove() }
        friendListeners.removeAll()
    }

    /// Recompute my friend set from the cache, (un)subscribe to each friend's card
    /// for live stars, and publish the sorted board.
    private func rebuild(myID: String) {
        guard let me = cardCache[myID] else { return }
        var ids = Set(me.friendIDs)
        for (fid, c) in cardCache where c.friendIDs.contains(myID) { ids.insert(fid) }
        ids.subtract(me.hiddenIDs); ids.remove(myID)

        // Subscribe to any new friends; drop ones no longer friends.
        for fid in ids where friendListeners[fid] == nil {
            friendListeners[fid] = db.collection("friendCards").document(fid)
                .addSnapshotListener { [weak self] snap, _ in
                    Task { @MainActor in
                        guard let self else { return }
                        if let c = Self.decode(snap?.data() ?? [:]) { self.cardCache[fid] = c; self.publish(myID: myID) }
                    }
                }
        }
        for (fid, l) in friendListeners where !ids.contains(fid) { l.remove(); friendListeners[fid] = nil }
        publish(myID: myID)
    }

    private func publish(myID: String) {
        guard let me = cardCache[myID] else { return }
        var ids = Set(me.friendIDs)
        for (fid, c) in cardCache where c.friendIDs.contains(myID) { ids.insert(fid) }
        ids.subtract(me.hiddenIDs); ids.remove(myID)
        var cards = [me]
        for fid in ids { if let c = cardCache[fid] { cards.append(c) } }
        leaderboard = cards.sorted { $0.stars > $1.stars }
    }

    private func upsertMyCard(id: String) async {
        let profile = ProfileStore.shared.active
        let card = FriendCard(
            id: id,
            name: profile?.name ?? "",
            character3DID: profile?.character3DID,
            stars: ProgressStore.shared.stars,
            code: myCode,
            ownerUID: AuthManager.shared.userID ?? ""
        )
        guard let data = try? JSONEncoder.firestore.encode(card),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        // Don't clobber friendIDs/hiddenIDs we may not have loaded — only the card facts.
        var fields = dict
        fields["friendIDs"] = nil
        fields["hiddenIDs"] = nil
        fields = fields.compactMapValues { $0 }
        do {
            try await db.collection("friendCards").document(id).setData(fields, merge: true)
            log("✅ upsertMyCard OK id=\(id) code=\(myCode) ownerUID=\(card.ownerUID)")
        } catch {
            log("❌ upsertMyCard FAILED: \((error as NSError).domain) #\((error as NSError).code): \(error.localizedDescription)")
        }
    }

    // MARK: - Live diagnostic (DEMO only)

    /// Signs in anonymously and exercises the full friend flow against the LIVE
    /// Firestore + deployed rules, logging each step — to reveal a permission
    /// block. Creates a throwaway "friend" card owned by this device.
    func runDiagnostic() async {
        log("=== DIAGNOSTIC START ===")
        AuthManager.shared.signInAnonymouslyIfNeeded()
        for _ in 0..<25 where !AuthManager.shared.isSignedIn {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        guard let uid = AuthManager.shared.userID else { log("❌ not signed in after wait"); return }
        log("signed in uid=\(uid)")
        let myID = ProfileStore.shared.activeID?.uuidString ?? "diag-me"
        myCode = "MYCODE"

        // 1) write my card
        await diagWrite(id: myID, code: "MYCODE", uid: uid, label: "my card")
        // 2) write a throwaway friend card (owned by me so the rule passes)
        let friendID = "diag-friend"
        await diagWrite(id: friendID, code: "FRND01", uid: uid, label: "friend card")
        // 3) query by the friend's code
        do {
            let snap = try await db.collection("friendCards").whereField("code", isEqualTo: "FRND01").getDocuments()
            log("3) query FRND01 → \(snap.documents.count) doc(s)")
        } catch {
            log("3) ❌ QUERY FAILED: \((error as NSError).code) \(error.localizedDescription)")
        }
        // 4) add the friend
        let ok = await addFriend(code: "FRND01")
        log("4) addFriend(FRND01) → \(ok) (lastError=\(lastError ?? "nil"))")
        log("=== DIAGNOSTIC END ===")
    }

    private func diagWrite(id: String, code: String, uid: String, label: String) async {
        do {
            try await db.collection("friendCards").document(id).setData([
                "id": id, "name": "Diag", "stars": 50, "code": code, "ownerUID": uid,
            ], merge: true)
            log("write \(label) (\(id)) → ✅")
        } catch {
            log("write \(label) (\(id)) → ❌ \((error as NSError).code) \(error.localizedDescription)")
        }
    }

    /// Load my friends (the ones I added + the ones who added me) minus hidden,
    /// fetch their cards, and build the sorted leaderboard including me.
    private func loadLeaderboard(myID: String) async {
        guard let meDoc = try? await db.collection("friendCards").document(myID).getDocument(),
              let me = Self.decode(meDoc.data() ?? [:]) else { return }

        var friendIDs = Set(me.friendIDs)
        // People who added me (mutual visibility) — they list me in `friendIDs`.
        if let inbound = try? await db.collection("friendCards")
            .whereField("friendIDs", arrayContains: myID).getDocuments() {
            for d in inbound.documents { friendIDs.insert(d.documentID) }
        }
        friendIDs.subtract(me.hiddenIDs)
        friendIDs.remove(myID)

        var cards: [FriendCard] = [me]
        for fid in friendIDs {
            if let doc = try? await db.collection("friendCards").document(fid).getDocument(),
               let card = Self.decode(doc.data() ?? [:]) {
                cards.append(card)
            }
        }
        leaderboard = cards.sorted { $0.stars > $1.stars }
    }

    /// Friends of a specific child — for the PARENT dashboard (see + remove).
    func friends(ofChild childID: String) async -> [FriendCard] {
        var ids = Set<String>()
        if let doc = try? await db.collection("friendCards").document(childID).getDocument(),
           let card = Self.decode(doc.data() ?? [:]) {
            ids.formUnion(card.friendIDs)
            ids.subtract(card.hiddenIDs)
        }
        if let inbound = try? await db.collection("friendCards")
            .whereField("friendIDs", arrayContains: childID).getDocuments() {
            for d in inbound.documents { ids.insert(d.documentID) }
        }
        ids.remove(childID)
        var out: [FriendCard] = []
        for fid in ids {
            if let doc = try? await db.collection("friendCards").document(fid).getDocument(),
               let card = Self.decode(doc.data() ?? [:]) { out.append(card) }
        }
        return out.sorted { $0.stars > $1.stars }
    }

    private static func decode(_ raw: [String: Any]) -> FriendCard? {
        guard !raw.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: raw) else { return nil }
        return try? JSONDecoder.firestore.decode(FriendCard.self, from: data)
    }
    #endif
}
