import SwiftUI

/// Shared juicy CTA button used across the app.
///
/// Default size is intentionally compact — caller can override the font via the
/// label closure. Width is capped at `maxWidth` so the button doesn't stretch
/// edge-to-edge on iPad.
struct JuicyButton<Label: View>: View {
    let action: () -> Void
    let gradient: LinearGradient
    let glowColor: Color
    let maxWidth: CGFloat?
    @ViewBuilder let label: () -> Label

    init(
        gradient: LinearGradient = AppGradient.success,
        glowColor: Color = AppColor.successMint,
        maxWidth: CGFloat? = 420,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.gradient = gradient
        self.glowColor = glowColor
        self.maxWidth = maxWidth
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            SoundPlayer.shared.play(.uiTap)
            Haptic.light()
            action()
        } label: {
            let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
            label()
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .padding(.horizontal, 28)
                .frame(maxWidth: maxWidth ?? .infinity)
                // Glass, like every big button in the app: a faint dark base, a
                // white pane, the button's own gradient glowing through it at
                // ~60 %, a top highlight and a light edge — never an opaque slab.
                .background {
                    ZStack {
                        shape.fill(Color(hex: "2A1E5C").opacity(0.2))
                        shape.fill(.white.opacity(0.12))
                        shape.fill(gradient).opacity(0.85)
                        shape.fill(LinearGradient(colors: [.white.opacity(0.35), .clear],
                                                  startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.55)))
                    }
                }
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .white.opacity(0.3)],
                                                           startPoint: .top, endPoint: .bottom), lineWidth: 1.2))
                .clipShape(shape)
                .shadow(color: .black.opacity(0.3), radius: 16, y: 8)
        }
        .buttonStyle(.juicy)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 16) {
            JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {} label: {
                Label("יַאללָה!", systemImage: "play.fill")
            }
            JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {} label: {
                Text("בּוֹא נַתְחִיל")
            }
            JuicyButton(gradient: AppGradient.castle, glowColor: AppColor.flameOrange) {} label: {
                Label("פִּתְחוּ לִי 10 דַּקּוֹת", systemImage: "gamecontroller.fill")
            }
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
