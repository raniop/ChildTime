import SwiftUI
import Combine

enum CompanionState: Equatable {
    case idle
    case cheer
    case hype
    case wow
    case console
    case sleep
}

/// ObservableObject (not the iOS-17 `@Observable` macro) so the app supports
/// iOS 16. @MainActor because it drives @Published UI state — mutating those off
/// the main thread crashes SwiftUI ("Call must be made on main thread").
@MainActor
final class CompanionController: ObservableObject {
    @Published var state: CompanionState = .idle
    @Published var bubbleText: String?

    private var bubbleTask: Task<Void, Never>?

    func cheer(_ text: String? = nil) {
        state = .cheer
        bubbleText = text
        SoundPlayer.shared.play(.companionCheer)
        Haptic.light()
        holdBubble(text: text, idleAfter: 1.4)
    }

    func hype(_ text: String? = nil) {
        state = .hype
        bubbleText = text
        SoundPlayer.shared.play(.streakUp)
        Haptic.medium()
        holdBubble(text: text, idleAfter: 1.6)
    }

    func wow(_ text: String? = nil) {
        state = .wow
        bubbleText = text
        SoundPlayer.shared.play(.portalAppear)
        Haptic.heavy()
        holdBubble(text: text, idleAfter: 2.0)
    }

    func console(_ text: String? = nil) {
        let line = text ?? "כִּמְעַט!"
        state = .console
        bubbleText = line
        Haptic.soft()
        holdBubble(text: line, idleAfter: 1.6)
    }

    /// Keep the bubble on screen long enough to actually READ it — the words
    /// reveal one-by-one (typewriter), so the hold scales with the line length:
    /// reveal time (~0.16/word) + a generous reading buffer, never under 4s.
    private func holdBubble(text: String?, idleAfter: TimeInterval) {
        bubbleTask?.cancel()
        let words = max(1, text?.split(separator: " ").count ?? 1)
        let visible = max(4.0, Double(words) * 0.55 + 2.6)
        bubbleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(idleAfter * 1_000_000_000))
            if Task.isCancelled { return }
            self.state = .idle
            let remaining = max(0, visible - idleAfter)
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            if Task.isCancelled { return }
            if self.state == .idle { self.bubbleText = nil }
        }
    }
}
