import Foundation
import FamilyControls

enum SelectionStorage {
    static func decode(_ data: Data?) -> FamilyActivitySelection {
        guard let data = data else { return FamilyActivitySelection() }
        let decoder = JSONDecoder()
        return (try? decoder.decode(FamilyActivitySelection.self, from: data)) ?? FamilyActivitySelection()
    }

    static func encode(_ selection: FamilyActivitySelection) -> Data? {
        let encoder = JSONEncoder()
        return try? encoder.encode(selection)
    }
}
