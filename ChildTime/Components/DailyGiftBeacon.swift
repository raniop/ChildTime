import SwiftUI

/// A small, lively "daily gift" icon that lives at the top of the home screen.
///
/// It replaces the old full-width bottom button. Instead of a static bar that's
/// always there, this is a playful dancing 🎁 that *only* appears when there's
/// actually a gift to claim (the parent view gates it on
/// `dailyChestAvailable`). It animates in with a little entrance, then keeps
/// wiggling + bobbing + sparkling to pull the child's eye — and vanishes the
/// moment the gift is opened, so it never nags.
struct DailyGiftBeacon: View {
    var size: CGFloat = 46
    let onTap: () -> Void

    @State private var appeared = false
    @State private var wiggle = false
    @State private var bob = false
    @State private var pulse = false
    @State private var sparkle = false

    var body: some View {
        Button {
            Haptic.medium()
            onTap()
        } label: {
            ZStack {
                // Soft glow halo behind the gift.
                Circle()
                    .fill(AppColor.starGold.opacity(0.28))
                    .frame(width: size * 1.5, height: size * 1.5)
                    .scaleEffect(pulse ? 1.12 : 0.9)
                    .blur(radius: 6)

                // Orbiting sparkles.
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: size * 0.26, weight: .bold))
                        .foregroundStyle(AppColor.starGold)
                        .offset(y: -size * 0.7)
                        .rotationEffect(.degrees(Double(i) * 120 + (sparkle ? 360 : 0)))
                        .opacity(sparkle ? 0.9 : 0.4)
                }

                // The gift itself — bobbing + wiggling.
                Text("🎁")
                    .font(.system(size: size * 0.92))
                    .rotationEffect(.degrees(wiggle ? 9 : -9), anchor: .bottom)
                    .offset(y: bob ? -3 : 3)
                    .shadow(color: AppColor.starGold.opacity(0.7), radius: 8)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            }
            .frame(width: size, height: size)
            // The animations can spill outside the frame; don't clip them.
            .contentShape(Circle())
            .scaleEffect(appeared ? 1 : 0.1)
            .opacity(appeared ? 1 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("מתנה יומית"))
        .onAppear {
            // Entrance: pop in with a spring after a beat so it reads as " taa-da!"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55).delay(0.6)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                wiggle = true
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                bob = true
            }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                sparkle = true
            }
        }
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        DailyGiftBeacon { }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
