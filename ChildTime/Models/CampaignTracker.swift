import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 📣 First-party funnel for admin campaigns (no third-party analytics — Kids
/// Category): a tapped push carries `campaignID`; every later step (page,
/// purchase started, purchased, sent to child) bumps ONE counter on
/// `campaigns/{id}.stats` — the only field the rules let the app touch.
/// Attribution lives one hour, on this device only.
@MainActor
final class CampaignTracker: ObservableObject {
    static let shared = CampaignTracker()

    /// A pack the user should land on (set by a tapped push; consumed by the
    /// parent home / kid home when they appear).
    @Published var pendingPackID: String? = nil
    /// A screen to open ("tofyPlus" → the paywall on a parent device).
    @Published var pendingScreen: String? = nil
    /// The campaign to show as an in-app pop-up right now (loaded once per launch).
    @Published var popup: Campaign? = nil
    private(set) var popupChecked = false

    /// Once per launch: find the newest unseen campaign for this device.
    func checkPopup(role: String, profiles: [Profile], premium: Bool) {
        guard !popupChecked else { return }
        popupChecked = true
        Task { @MainActor in
            if let c = await fetchPopup(role: role, profiles: profiles, premium: premium) {
                markPopupSeen(c.id)
                record("popup", campaignID: c.id)
                popup = c
            }
        }
    }

    /// Demo harness.
    func seedDemoPopup(_ c: Campaign) { popupChecked = true; popup = c }

    private let attributionKey = "packs.attributionCampaign"
    private let attributionAtKey = "packs.attributionCampaignAt"

    private init() {}

    /// The campaign a purchase in the next hour should be credited to.
    var currentCampaignID: String? {
        let at = UserDefaults.standard.double(forKey: attributionAtKey)
        guard at > 0, Date().timeIntervalSince1970 - at < 3600 else { return nil }
        return UserDefaults.standard.string(forKey: attributionKey)
    }

    /// A campaign push was TAPPED (or its in-app pop-up was acted on).
    func handleOpen(_ info: [AnyHashable: Any]) {
        guard let id = info["campaignID"] as? String, !id.isEmpty else { return }
        UserDefaults.standard.set(id, forKey: attributionKey)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: attributionAtKey)
        record("opened", campaignID: id)
        switch info["action"] as? String ?? "" {
        case "pack":
            if let pid = info["packID"] as? String, !pid.isEmpty { pendingPackID = pid }
        case "tofyPlus":   pendingScreen = "tofyPlus"
        default: break
        }
    }

    /// Bump one funnel counter on the attributed campaign (if any).
    func record(_ event: String) {
        guard let id = currentCampaignID else { return }
        record(event, campaignID: id)
    }

    func record(_ event: String, campaignID: String) {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync, campaignID != "test" else { return }
        Firestore.firestore().collection("campaigns").document(campaignID)
            .updateData(["stats.\(event)": FieldValue.increment(Int64(1))]) { err in
                if let err { TofyLink("campaign \(campaignID.prefix(8)) \(event) not counted: \(err.localizedDescription)") }
            }
        #endif
    }
}

// MARK: - 📣 In-app pop-up (phase 4)

/// A sent campaign as the app sees it (campaigns/{id}, written by the admin
/// functions). Only the fields the pop-up needs.
struct Campaign: Identifiable, Equatable {
    struct Action: Equatable { var type: String; var packID: String }
    struct Audience: Equatable { var roles: [String]; var gradeMin: Int; var gradeMax: Int; var premium: String; var topics: [String] }
    let id: String
    var title: String
    var body: String
    var emoji: String
    var imageURL: String
    var childTitle: String
    var childBody: String
    var action: Action
    var audience: Audience
    var sentAt: Double

    init?(id: String, data: [String: Any]) {
        guard (data["status"] as? String) == "sent", (data["showPopup"] as? Bool) ?? true else { return nil }
        self.id = id
        title = data["title"] as? String ?? ""
        body = data["body"] as? String ?? ""
        emoji = data["emoji"] as? String ?? ""
        imageURL = data["imageURL"] as? String ?? ""
        childTitle = data["childTitle"] as? String ?? ""
        childBody = data["childBody"] as? String ?? ""
        let a = data["action"] as? [String: Any] ?? [:]
        action = Action(type: a["type"] as? String ?? "none", packID: a["packID"] as? String ?? "")
        let au = data["audience"] as? [String: Any] ?? [:]
        audience = Audience(roles: au["roles"] as? [String] ?? ["parents"],
                            gradeMin: (au["gradeMin"] as? Int) ?? 0, gradeMax: (au["gradeMax"] as? Int) ?? 6,
                            premium: au["premium"] as? String ?? "any", topics: au["topics"] as? [String] ?? [])
        sentAt = (data["sentAt"] as? Double) ?? (data["scheduledAt"] as? Double) ?? 0
        guard !title.isEmpty else { return nil }
    }

