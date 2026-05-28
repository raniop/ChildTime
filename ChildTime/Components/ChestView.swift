import SwiftUI

enum ChestStage: Equatable {
    case closed
    case glowing       // pulsing, "tap to open"
    case opening       // shake + crack
    case revealed
}

struct ChestView: View {
    let kind: ChestKind
    let stage: ChestStage
    let size: CGFloat

    @State private var shake: CGFloat = 0
    @State private var lidOffset: CGFloat = 0
    @State private var glowScale: CGFloat = 1

    var body: some View {
        ZStack {
            // Glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor.opacity(0.7), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 1.2
                    )
                )
                .frame(width: size * 2.4, height: size * 2.4)
                .blur(radius: 24)
                .scaleEffect(glowScale)
                .opacity(stage == .closed ? 0.5 : 1.0)

            // Chest emoji (using SF Symbol fallback if needed)
            Text(kind.emoji)
                .font(.system(size: size))
                .offset(x: shake)
                .scaleEffect(stage == .revealed ? 1.15 : 1.0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: stage)
        }
        .onAppear { startStageAnimation() }
        .onChange(of: stage) { _, _ in startStageAnimation() }
    }

    private var glowColor: Color {
        switch kind {
        case .wood: return AppColor.companionGlow
        case .gold: return AppColor.starGold
        case .magic: return AppColor.gemPurple
        case .legendary: return Color(hex: "FF6B9D")
        }
    }

    private func startStageAnimation() {
        switch stage {
        case .closed:
            shake = 0; lidOffset = 0; glowScale = 1
        case .glowing:
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                glowScale = 1.15
            }
        case .opening:
            withAnimation(.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true)) {
                shake = 4
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                shake = 0
            }
        case .revealed:
            shake = 0
        }
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 24) {
            HStack(spacing: 30) {
                ChestView(kind: .wood, stage: .closed, size: 90)
                ChestView(kind: .gold, stage: .glowing, size: 90)
                ChestView(kind: .magic, stage: .opening, size: 90)
                ChestView(kind: .legendary, stage: .revealed, size: 90)
            }
            Text("4 שלבי קופסה")
                .subtitleStyle()
        }
    }
}
