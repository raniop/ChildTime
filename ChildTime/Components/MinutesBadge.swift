import SwiftUI

/// A prominent badge that shows how many play-time minutes the child has earned.
/// Pulses gently when minutes > 0 and animates the number on change.
struct MinutesBadge: View {
    let minutes: Int
    var compact: Bool = false

    @State private var bounce: Bool = false

    private var hasMinutes: Bool { minutes > 0 }

    var body: some View {
        HStack(spacing: 8) {
            Text("🎮")
                .font(.system(size: compact ? 18 : 24))
                .scaleEffect(bounce ? 1.25 : 1.0)

            HStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.system(size: compact ? 22 : 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(value: Double(minutes)))
                    .scaleEffect(bounce ? 1.15 : 1.0)
                Text("דק׳")
                    .font(.system(size: compact ? 14 : 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, compact ? 12 : 18)
        .padding(.vertical, compact ? 8 : 12)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: hasMinutes
                            ? [AppColor.successMint.opacity(0.4), Color(hex: "118AB2").opacity(0.4)]
                            : [Color.white.opacity(0.12), Color.white.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule().stroke(
                        hasMinutes ? AppColor.successMint : .white.opacity(0.2),
                        lineWidth: hasMinutes ? 2 : 1
                    )
                )
        )
        .glow(hasMinutes ? AppColor.successMint : .clear, radius: hasMinutes ? 14 : 0)
        .scaleEffect(bounce ? 1.05 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.5), value: bounce)
        .onChange(of: minutes) { _, _ in
            bounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                bounce = false
            }
        }
    }
}

/// A floating popup that pops "+X דקות 🎮" at center on a correct answer, then
/// *flies up toward the top timer* as it fades — so the child sees the time they
/// just earned travel into their banked total.
struct EarnedMinutesPopup: View {
    let minutes: Int
    var visible: Bool

    private enum Phase { case hidden, popped, flying }
    @State private var phase: Phase = .hidden

    private var scale: CGFloat {
        switch phase {
        case .hidden: return 0.4
        case .popped: return 1.0
        case .flying: return 0.5
        }
    }
    private var opacity: Double {
        switch phase {
        case .hidden: return 0
        case .popped: return 1
        case .flying: return 0
        }
    }
    private var offsetY: CGFloat {
        switch phase {
        case .hidden: return 30
        case .popped: return -20
        case .flying: return -300   // flies up toward the HUD timer
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("+\(minutes)")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(AppColor.successMint)
                .glow(AppColor.successMint, radius: 18)
            Text("דקות")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("🎮")
                .font(.system(size: 48))
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.7))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(AppColor.successMint, lineWidth: 3)
                )
        )
        .glow(AppColor.successMint, radius: 30)
        .scaleEffect(scale)
        .opacity(opacity)
        .offset(y: offsetY)
        .onChange(of: visible) { _, isVisible in
            if isVisible {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) {
                    phase = .popped
                }
                // After a beat at center, launch it up toward the timer.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    withAnimation(.easeIn(duration: 0.55)) {
                        phase = .flying
                    }
                }
            } else {
                phase = .hidden
            }
        }
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 30) {
            MinutesBadge(minutes: 0)
            MinutesBadge(minutes: 8)
            MinutesBadge(minutes: 12, compact: true)
            EarnedMinutesPopup(minutes: 2, visible: true)
            EarnedMinutesPopup(minutes: 6, visible: true)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}
