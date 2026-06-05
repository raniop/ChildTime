import SwiftUI

enum OptionFeedback {
    case normal
    case correct
    case wrong       // chosen but wrong (briefly)
    case revealed    // not chosen, but highlight the correct one
    case dimmed      // already-picked-wrong or not selected (neutral)
    case eliminated  // removed by a hint — clear visual feedback
}

struct OptionCard: View {
    let text: String
    let feedback: OptionFeedback
    let index: Int
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var hsc
    private var isCompact: Bool { hsc == .compact }
    private var minHeight: CGFloat { isCompact ? 80 : 110 }
    /// Big by default; shrinks for a long answer / long word so it never breaks
    /// mid-word across lines.
    private var fontSize: CGFloat {
        let longest = text.split(separator: " ").map(\.count).max() ?? text.count
        if longest >= 11      { return isCompact ? 19 : 26 }
        else if longest >= 8  { return isCompact ? 25 : 33 }
        else if text.count >= 16 { return isCompact ? 23 : 30 }
        return isCompact ? 34 : 44
    }

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

    /// Hebrew color name per tile, in the SAME order as `palette`. Lets the
    /// read-aloud identify a tile by COLOR ("יָרוֹק, 4") when the answers are
    /// numbers — otherwise "1, 4" reads as two confusing numbers.
    static let colorNames = ["יָרוֹק", "סָגוֹל", "כָּתוֹם", "כָּחוֹל"]
    static func colorName(for index: Int) -> String {
        colorNames[((index % colorNames.count) + colorNames.count) % colorNames.count]
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(text)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)   // tidy 2-word answers that wrap
                    .lineLimit(2)
                    .minimumScaleFactor(0.45)          // shrink, don't break, long words
                    .strikethrough(feedback == .eliminated, color: .white.opacity(0.8))
                    .frame(maxWidth: .infinity, minHeight: minHeight)
                    .padding(.horizontal, 12)

                // Number badge (1-4) — so the read-aloud can say "answer 2" and
                // the child knows which tile to tap. Top-leading corner.
                VStack {
                    HStack {
                        Text("\(index + 1)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(.black.opacity(0.28)))
                            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)

                // Hint badge — only on eliminated options. Top-TRAILING corner so
                // it never sits on top of the number badge.
                if feedback == .eliminated {
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(AppColor.starGold)
                                    .frame(width: 28, height: 28)
                                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                                Text("💡")
                                    .font(.system(size: 16))
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .background(backgroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.large, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .glow(glowColor, radius: glowRadius)
            .scaleEffect(scale)
            .opacity(feedback == .eliminated ? 0.55 : 1.0)
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
        case .eliminated:
            // Keep the original tile color but heavily desaturated so the
            // 💡 badge + strikethrough read as the source of truth.
            palette[index % palette.count]
        }
    }

    private var borderColor: Color {
        switch feedback {
        case .correct, .revealed: return AppColor.successMint
        case .wrong:              return AppColor.almostWarm
        case .eliminated:         return AppColor.starGold
        default:                  return .white.opacity(0.2)
        }
    }

    private var borderWidth: CGFloat {
        switch feedback {
        case .correct, .wrong, .revealed: return 3
        case .eliminated:                  return 2.5
        default:                            return 1
        }
    }

    private var glowColor: Color {
        switch feedback {
        case .correct, .revealed: return AppColor.successMint
        case .wrong:              return AppColor.almostWarm
        case .eliminated:         return AppColor.starGold.opacity(0.5)
        default:                  return .clear
        }
    }

    private var glowRadius: CGFloat {
        switch feedback {
        case .normal, .dimmed: return 0
        case .eliminated:      return 8
        default:               return 18
        }
    }

    private var scale: CGFloat {
        switch feedback {
        case .correct, .revealed: return 1.05
        case .wrong:               return 0.97
        case .dimmed:              return 0.95
        case .eliminated:          return 0.92
        default:                   return 1.0
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
