import ActivityKit
import Foundation
import AppIntents

/// Shared between the app (which starts/ends the activity) and the
/// PlayTimeWidget extension (which renders it). MUST be a member of BOTH targets
/// — otherwise ActivityKit treats them as different types and nothing shows.
struct PlayTimeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Wall-clock moment the play window ends — drives the live countdown.
        var endsAt: Date
    }

    /// The child's chosen character name (a cute label on the activity).
    var characterName: String
}

/// "עֲצֹר וּשְׁמֹר" from the Live Activity (iOS 17+ interactive button). A
/// `LiveActivityIntent` runs `perform()` in the APP's process. The type is shared
/// with the widget target (which lacks FamilyControls/the app's stores), so the
/// intent itself stays FOUNDATION-only: it records the request in the shared app
/// group and posts a Darwin notification. The app (`StopAndSaveBridge`) does the
/// real work — freeze/bank the leftover + re-lock — since the intent runs it.
public let stopAndSaveDarwinName = "com.rani.ChildTime.stopAndSave"
public let stopAndSaveRequestedAtKey = "stopAndSaveRequestedAt"
public let tofyAppGroupID = "group.com.childtime.shared"

@available(iOS 17.0, *)
struct StopAndSavePlayIntent: LiveActivityIntent {
    // The Lock Screen button. AppIntents extracts these at BUILD time, so they
    // have to stay literals — `tr()` here fails the metadata export outright.
    // The literal is the catalog key, so the system still translates it, but it
    // follows the DEVICE language rather than the language picked inside Tofy.
    // A family whose iPhone is Russian sees Russian; one running a Russian Tofy
    // on a Hebrew iPhone sees Hebrew here alone.
    static var title: LocalizedStringResource = "עֲצֹר וּשְׁמֹר זְמַן"
    static var description = IntentDescription("עוֹצֵר אֶת זְמַן הַמִּשְׂחָק וְשׁוֹמֵר אֶת מַה שֶּׁנִּשְׁאַר")

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: tofyAppGroupID)?
            .set(Date().timeIntervalSince1970, forKey: stopAndSaveRequestedAtKey)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(stopAndSaveDarwinName as CFString),
            nil, nil, true)
        return .result()
    }
}
