import SwiftUI

/// Cached loader for the bundled 2D character PNGs.
enum Character2DImages {
    private static var cache: [String: UIImage] = [:]
    static func image(_ name: String) -> UIImage? {
        if let cached = cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        cache[name] = img
        return img
    }
}

extension Character3D {
    /// The flat image for a 2D character (nil for 3D `.scn` characters).
    var uiImage: UIImage? {
        guard let name = imageAsset else { return nil }
        return Character2DImages.image(name)
    }
}

/// Renders any character — a flat image for the 2D animals, or the live 3D
/// SceneKit view for `.scn` models — so callers don't branch on the kind.
struct CharacterView: View {
    let character: Character3D
    var animated: Bool = false
    var interactive: Bool = false
    var portrait: Bool = false

    var body: some View {
        if let img = character.uiImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
        } else {
            Character3DView(modelName: character.scn,
                            animated: animated, interactive: interactive, portrait: portrait)
        }
    }
}
