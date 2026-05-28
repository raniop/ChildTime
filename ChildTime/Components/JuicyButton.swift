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
            label()
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.vertical, 14)
                .padding(.horizontal, 28)
                .frame(maxWidth: maxWidth ?? .infinity)
                .background(gradient)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                .glow(glowColor, radius: 14)
        }
        .buttonStyle(.juicy)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 16) {
            JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {} label: {
                Label("יאללה!", systemImage: "play.fill")
            }
            JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {} label: {
                Text("בוא נתחיל")
            }
            JuicyButton(gradient: AppGradient.castle, glowColor: AppColor.flameOrange) {} label: {
                Label("פתחו לי 10 דקות", systemImage: "gamecontroller.fill")
            }
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
