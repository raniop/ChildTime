import SwiftUI

struct JuicyButton<Label: View>: View {
    let action: () -> Void
    let gradient: LinearGradient
    let glowColor: Color
    @ViewBuilder let label: () -> Label

    init(
        gradient: LinearGradient = AppGradient.success,
        glowColor: Color = AppColor.successMint,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.gradient = gradient
        self.glowColor = glowColor
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
                .font(AppFont.title())
                .foregroundStyle(AppColor.textPrimary)
                .padding(.vertical, AppSpacing.xl)
                .padding(.horizontal, AppSpacing.xxxl)
                .frame(maxWidth: .infinity)
                .background(gradient)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.huge, style: .continuous))
                .glow(glowColor, radius: 24)
        }
        .buttonStyle(.juicy)
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 24) {
            JuicyButton(gradient: AppGradient.gold, glowColor: AppColor.starGold) {} label: {
                Label("יאללה!", systemImage: "play.fill")
            }
            JuicyButton(gradient: AppGradient.success, glowColor: AppColor.successMint) {} label: {
                Text("בוא נתחיל")
            }
            JuicyButton(gradient: AppGradient.castle, glowColor: AppColor.flameOrange) {} label: {
                Label("פתח דקות", systemImage: "gamecontroller.fill")
            }
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
