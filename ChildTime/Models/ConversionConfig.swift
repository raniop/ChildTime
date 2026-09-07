import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// The conversion "knobs" the founder turns in the admin dashboard
/// (`config/conversion`), read live by every device. Decides what a family
/// WITHOUT Tofy+ sees on the kid's home: how many locked worlds are shown and
/// how often they rotate, and whether any world is open as a free "guest".
/// Defaults match the server's CONVERSION_DEFAULTS so a device that never
/// reached Firestore behaves exactly like the fleet.
@MainActor
final class ConversionConfig: ObservableObject {
    static let shared = ConversionConfig()

    /// Locked worlds shown to a free child (the rest are hidden entirely).
    @Published private(set) var lockedShown: Int
    /// Days between rotations of the locked set.
    @Published private(set) var lockedRotateDays: Int
    /// Free "guest" worlds open for a free child (0 = none, Rani's default).
    @Published private(set) var guestWorlds: Int
    @Published private(set) var guestRotateDays: Int
    /// Fixed guest topics (raw values); empty = automatic by grade.
    @Published private(set) var guestTopics: [String]

    private let defaults = UserDefaults.standard
    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    private init() {
        let d = UserDefaults.standard
        lockedShown = d.object(forKey: "conv.lockedShown") as? Int ?? 5
        lockedRotateDays = d.object(forKey: "conv.lockedRotateDays") as? Int ?? 3
        guestWorlds = d.object(forKey: "conv.guestWorlds") as? Int ?? 0
        guestRotateDays = d.object(forKey: "conv.guestRotateDays") as? Int ?? 7
        guestTopics = d.stringArray(forKey: "conv.guestTopics") ?? []
    }

    /// Idempotent; safe to call from every screen that cares.
    func start() {
        #if canImport(FirebaseFirestore)
        guard listener == nil, !AppInfo.isDemoRun else { return }
        listener = Firestore.firestore().collection("config").document("conversion")
            .addSnapshotListener { [weak self] doc, _ in
                guard let self, let data = doc?.data() else { return }
                Task { @MainActor in self.apply(data) }
            }
        #endif
    }

    private func apply(_ data: [String: Any]) {
        func int(_ key: String, _ current: Int) -> Int {
            if let n = data[key] as? Int { return max(0, n) }
            if let n = data[key] as? Double { return max(0, Int(n)) }
            return current
        }
        lockedShown = int("lockedShown", lockedShown)
        lockedRotateDays = max(1, int("lockedRotateDays", lockedRotateDays))
        guestWorlds = int("guestWorlds", guestWorlds)
        guestRotateDays = max(1, int("guestRotateDays", guestRotateDays))
        guestTopics = (data["guestTopics"] as? [String]) ?? guestTopics
        defaults.set(lockedShown, forKey: "conv.lockedShown")
        defaults.set(lockedRotateDays, forKey: "conv.lockedRotateDays")
        defaults.set(guestWorlds, forKey: "conv.guestWorlds")
        defaults.set(guestRotateDays, forKey: "conv.guestRotateDays")
        defaults.set(guestTopics, forKey: "conv.guestTopics")
    }
}

/// Which worlds suit a child of a given school grade (0 = גן). Packs carry
/// their own range; the base worlds are pinned here. Used to pick the locked
/// and guest worlds a free child is shown — a kindergartner is never teased
/// with a history world they could not play yet.
enum WorldSuitability {
    static func minGrade(for topic: Topic) -> Int {
        if let pack = topic.pack { return pack.grades.lowerBound }
        switch topic {
        case .reading, .geography: return 1
        case .history, .money: return 2
        default: return 0
        }
    }
    static func suits(_ topic: Topic, grade: Int) -> Bool { grade >= minGrade(for: topic) }
}
