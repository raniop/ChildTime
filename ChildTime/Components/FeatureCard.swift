import SwiftUI

/// A grid tile that matches `WorldCard`'s footprint but represents a feature
/// (e.g. "Smart Adventure") instead of a world. Keeps the home grid visually
/// consistent — same size, corner radius, emoji treatment, and glow.
struct FeatureCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let gradient: LinearGradient
    let glowColor: Color
    let onTap: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    @State private var float: CGFloat = 0
    @State private var shimmer = false

    private var isCompact: Bool { hsc == .compact }
    private var emojiSize: CGFloat { isCompact ? 80 : 100 }
    private var titleSize: CGFloat { isCompact ? 22 : 26 }
    private var labelSize: CGFloat { isCompact ? 15 : 17 }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                gradient

                RadialGradient(
                    colors: [Color.white.opacity(0.20), .clear],
                    center: UnitPoint(x: 0.8, y: 0.15),
                    startRadius: 0, endRadius: 160
                )

                LinearGradient(colors: [.clear, .white.opacity(0.16), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 70)
                    .offset(y: shimmer ? 200 : -200)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))

                VStack(spacing: 8) {
                    Spacer(minLength: 8)
                    Text(emoji)
                        .font(.system(size: emojiSize))
                        .offset(y: float)
                        .shadow(color: glowColor.opacity(0.8), radius: 22)
                        .shadow(color: .black.opacity(0.25), radius: 4, y: 4)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(title)
                        .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 10)

                    Text(subtitle)
                        .font(.system(size: labelSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 10)

                    Spacer(minLength: 4)
                }
                .padding(.bottom, 12)
            }
            .aspectRatio(0.95, contentMode: .fit)
            .frame(maxWidth: 270)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(.white.opacity(0.35), lineWidth: 2)
            )
            .glow(glowColor, radius: 18)
        }
        .buttonStyle(.juicy)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = -4 }
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false).delay(1)) { shimmer = true }
        }
    }
}
