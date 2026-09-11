import SwiftUI
import Combine

/// 🌍 The languages Tofy speaks.
///
/// Rani (2026-09-11): "בחירת שפות אמיתית — כמו כל אפליקציה אמיתית שיכולה להחליף
/// שפה". A language here is more than the strings: it carries the layout
/// direction, the read-aloud voice and the region whose curriculum, currency
/// and grade names come with it.
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case he
    case en

    var id: String { rawValue }

    /// Written in the language itself — a picker must be readable by someone
    /// who doesn't know the current one.
    var nativeName: String {
        switch self {
        case .he: return "עברית"
        case .en: return "English"
        }
    }

    /// The region whose content, currency and school grades come with it.
    var regionCode: String {
        switch self {
        case .he: return "IL"
        case .en: return "US"
        }
    }

    var locale: Locale { Locale(identifier: "\(rawValue)_\(regionCode)") }

    var layoutDirection: LayoutDirection {
        switch self {
        case .he: return .rightToLeft
        case .en: return .leftToRight
        }
    }

    /// BCP-47 code for AVSpeechSynthesisVoice.
    var speechCode: String { "\(rawValue)-\(regionCode)" }
}

/// The language the app is showing right now, and the switch that changes it.
///
/// Stored in the App Group so the widgets, the watch and the shield screen follow
/// the same choice. Every install that exists today is Hebrew, so Hebrew stays the
/// default until the user picks otherwise — nobody wakes up to an English app.
final class LanguageStore: ObservableObject {
    static let shared = LanguageStore()
    static let defaultsKey = "app.language"

    @Published private(set) var current: AppLanguage

    private init() {
        current = AppLanguage(rawValue: AppGroup.defaults.string(forKey: Self.defaultsKey) ?? "") ?? .he
        #if DEBUG
        // DEMO_LANG=en — screenshots in another language without touching the saved choice.
        if let demo = ProcessInfo.processInfo.environment["DEMO_LANG"].flatMap(AppLanguage.init(rawValue:)) { current = demo }
        #endif
    }

    /// Languages offered in the picker. English is visible only to builds that
    /// are testing it until its content is ready to launch.
    var available: [AppLanguage] {
        #if DEBUG
        return AppLanguage.allCases
        #else
        return AppGroup.defaults.bool(forKey: "app.language.englishPreview") ? AppLanguage.allCases : [.he]
        #endif
    }

    func set(_ language: AppLanguage) {
        guard language != current else { return }
        AppGroup.defaults.set(language.rawValue, forKey: Self.defaultsKey)
        current = language
    }

    #if DEBUG
    /// Tests and demo screens only.
    func setForTesting(_ language: AppLanguage) {
        AppGroup.defaults.set(language.rawValue, forKey: Self.defaultsKey)
        current = language
    }
    #endif
}

extension LayoutDirection {
    /// The direction of the current app language (Hebrew → right-to-left).
    static var app: LayoutDirection { LanguageStore.shared.current.layoutDirection }
    /// For the few rows that were pinned left-to-right inside a Hebrew screen
    /// (a close button on the far left): the mirror of `.app`, so English puts
    /// it on the far right the way a left-to-right app expects.
    static var appMirrored: LayoutDirection { LanguageStore.shared.current == .he ? .leftToRight : .rightToLeft }
}

/// Look up a user-facing string in the current app language.
///
/// The key IS the Hebrew text as it was written before localization, so a
/// Hebrew lookup returns exactly what the app always showed — Hebrew can't
/// regress — and every other language is a translation of it in
/// `Localizable.xcstrings`. A missing translation falls back to Hebrew rather
/// than to an empty string or a raw key.
func tr(_ key: String.LocalizationValue) -> String {
    let language = LanguageStore.shared.current
    let resource = LocalizedStringResource(key, locale: language.locale, bundle: .atURL(Localization.bundle(for: language).bundleURL))
    let text = String(localized: resource)
    // Foundation wraps every interpolated String in invisible first-strong
    // isolates (U+2068 … U+2069). They help an English sentence hold a Hebrew
    // name, but in Hebrew they would make "the same" string differ byte-for-byte
    // from what the app always produced — read-aloud scripts, keys, comparisons.
    return language == .he ? Localization.removingInsertedIsolates(text) : text
}

enum Localization {
    /// Drop U+2068 (first-strong isolate) and the U+2069 that closes it, leaving
    /// the app's own left-to-right isolates (U+2066 … U+2069, used for math) intact.
    static func removingInsertedIsolates(_ s: String) -> String {
        guard s.unicodeScalars.contains("\u{2068}") else { return s }
        var out = String.UnicodeScalarView()
        var openers: [Unicode.Scalar] = []
        for u in s.unicodeScalars {
            switch u.value {
            case 0x2066, 0x2067:
                openers.append(u); out.append(u)
            case 0x2068:
                openers.append(u)                       // inserted — drop
            case 0x2069:
                if openers.popLast()?.value != 0x2068 { out.append(u) }   // keep the app's own closers
            default:
                out.append(u)
            }
        }
        return String(out)
    }

    private static var cache: [AppLanguage: Bundle] = [:]
    private static let lock = NSLock()

    /// The `.lproj` bundle for one language, independent of the device language —
    /// that independence is what lets the in-app picker switch instantly.
    static func bundle(for language: AppLanguage) -> Bundle {
        lock.lock(); defer { lock.unlock() }
        if let b = cache[language] { return b }
        let b = Bundle.main.path(forResource: language.rawValue, ofType: "lproj").flatMap(Bundle.init(path:)) ?? .main
        cache[language] = b
        return b
    }
}
