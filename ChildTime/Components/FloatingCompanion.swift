import SwiftUI

/// A companion that wanders the screen on its own and can be dragged manually.
///
/// Use as an overlay so it stays above other content but doesn't push layout.
struct FloatingCompanion: View {
    var controller: CompanionController
    /// When set, the floating buddy *is* the child — their own avatar wanders
    /// the screen instead of the generic Tofy face.
    var profile: Profile? = nil
    /// Tapping (not dragging) the buddy fires this — used to open avatar settings.
    var onTap: (() -> Void)? = nil
    var size: CGFloat = 120
    /// Insets from the parent edges that constrain wandering / drag.
    var topInset: CGFloat = 80
    var bottomInset: CGFloat = 220
    var horizontalInset: CGFloat = 20

    @Environment(\.layoutDirection) private var layoutDirection

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

                Group {
                    if let profile {
                        // The child's own avatar floats around (with their
                        // cosmetics), wrapped in a soft glow so it still reads
                        // as a lively buddy.
                        ZStack {
                            Circle()
                                .fill(AppColor.companionGlow.opacity(0.28))
                                .frame(width: size * 1.18, height: size * 1.18)
                                .blur(radius: 10)
                            ProfileAvatarView(profile: profile, size: size)
                                .overlay(
                                    Circle().stroke(.white.opacity(0.5), lineWidth: 2)
                                )
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                        }
                    } else {
                        CompanionView(controller: controller, size: size)
                    }
                }
                .scaleEffect(isDragging ? 1.12 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isDragging)
            }
            .position(position == .zero ? defaultPosition(in: geo.size) : position)
            .animation(isDragging ? nil : .easeInOut(duration: 4), value: position)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // Ignore tiny movement so a tap doesn't yank the buddy.
                        let dist = hypot(value.translation.width, value.translation.height)
                        guard dist > 8 else { return }
                        if !isDragging {
                            isDragging = true
                            controller.cheer()
                            Haptic.light()
                            cancelWandering()
                        }
                        // In RTL the gesture's local x is mirrored relative to .position,
                        // so we flip it back to screen-space coords.
                        let mirroredX = layoutDirection == .rightToLeft
                            ? geo.size.width - value.location.x
                            : value.location.x
                        position = clamp(CGPoint(x: mirroredX, y: value.location.y), in: geo.size)
                    }
                    .onEnded { value in
                        let dist = hypot(value.translation.width, value.translation.height)
                        if dist <= 8 {
                            // A tap, not a drag → open avatar settings.
                            Haptic.light()
                            onTap?()
                        } else {
                            Haptic.soft()
                            scheduleWander(in: geo.size)
                        }
                        isDragging = false
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

    /// Keep the buddy on-screen but let it roam the WHOLE screen (only a small
    /// safe margin near the very edges). The larger top/bottom insets are used
    /// only to bias auto-wandering — never to cage a manual drag.
    private func clamp(_ point: CGPoint, in container: CGSize) -> CGPoint {
        let margin = size * 0.30          // a sliver may sit past the edge
        let minX = margin
        let maxX = container.width - margin
        let minY = margin
        let maxY = container.height - margin
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
