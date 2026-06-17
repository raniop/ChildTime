import SwiftUI

/// A small, kid-friendly explainer screen for a home-screen card (the daily
/// challenge, the topic-of-the-day event…). Shows a big emoji, a title, a short
/// explanation, an optional progress pill, and one primary "go" button that
/// runs `onCTA` (e.g. start a session or claim a prize).
struct ChallengeInfoView: View {
    let emoji: String
    let title: String
    let message: String
    var progressText: String? = nil
    let ctaTitle: String
    let onCTA: () -> Void
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "5B6CFF"), Color(hex: "9B5DE5"), Color(hex: "EF476F")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            FloatingOrbs.home().opacity(0.5)
            SparkleField(count: 20, size: 12)

            VStack(spacing: 18) {
                Spacer()
                Text(emoji).font(.system(size: 78)).float(amplitude: 8)
                Text(title)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white).multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                Text(message)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)
                if let progressText {
                    Text(progressText)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Capsule().fill(.white.opacity(0.18)))
                        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                }
                Spacer()
                Button { onCTA() } label: {
                    Text(ctaTitle)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(AppColor.textOnLight)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(AppGradient.gold, in: Capsule())
                        .glow(AppColor.starGold, radius: 14)
                }
                .buttonStyle(.juicy)
                .padding(.horizontal, 36).padding(.bottom, 30)
            }
            .scaleEffect(appeared ? 1 : 0.9)
            .opacity(appeared ? 1 : 0)

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.2)))
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(20)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appeared = true } }
    }
}
