import SwiftUI

enum Motion {
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.55)
    static let snappy = Animation.spring(response: 0.25, dampingFraction: 0.8)
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.85)
    static let lazy = Animation.easeInOut(duration: 0.6)

    static let float = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let pulse = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    static let breathe = Animation.easeInOut(duration: 2.5).repeatForever(autoreverses: true)
    static let shimmer = Animation.linear(duration: 1.5).repeatForever(autoreverses: false)
    static let spin = Animation.linear(duration: 4.0).repeatForever(autoreverses: false)
}
