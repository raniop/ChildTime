import SwiftUI

/// A companion that wanders the screen on its own and can be dragged manually.
///
/// Use as an overlay so it stays above other content but doesn't push layout.
struct FloatingCompanion: View {
    @ObservedObject var controller: CompanionController
    /// When set, the floating buddy *is* the child — their own avatar wanders
    /// the screen instead of the generic Tofy face.
    var profile: Profile? = nil
    /// Tapping (not dragging) the buddy fires this — used to open avatar settings.
    var onTap: (() -> Void)? = nil
    /// When true, a daily-gift 🎁 floats just above the buddy's head and follows
    /// it as it wanders. Tapping the gift fires `onGiftTap` (opens the chest).
    var showGift: Bool = false
    var onGiftTap: (() -> Void)? = nil
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
    @State private var bubbleSize: CGSize = .zero
    @ObservedObject private var cosmeticStore = CosmeticStore.shared

    var body: some View {
        GeometryReader { geo in
            let anchor = position == .zero ? defaultPosition(in: geo.size) : position
            ZStack {
            // Layer 1 (back): the draggable avatar.
            ZStack {
                Group {
                    // A flat image of the child's chosen character — the 2D
                    // animal directly, or a snapshot of the 3D model — so it
                    // drags and wanders perfectly smoothly (a live SCNView won't).
                    if let profile,
                       let img = profile.character.uiImage
                        ?? CharacterSnapshot.image(modelName: profile.character.scn, pixelSize: size * 2) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size * 1.3)
                    } else {
                        // Main-screen fallback when the child has no character —
                        // kept as the original smiley (per "don't touch the main screen").
                        CompanionView(controller: controller, size: size, useLion: false)
                    }
                }
                .frame(width: size, height: size * 1.3)
                // The 3D view disables its own hit testing, so give the buddy an
                // explicit tappable/draggable area for the gesture below.
                .contentShape(Rectangle())
                .scaleEffect(isDragging ? 1.12 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isDragging)
            }
            .position(anchor)
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

            // Layer 2 (middle): the daily gift 🎁 — IN FRONT of the avatar,
            // floating above its head and following it. Its own button opens
            // the chest without selecting/dragging the avatar.
            if showGift, let onGiftTap {
                DailyGiftBeacon(size: size * 0.5) { onGiftTap() }
                    .position(x: anchor.x, y: anchor.y - size * 0.72)
                    .animation(isDragging ? nil : .easeInOut(duration: 4), value: position)
                    .transition(.scale.combined(with: .opacity))
            }

            // Layer 3 (front): the speech bubble — ALWAYS on top so the child can
            // read it, floating just above the avatar's head and kept fully ON
            // SCREEN (clamped horizontally). No tail: the buddy wanders, so a tail
            // can't reliably point at it — a clean bubble right above reads best.
            if let bubble = controller.bubbleText {
                let margin: CGFloat = 10
                let half = bubbleSize.width / 2
                let clampedX = bubbleSize.width > 0
                    ? min(max(margin + half, anchor.x), geo.size.width - margin - half)
                    : anchor.x
                BubbleSpeech(text: bubble, showTail: false)
                    .fixedSize()
                    .background(GeometryReader { g in
                        Color.clear.preference(key: BubbleSizeKey.self, value: g.size)
                    })
                    .onPreferenceChange(BubbleSizeKey.self) { bubbleSize = $0 }
                    .position(x: clampedX, y: anchor.y - size * 0.9)
                    .animation(isDragging ? nil : .easeInOut(duration: 4), value: position)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: controller.bubbleText)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showGift)
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
        // Anchor zones live STRICTLY inside the band defined by the insets, so a
        // large bottomInset (e.g. on the pre-mission screen) keeps the buddy
        // above the cards/buttons instead of parking on them. Biased to the
        // edges so it frames the content rather than sitting dead-center on it.
        let r = size * 0.5
        let minX = horizontalInset + r
        let maxX = max(minX, container.width - horizontalInset - r)
        let minY = topInset + r
        let maxY = max(minY, container.height - bottomInset - r)
        let midX = (minX + maxX) / 2
        func y(_ t: CGFloat) -> CGFloat { minY + (maxY - minY) * t }
        let zones: [(CGFloat, CGFloat)] = [
            (maxX, y(0.0)),    // top-trailing
            (minX, y(0.30)),   // upper-leading
            (maxX, y(0.55)),   // mid-trailing
            (minX, y(1.0)),    // lower-leading
            (midX, y(1.0)),    // lower-center
            (maxX, y(1.0))     // lower-trailing
        ]
        let pick = zones.randomElement() ?? (maxX, minY)
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

/// Measures the speech bubble's rendered size so it can be kept on screen.
private struct BubbleSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

#Preview {
    struct DemoWrapper: View {
        @StateObject var c = CompanionController()
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
