import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// 🔄 "There is a newer Tofy" — read live from `config/appUpdate`, which the
/// founder sets from the admin after every upload.
///
/// Why a config document and not Apple's lookup API: the lookup only knows what
/// is already on the App Store, so it is blind to TestFlight and blind during the
/// days a release sits in review — exactly the window where telling a parent
/// "there is a fix waiting" matters most. A number we write ourselves covers both.
///
/// Two thresholds, deliberately separate:
/// • `latestBuild` — what we would LIKE everyone on. Shows a dismissible notice.
/// • `minBuild` — below this the app cannot talk to the server correctly any
///   more, so it blocks. Left at 0 until a server change actually breaks an old
///   client; a blocking screen is not something to hand out casually.
///
/// Defaults are "nothing to say", so a device that never reached Firestore — or
/// a demo run, or an offline first launch — behaves exactly as before.
@MainActor
final class AppUpdateConfig: ObservableObject {
    static let shared = AppUpdateConfig()

    @Published private(set) var latestBuild: Int
    @Published private(set) var minBuild: Int
    /// A kill switch: one toggle silences every update screen fleet-wide without
    /// a release, in case the numbers are ever set wrong.
    @Published private(set) var enabled: Bool
    /// What the parent is shown about the build they do NOT have yet.
    ///
    /// These cannot come from `WhatsNewContent`: that file ships INSIDE a build
    /// and describes it, so an installed app has no idea what the next one holds.
    /// The admin writes them beside the numbers. Empty is fine — then the sheet
    /// is just the offer, without a list.
    @Published private(set) var versionName: String
    @Published private(set) var notes: [String]
    /// `notesByLang` {"he": […], "en": […], "ru": […], "ar": […]}. The legacy
    /// `notes` array is Hebrew, so it is only ever shown to a Hebrew app —
    /// a Russian parent sees their own lines or none, never Hebrew.
    @Published private(set) var notesByLang: [String: [String]]

    /// The lines for the app's current language.
    var displayNotes: [String] {
        let lang = LanguageStore.shared.current
        if let own = notesByLang[lang.rawValue], !own.isEmpty { return own }
        return lang == .he ? notes : []
    }

    /// The last build the parent said "later" to. Asking again on the same build
    /// is nagging; asking again on the NEXT one is the point of the feature.
    @AppStorageBacked("update.dismissedBuild") private var dismissedBuild: Int = 0

    private let defaults = UserDefaults.standard
    #if canImport(FirebaseFirestore)
    private var listener: ListenerRegistration?
    #endif

    private init() {
        let d = UserDefaults.standard
        latestBuild = d.object(forKey: "update.latestBuild") as? Int ?? 0
        minBuild    = d.object(forKey: "update.minBuild") as? Int ?? 0
        enabled     = d.object(forKey: "update.enabled") as? Bool ?? true
        versionName = d.string(forKey: "update.versionName") ?? ""
        notes       = d.stringArray(forKey: "update.notes") ?? []
        notesByLang = d.dictionary(forKey: "update.notesByLang") as? [String: [String]] ?? [:]
    }

    /// This build, as a number. `CFBundleVersion` is a string by definition and a
    /// malformed one must never read as "older than everything" — that would show
    /// a blocking screen to a device that is perfectly current.
    static var installedBuild: Int { Int(AppInfo.build) ?? Int.max }

    enum State: Equatable {
        case none
        /// A newer build exists. Dismissible, and remembered per build.
        case recommended(build: Int)
        /// This build can no longer be trusted against the server. Blocks.
        case required(build: Int)
    }

    var state: State {
        guard enabled, !AppInfo.isDemoRun else { return .none }
        let mine = Self.installedBuild
        if minBuild > 0, mine < minBuild { return .required(build: minBuild) }
        if latestBuild > mine, dismissedBuild < latestBuild { return .recommended(build: latestBuild) }
        return .none
    }

    /// "Later" — quiet until the NEXT build, never for this one again.
    func dismissCurrent() {
        guard case .recommended(let b) = state else { return }
        dismissedBuild = b
        objectWillChange.send()
    }

    /// The App Store page for Tofy. Parent-facing only: a kid screen never leaves
    /// the app, which is what 1.3 of the Kids Category requires and what a child
    /// could not finish anyway without an Apple ID password.
    static let storeURL = URL(string: "https://apps.apple.com/app/id6773805449")!

    /// Idempotent; safe to call from every screen that cares.
    func start() {
        #if canImport(FirebaseFirestore)
        guard listener == nil, !AppInfo.isDemoRun else { return }
        listener = Firestore.firestore().collection("config").document("appUpdate")
            .addSnapshotListener { [weak self] doc, _ in
                guard let self, let data = doc?.data() else { return }
                Task { @MainActor in self.apply(data) }
            }
        #endif
    }

    private func apply(_ data: [String: Any]) {
        if let v = data["latestBuild"] as? Int { latestBuild = v; defaults.set(v, forKey: "update.latestBuild") }
        if let v = data["minBuild"] as? Int { minBuild = v; defaults.set(v, forKey: "update.minBuild") }
        if let v = data["enabled"] as? Bool { enabled = v; defaults.set(v, forKey: "update.enabled") }
        if let v = data["version"] as? String { versionName = v; defaults.set(v, forKey: "update.versionName") }
        if let v = data["notes"] as? [String] { notes = v; defaults.set(v, forKey: "update.notes") }
        if let v = data["notesByLang"] as? [String: [String]] { notesByLang = v; defaults.set(v, forKey: "update.notesByLang") }
    }

    #if DEBUG
    /// Demo screens and tests only.
    func setForTesting(latest: Int, min: Int = 0, enabled: Bool = true,
                       version: String = "", notes: [String] = []) {
        latestBuild = latest; minBuild = min; self.enabled = enabled
        versionName = version; self.notes = notes; notesByLang = [:]
    }
    func resetDismissedForTesting() { dismissedBuild = 0 }
    #endif
}

/// A tiny `@AppStorage` stand-in usable inside a plain class.
@propertyWrapper
struct AppStorageBacked<T> {
    let key: String
    let initial: T
    init(_ key: String, default initial: T) { self.key = key; self.initial = initial }
    init(wrappedValue: T, _ key: String) { self.key = key; self.initial = wrappedValue }
    var wrappedValue: T {
        get { UserDefaults.standard.object(forKey: key) as? T ?? initial }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
