import SwiftUI

enum OptionFeedback {
    case normal
    case correct
    case wrong       // chosen but wrong
    case revealed    // not chosen, but highlight the correct one
    case dimmed      // not chosen, neutral
}

struct OptionCard: View {
    let text: String
    let feedback: OptionFeedback
    let index: Int
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    private var isCompact: Bool { hsc == .compact }
    private var minHeight: CGFloat { isCompact ? 80 : 110 }
    private var fontSize: CGFloat { isCompact ? 34 : 44 }

    private let palette: [LinearGradient] = [
        LinearGradient(colors: [Color(hex: "118AB2"), Color(hex: "06D6A0")],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(hex: "9B5DE5"), Color(hex: "F15BB5")],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(hex: "FFB84D"), Color(hex: "FF6B9D")],
                       startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(hex: "5E60CE"), Color(hex: "48BFE3")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    ]

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .padding(.horizontal, 12)
                .background(backgroundStyle)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .glow(glowColor, radius: glowRadius)
                .scaleEffect(scale)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: feedback)
        }
        .buttonStyle(.juicy)
        .disabled(feedback != .normal)
    }

    @ViewBuilder
    private var backgroundStyle: some View {
        switch feedback {
        case .normal:
            palette[index % palette.count]
        case .correct, .revealed:
            AppGradient.success
        case .wrong:
            AppGradient.almost
        case .dimmed:
            Color.gray.opacity(0.4)
        }
    }

    private var borderColor: Color {
        switch feedback {
        case .correct, .revealed: return AppColor.successMint
        case .wrong: return AppColor.almostWarm
        default: return .white.opacity(0.2)
        }
    }

    private var borderWidth: CGFloat {
        switch feedback {
        case .correct, .wrong, .revealed: return 3
        default: return 1
        }
    }

    private var glowColor: Color {
        switch feedback {
        case .correct, .revealed: return AppColor.successMint
        case .wrong: return AppColor.almostWarm
        default: return .clear
        }
    }

    private var glowRadius: CGFloat {
        feedback == .normal || feedback == .dimmed ? 0 : 18
    }

    private var scale: CGFloat {
        switch feedback {
        case .correct, .revealed: return 1.05
        case .wrong: return 0.97
        case .dimmed: return 0.95
        default: return 1.0
        }
    }
}

#Preview {
    ZStack {
        AppGradient.dreamy.ignoresSafeArea()
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                OptionCard(text: "12", feedback: .normal, index: 0, action: {})
                OptionCard(text: "9",  feedback: .normal, index: 1, action: {})
            }
            HStack(spacing: 14) {
                OptionCard(text: "11", feedback: .correct, index: 2, action: {})
                OptionCard(text: "13", feedback: .dimmed, index: 3, action: {})
            }
            HStack(spacing: 14) {
                OptionCard(text: "14", feedback: .wrong, index: 0, action: {})
                OptionCard(text: "15", feedback: .revealed, index: 1, action: {})
            }
        }
        .padding()
    }
    .environment(\.layoutDirection, .rightToLeft)
}