    /// Demo / preview.
    init(sampleFor packID: String) {
        id = "sample"; title = "חדש בטופי: עולם הכדורגל"; emoji = "⚽"; imageURL = ""
        body = "עזרו לילד שלכם להכיר שחקנים, קבוצות, תחרויות ועובדות מעניינות מעולם הכדורגל בישראל ובעולם."
        childTitle = "רוצה ללמוד על כדורגל?"; childBody = "שחקנים, קבוצות, תחרויות ועובדות מפתיעות — בקש מאבא או אמא"
        action = Action(type: "pack", packID: packID)
        audience = Audience(roles: ["parents", "children"], gradeMin: 0, gradeMax: 6, premium: "any", topics: [])
        sentAt = Date().timeIntervalSince1970 * 1000
    }

    /// Does this device/profile belong to the audience? Mirrors the server's
    /// resolveAudience closely enough for a pop-up (the push already went to
    /// the right people; this only keeps the pop-up from showing on a device
    /// the campaign never meant).
    func matches(role: String, profiles: [Profile], premium: Bool) -> Bool {
        guard audience.roles.contains(role == "child" ? "children" : "parents") else { return false }
        if audience.premium == "with", !premium { return false }
        if audience.premium == "without", premium { return false }
        if action.type == "pack", !action.packID.isEmpty, !profiles.isEmpty,
           profiles.allSatisfy({ $0.ownedPacks.contains(action.packID) }) { return false }
        let narrowed = audience.gradeMin > 0 || audience.gradeMax < 6 || !audience.topics.isEmpty
        guard narrowed, !profiles.isEmpty else { return true }
        return profiles.contains { p in
            let g = p.effectiveGrade
            if g < audience.gradeMin || g > audience.gradeMax { return false }
            if !audience.topics.isEmpty {
                let mine = Set(p.interests + p.enabledTopics.map(\.rawValue) + p.difficultyByTopic.keys)
                if !audience.topics.contains(where: { mine.contains($0) }) { return false }
            }
            return true
        }
    }
}

extension CampaignTracker {
    private var seenKey: String { "campaigns.seen" }
    private var sinceKey: String { "campaigns.since" }

    /// Campaigns sent BEFORE this install first looked are never shown — a new
    /// family shouldn't open Tofy to a month of old news.
    private var since: Double {
        let v = UserDefaults.standard.double(forKey: sinceKey)
        if v > 0 { return v }
        let now = Date().timeIntervalSince1970 * 1000
        UserDefaults.standard.set(now, forKey: sinceKey)
        return now
    }

    func markPopupSeen(_ id: String) {
        var seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        seen.insert(id)
        UserDefaults.standard.set(Array(seen.suffix(200)), forKey: seenKey)
    }

    /// The newest sent campaign this device hasn't shown yet (or nil). One
    /// Firestore range query, no composite index; filtered client-side.
    func fetchPopup(role: String, profiles: [Profile], premium: Bool) async -> Campaign? {
        #if canImport(FirebaseFirestore)
        guard !HouseholdManager.skipsCloudSync else { return nil }
        let seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        let floor = max(since, Date().timeIntervalSince1970 * 1000 - 14 * 86_400_000)   // ≤ 2 weeks old
        do {
            let snap = try await Firestore.firestore().collection("campaigns")
                .whereField("sentAt", isGreaterThanOrEqualTo: floor)
                .order(by: "sentAt", descending: true).limit(to: 10).getDocuments()
            for doc in snap.documents where !seen.contains(doc.documentID) {
                if let c = Campaign(id: doc.documentID, data: doc.data()),
                   c.matches(role: role, profiles: profiles, premium: premium) { return c }
            }
        } catch { TofyLink("campaign popup fetch failed: \(error.localizedDescription)") }
        #endif
        return nil
    }

    /// The pop-up's button was tapped — same attribution + landing as a push tap.
    func popupTapped(_ c: Campaign) {
        handleOpen(["campaignID": c.id, "action": c.action.type, "packID": c.action.packID])
    }
}
