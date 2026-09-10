import UIKit

/// A full-screen Tofy backdrop for the shield.
///
/// `ShieldConfiguration` has no background-image slot — only `backgroundColor`.
/// But a `UIColor` can be built from a pattern image, and a pattern large enough
/// to never tile reads as a full-screen picture. That is the only way to put our
/// gradient behind Apple's shield.
enum ShieldBackdrop {

    /// Big enough that no iPhone or iPad ever sees a seam (iPad Pro 13" is
    /// 1366×1024 pt), drawn at 1x to keep this short-lived extension light.
    private static let size = CGSize(width: 1400, height: 1500)

    static func color(from: UIColor, to: UIColor) -> UIColor {
        UIColor(patternImage: image(from: from, to: to))
    }

    private static func image(from: UIColor, to: UIColor) -> UIImage {
        let f = UIGraphicsImageRendererFormat.default()
        f.scale = 1
        f.opaque = true
        return UIGraphicsImageRenderer(size: size, format: f).image { ctx in
            let cg = ctx.cgContext
            // Brand gradient, corner to corner like GlassBackdrop in the app.
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [from.cgColor, to.cgColor] as CFArray,
                                     locations: [0, 1]) {
                cg.drawLinearGradient(grad, start: CGPoint(x: size.width, y: 0),
                                      end: CGPoint(x: 0, y: size.height), options: [])
            }
            // The two soft orbs — pink high-right, teal low-left.
            glow(cg, UIColor(red: 1.0, green: 0.48, blue: 0.83, alpha: 1), 0.40,
                 CGPoint(x: size.width * 0.82, y: size.height * 0.16), size.width * 0.55)
            glow(cg, UIColor(red: 0.49, green: 0.95, blue: 1.0, alpha: 1), 0.34,
                 CGPoint(x: size.width * 0.14, y: size.height * 0.84), size.width * 0.52)
            // A scatter of stars, fixed so the screen never shimmers between draws.
            let stars: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (0.12, 0.22, 9, 0.75), (0.83, 0.30, 7, 0.6), (0.28, 0.62, 6, 0.5),
                (0.70, 0.72, 10, 0.7), (0.46, 0.13, 6, 0.55), (0.90, 0.55, 7, 0.5),
                (0.20, 0.44, 5, 0.45), (0.60, 0.90, 8, 0.6), (0.36, 0.80, 6, 0.5),
            ]
            for (x, y, r, a) in stars {
                cg.setFillColor(UIColor.white.withAlphaComponent(a).cgColor)
                cg.fillEllipse(in: CGRect(x: size.width * x - r, y: size.height * y - r,
                                          width: r * 2, height: r * 2))
            }
        }
    }

    private static func glow(_ cg: CGContext, _ color: UIColor, _ alpha: CGFloat,
                             _ center: CGPoint, _ radius: CGFloat) {
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: [color.withAlphaComponent(alpha).cgColor,
                                             color.withAlphaComponent(0).cgColor] as CFArray,
                                    locations: [0, 1]) else { return }
        cg.drawRadialGradient(grad, startCenter: center, startRadius: 0,
                              endCenter: center, endRadius: radius, options: [])
    }
}
