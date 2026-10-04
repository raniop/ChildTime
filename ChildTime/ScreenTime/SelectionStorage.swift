import Foundation
import FamilyControls

enum SelectionStorage {

    /// 🧨 `FamilyActivitySelection(includeEntireCategory:)` decides what Apple's
    /// picker hands back when a parent ticks a WHOLE CATEGORY.
    ///
    /// With the default `false` — which is what every selection in Tofy used to
    /// be — ticking "Games" stores the *category token* and **nothing else**:
    /// `applicationTokens` comes back empty. The shield is then
    /// `applications = nil` + `.specific([games])`, and a category policy only
    /// reaches apps iOS can file under an App Store category. Apple's own
    /// built-ins — Safari, Photos, Messages, Camera, App Store, FaceTime,
    /// Settings — have no App Store category, so they are never covered.
    ///
    /// That is exactly what Rani saw on his daughter's iPhone: he ticked
    /// everything in "אילו אפליקציות נעולות" and nothing moved, because the
    /// picker handed back zero application tokens.
    ///
    /// With `true`, ticking a category returns every application token inside
    /// it, so `shield.applications` names the apps individually and they are
    /// really shielded. `includeEntireCategory` is a `let` — it can only be set
    /// at init — so every selection in the app is built through here.
    static let includeEntireCategory = true

    /// A fresh, correctly-flagged empty selection. Use this instead of
    /// `FamilyActivitySelection()` anywhere a picker will write into it.
    static func empty() -> FamilyActivitySelection {
        FamilyActivitySelection(includeEntireCategory: includeEntireCategory)
    }

    /// Re-home a selection onto the correct flag, keeping its tokens. Needed
    /// because a selection stored by an older build carries `false`, and the
    /// flag is immutable.
    static func normalized(_ selection: FamilyActivitySelection) -> FamilyActivitySelection {
        guard selection.includeEntireCategory != includeEntireCategory else { return selection }
        var fixed = empty()
        fixed.applicationTokens = selection.applicationTokens
        fixed.categoryTokens = selection.categoryTokens
        fixed.webDomainTokens = selection.webDomainTokens
        return fixed
    }

    static func decode(_ data: Data?) -> FamilyActivitySelection {
        guard let data = data else { return empty() }
        let decoder = JSONDecoder()
        guard let decoded = try? decoder.decode(FamilyActivitySelection.self, from: data) else {
            return empty()
        }
        return normalized(decoded)
    }

    static func encode(_ selection: FamilyActivitySelection) -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(normalized(selection))
    }

    /// True when no apps/categories are selected — lets callers check without
    /// importing FamilyControls themselves.
    static func isEmpty(_ data: Data?) -> Bool {
        let s = decode(data)
        return s.applicationTokens.isEmpty && s.categoryTokens.isEmpty
    }

    /// A block-list that names CATEGORIES but no apps cannot reach Apple's
    /// built-in apps (no App Store category), so the device looks locked while
    /// Safari, Photos and Messages stay open. Worth warning about.
    static func isCategoryOnly(_ data: Data?) -> Bool {
        let s = decode(data)
        return s.applicationTokens.isEmpty && !s.categoryTokens.isEmpty
    }
}
