import SwiftUI

/// Branded Google Sign-In button — respects Google's identity guidelines while
/// matching the visual weight of Apple's native SignInWithAppleButton.
///
/// Two surface modes (mirroring Apple's `.white` / `.black` styles):
/// - `.onColor`: WHITE button with the multi-color G + dark text.
///               Use on top of dark / colored backgrounds (e.g. onboarding).
/// - `.onLight`: Google-BLUE button with a white G-in-circle + white text.
///               Use on top of white system backgrounds (e.g. sheets).
struct GoogleSignInBranded: View {
    enum Surface { case onColor, onLight }

    let surface: Surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                logo
                Text("התחבר עם Google")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(background)
            .overlay(border)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        }
        .buttonStyle(.juicy)
    }

    // MARK: - G logo

    @ViewBuilder
    private var logo: some View {
        switch surface {
        case .onColor:
            // Crisp multi-color G centered on the white button surface.
            // Approximates Google's brand 4-color identity via angular gradient.
            GoogleGlyph()
                .frame(width: 26, height: 26)
        case .onLight:
            // White G inside a white circle, sitting on Google-blue.
            ZStack {
                Circle().fill(.white)
                Text("G")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(GoogleBrand.blue)
            }
            .frame(width: 26, height: 26)
        }
    }

    private var textColor: Color {
        switch surface {
        case .onColor: return Color(white: 0.12)
        case .onLight: return .white
        }
    }

    @ViewBuilder
    private var background: some View {
        switch surface {
        case .onColor:
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white)
        case .onLight:
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(GoogleBrand.blue)
        }
    }

    @ViewBuilder
    private var border: some View {
        switch surface {
        case .onColor:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 0.5)
        case .onLight:
            EmptyView()
        }
    }
}

// MARK: - Google G glyph

/// A clean, recognizable "G" logo that nods to Google's 4-color identity by
/// running an angular gradient through Blue → Green → Yellow → Red → Blue.
/// Renders crisply at any size; no bundled assets needed.
private struct GoogleGlyph: View {
    var body: some View {
        Text("G")
            .font(.system(size: 22, weight: .black, design: .default))
            .foregroundStyle(
                AngularGradient(
                    gradient: Gradient(stops: [
                        .init(color: GoogleBrand.blue,   location: 0.00),
                        .init(color: GoogleBrand.green,  location: 0.27),
                        .init(color: GoogleBrand.yellow, location: 0.55),
                        .init(color: GoogleBrand.red,    location: 0.80),
                        .init(color: GoogleBrand.blue,   location: 1.00),
                    ]),
                    center: .center,
                    startAngle: .degrees(-90),
                    endAngle:   .degrees(270)
                )
            )
    }
}

// MARK: - Brand palette

enum GoogleBrand {
    static let blue   = Color(red: 66 / 255,  green: 133 / 255, blue: 244 / 255) // #4285F4
    static let green  = Color(red: 52 / 255,  green: 168 / 255, blue: 83 / 255)  // #34A853
    static let yellow = Color(red: 251 / 255, green: 188 / 255, blue: 4 / 255)   // #FBBC04
    static let red    = Color(red: 234 / 255, green: 67 / 255,  blue: 53 / 255)  // #EA4335
}

#Preview {
    VStack(spacing: 20) {
        // On a dark surface
        VStack(spacing: 12) {
            GoogleSignInBranded(surface: .onColor) {}
                .frame(maxWidth: 360)
        }
        .padding()
        .background(
            LinearGradient(colors: [.purple, .blue],
                           startPoint: .top, endPoint: .bottom)
        )

        // On a light surface
        VStack(spacing: 12) {
            GoogleSignInBranded(surface: .onLight) {}
                .frame(maxWidth: 360)
        }
        .padding()
        .background(Color(white: 0.96))
    }
    .environment(\.layoutDirection, .rightToLeft)
}
