import SwiftUI

/// 👶➖ A גן take-away the child can SEE (Sasha, 2026-10-15): all the items
/// appear in a row, then the ones taken lift up, shrink and stay behind as
/// faded ghosts — so "how many are left?" is the bright ones. A tap plays it
/// again. Left to right, like every number line (Rani, 2026-10-15).
struct TakeAwayPicture: View {
    let scene: TakeAwayScene
    var fontSize: CGFloat = 34

    @State private var gone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: fontSize * 0.12) {
            ForEach(0..<scene.total, id: \.self) { i in
                let taken = i >= scene.total - scene.take
                Text(scene.emoji)
                    .font(.system(size: fontSize))
                    .scaleEffect(taken && gone ? 0.72 : 1)
                    .opacity(taken && gone ? 0.3 : 1)
                    .offset(y: taken && gone ? -fontSize * 0.55 : 0)
                    .rotationEffect(.degrees(taken && gone ? (i.isMultiple(of: 2) ? -14 : 12) : 0))
                    .animation(.spring(response: 0.55, dampingFraction: 0.62)
                        .delay(Double(i - (scene.total - scene.take)) * 0.12), value: gone)
            }
        }
        .padding(.top, fontSize * 0.55)            // room for the lifted ghosts
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { replay() }
        .task(id: scene) { await play() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(scene.total) ➖ \(scene.take)")
    }

    private func play() async {
        gone = false
        try? await Task.sleep(nanoseconds: reduceMotion ? 200_000_000 : 900_000_000)
        gone = true
    }

    private func replay() {
        gone = false
        Task { try? await Task.sleep(nanoseconds: 600_000_000); gone = true }
    }
}
