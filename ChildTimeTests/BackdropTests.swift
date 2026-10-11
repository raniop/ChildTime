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

    /// A screen on its side gets the wide picture; a photo of their own has only one.
    @Test func aWideScreenGetsTheWidePicture() {
        let tall = UIImage(), wide = UIImage()
        let look = BackdropStore.Look(theme: .tofy, photo: tall, widePhoto: wide)
        #expect(look.photo(for: CGSize(width: 800, height: 1200)) === tall)
        #expect(look.photo(for: CGSize(width: 1200, height: 800)) === wide)
        let own = BackdropStore.Look(theme: .tofy, photo: tall)
        #expect(own.photo(for: CGSize(width: 1200, height: 800)) === tall)
        #expect(BackdropStore.Look(theme: .tofy).photo(for: CGSize(width: 1200, height: 800)) == nil)
    }

    /// 🖼 The pictures: ids of their own (a build that does not know one falls
    /// back to the default colours), and every one really is in the bundle —
    /// full size and thumbnail.
    @Test func everyPictureHasItsOwnIdAndBothImages() {
        let ids = BackdropPicture.all.map(\.id)
        #expect(ids.count == 9)
        #expect(Set(ids).count == ids.count)
        #expect(ids.allSatisfy { $0.hasPrefix("pic-") })
        #expect(Set(ids).isDisjoint(with: BackdropTheme.all.map(\.id) + [BackdropTheme.photoID]))
        for picture in BackdropPicture.all {
            #expect(picture.image != nil, "\(picture.id) — no picture in the bundle")
            #expect(picture.thumbnail != nil, "\(picture.id) — no thumbnail in the bundle")
            let wide = picture.wideImage
            #expect(wide != nil, "\(picture.id) — no wide picture in the bundle")
            #expect((wide?.size.width ?? 0) > (wide?.size.height ?? 0), "\(picture.id) — the wide picture is not wide")
            #expect((picture.image?.size.height ?? 0) > (picture.image?.size.width ?? 0), "\(picture.id) — the tall picture is not tall")
            #expect(!picture.displayName.isEmpty)
            #expect(BackdropTheme.find(picture.id) == .tofy)
        }
        #expect(BackdropPicture.find("sea") == nil)
        #expect(BackdropPicture.find(nil) == nil)
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
