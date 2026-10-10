import Testing
import Foundation
import UIKit
@testable import ChildTime

/// 🎨 The child's backdrop travels on their record, and the catalog keeps its promises.
struct BackdropTests {
    @Test func backdropRoundTripsThroughTheChildRecord() {
        var p = Profile(name: "דנה")
        p.backdropID = "sea"
        p.backdropUpdatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let back = ChildRecord(profile: p, householdID: "H").toProfile()
        #expect(back?.backdropID == "sea")
        #expect(back?.backdropUpdatedAt == p.backdropUpdatedAt)
    }

    @Test func aProfileSavedBeforeBackdropsStillDecodes() throws {
        let data = try JSONEncoder().encode(Profile(name: "יואב"))
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "backdropID"); json.removeValue(forKey: "backdropUpdatedAt")
        let old = try JSONDecoder().decode(Profile.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.backdropID == nil)
    }

    @Test func unknownIdFallsBackToTheDefault() {
        #expect(BackdropTheme.find(nil) == .tofy)
        #expect(BackdropTheme.find("no-such-backdrop") == .tofy)
        #expect(BackdropTheme.find("sea").id == "sea")
    }

    @Test func idsAreUniqueAndNoneIsThePhotoId() {
        let ids = BackdropTheme.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(!ids.contains(BackdropTheme.photoID))
    }

    /// The one rule of the catalog: dark enough for white text. Each stop of the
    /// gradient must keep a 3:1 contrast with white (the large-text threshold).
    @Test func everyBackdropIsDarkEnoughForWhiteText() {
        func luminance(_ hex: String) -> Double {
            let v = UInt32(hex, radix: 16) ?? 0
            let c = [Double((v >> 16) & 0xFF), Double((v >> 8) & 0xFF), Double(v & 0xFF)].map { x -> Double in
                let s = x / 255
                return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
        }
        for theme in BackdropTheme.all {
            for hex in theme.colors {
                let contrast = 1.05 / (luminance(hex) + 0.05)
                #expect(contrast >= 3.0, "\(theme.id) #\(hex) — only \(contrast):1 with white")
            }
        }
    }

    @Test func aBigPhotoIsSqueezedUnderTheDocumentLimit() throws {
        let size = CGSize(width: 4000, height: 3000)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            for i in 0..<400 {
                UIColor(hue: CGFloat(i % 40) / 40, saturation: 0.9, brightness: 0.9, alpha: 1).setFill()
                ctx.fill(CGRect(x: CGFloat(i % 20) * 200, y: CGFloat(i / 20) * 150, width: 200, height: 150))
            }
        }
        let data = try #require(BackdropStore.compress(image))
        #expect(data.count < 900_000)
        let out = try #require(UIImage(data: data))
        #expect(max(out.size.width, out.size.height) <= 1400)
    }
}
