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
    var friendIDs: [String] = []   // friends THIS child added
    var hiddenIDs: [String] = []   // friends removed by this child / their parent
    var updatedAt: Date = .now

    var character: Character3D { Character3DCatalog.find(character3DID) }
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

    private let defaults = UserDefaults.standard
    private var myID: String? { ProfileStore.shared.activeID?.uuidString }

    private init() {}

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
        guard !code.isEmpty, code != myCode else {
            lastError = code == myCode ? "זֶה הַקּוֹד שֶׁלְּךָ 🙂" : "קוֹד לֹא תָּקִין"
            return false
        }
        do {
            let snap = try await db.collection("friendCards")
                .whereField("code", isEqualTo: code).limit(to: 1).getDocuments()
            guard let doc = snap.documents.first, let card = Self.decode(doc.data()) else {
                lastError = "לֹא מָצָאנוּ חָבֵר עִם הַקּוֹד הַזֶּה"
                return false
            }
            guard card.id != myID else { lastError = "זֶה אַתָּה 🙂"; return false }
            // Add to MY card's friend list (+ un-hide if previously removed).
            try await db.collection("friendCards").document(myID).setData([
                "friendIDs": FieldValue.arrayUnion([card.id]),
                "hiddenIDs": FieldValue.arrayRemove([card.id]),
            ], merge: true)
            lastError = nil
            await loadLeaderboard(myID: myID)
            return true
        } catch {
            lastError = error.localizedDescription
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

    private func upsertMyCard(id: String) async {
        let profile = ProfileStore.shared.active
        let card = FriendCard(
            id: id,
            name: profile?.name ?? "",
            character3DID: profile?.character3DID,
            stars: ProgressStore.shared.stars,
            code: myCode
        )
        guard let data = try? JSONEncoder.firestore.encode(card),
              let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
        // Don't clobber friendIDs/hiddenIDs we may not have loaded — only the card facts.
        var fields = dict
        fields["friendIDs"] = nil
        fields["hiddenIDs"] = nil
        fields = fields.compactMapValues { $0 }
        try? await db.collection("friendCards").document(id).setData(fields, merge: true)
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
