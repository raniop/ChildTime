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
