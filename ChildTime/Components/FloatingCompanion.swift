import SwiftUI

/// A companion that wanders the screen on its own and can be dragged manually.
///
/// Use as an overlay so it stays above other content but doesn't push layout.
struct FloatingCompanion: View {
    var controller: CompanionController
    var size: CGFloat = 120
    /// Insets from the parent edges that constrain wandering / drag.
    var topInset: CGFloat = 80
    var bottomInset: CGFloat = 220
    var horizontalInset: CGFloat = 20

    @State private var position: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var wanderTask: Task<Void, Never>? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Optional speech bubble above the companion
                if let bubble = controller.bubbleText {
                    BubbleSpeech(text: bubble)
                        .offset(x: -size * 0.35, y: -size * 0.85)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                CompanionView(controller: controller, size: size)
                    .scaleEffect(isDragging ? 1.12 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isDragging)
            }
            .position(position == .zero ? defaultPosition(in: geo.size) : position)
            .animation(isDragging ? nil : .easeInOut(duration: 4), value: position)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            controller.cheer()
                            Haptic.light()
                            cancelWandering()
                        }
                        position = clamp(value.location, in: geo.size)
                    }
                    .onEnded { _ in
                        isDragging = false
                        Haptic.soft()
                        scheduleWander(in: geo.size)
                    }
            )
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                    position = defaultPosition(in: geo.size)
                    scheduleWander(in: geo.size)
                }
            }
            .onDisappear { cancelWandering() }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: controller.bubbleText)
        }
    }

    // MARK: - Wandering

    private func scheduleWander(in size: CGSize) {
        cancelWandering()
        wanderTask = Task {
            while !Task.isCancelled {
                // Wait between 6 and 12 seconds, then pick a new spot.
                let wait = Double.random(in: 6...12)
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
                if Task.isCancelled { break }
                await MainActor.run {
                    guard !isDragging else { return }
                    let target = randomTarget(in: size)
                    position = target
                }
            }
        }
    }

    private func cancelWandering() {
        wanderTask?.cancel()
        wanderTask = nil
    }

    // MARK: - Positioning

    private func defaultPosition(in container: CGSize) -> CGPoint {
        // Start in the bottom-trailing area, but inside safe zone.
        let x = container.width - horizontalInset - size * 0.5 - 20
        let y = container.height - bottomInset - size * 0.5
        return clamp(CGPoint(x: x, y: y), in: container)
    }

    private func randomTarget(in container: CGSize) -> CGPoint {
        // Pick from a few anchor zones, biased to corners/edges that don't fully
        // overlap the cards. This gives variety without parking on a card.
        let zones: [(CGFloat, CGFloat)] = [
            (container.width - horizontalInset - size * 0.5, container.height * 0.18),  // top-right
            (horizontalInset + size * 0.5,                  container.height * 0.32),  // mid-left
            (container.width - horizontalInset - size * 0.5, container.height * 0.55),  // mid-right
            (horizontalInset + size * 0.5,                  container.height * 0.78),  // bottom-left
            (container.width * 0.5,                          container.height - bottomInset - size * 0.5),  // bottom-center
            (container.width - horizontalInset - size * 0.5, container.height - bottomInset - size * 0.5)   // bottom-right
        ]
        let pick = zones.randomElement() ?? zones[0]
        return clamp(CGPoint(x: pick.0, y: pick.1), in: container)
    }

    private func clamp(_ point: CGPoint, in container: CGSize) -> CGPoint {
        let minX = horizontalInset + size * 0.5
        let maxX = container.width - horizontalInset - size * 0.5
        let minY = topInset + size * 0.5
        let maxY = container.height - bottomInset * 0.5 - size * 0.5
        return CGPoint(
            x: min(max(minX, point.x), maxX),
            y: min(max(minY, point.y), maxY)
        )
    }
}

#Preview {
    struct DemoWrapper: View {
        @State var c = CompanionController()
        var body: some View {
            ZStack {
                AppGradient.dreamy.ignoresSafeArea()
                Text("גרור את טופי")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                FloatingCompanion(controller: c, size: 120)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
    return DemoWrapper()
}
