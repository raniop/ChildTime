import Foundation

/// Hebrew is gendered — verbs and adjectives change for a boy vs a girl. This
/// picks the right form based on the ACTIVE child's gender, so the companion
/// says "אַלּוּף" to a boy and "אַלּוּפָה" to a girl. Defaults to masculine when
/// the gender is unknown.
enum Gendered {
    static var isGirl: Bool { ProfileStore.shared.active?.gender == .girl }

    /// `Gendered.g("אַלּוּף", "אַלּוּפָה")` → the form matching the active child.
    static func g(_ masculine: String, _ feminine: String) -> String {
        isGirl ? feminine : masculine
    }
}
