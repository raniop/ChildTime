import SwiftUI
import Observation

enum CompanionState: Equatable {
    case idle
    case cheer
    case hype
    case wow
    case console
    case sleep
}

@Observable
final class CompanionController {
    var state: CompanionState = .idle
    var bubbleText: String?

    func cheer(_ text: String? = nil) {
        state = .cheer
        bubbleText = text
        SoundPlayer.shared.play(.companionCheer)
        Haptic.light()
        scheduleReturnToIdle(after: 1.4)
    }

    func hype(_ text: String? = nil) {
        state = .hype
        bubbleText = text
        SoundPlayer.shared.play(.streakUp)
        Haptic.medium()
        scheduleReturnToIdle(after: 1.6)
    }

    func wow(_ text: String? = nil) {
        state = .wow
        bubbleText = text
        SoundPlayer.shared.play(.portalAppear)
        Haptic.heavy()
        scheduleReturnToIdle(after: 2.0)
    }

    func console(_ text: String? = nil) {
        state = .console
        bubbleText = text ?? "כמעט!"
        Haptic.soft()
        scheduleReturnToIdle(after: 1.6)
    }

    private func scheduleReturnToIdle(after seconds: TimeInterval) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            self.state = .idle
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if self.state == .idle { self.bubbleText = nil }
        }
    }
}
