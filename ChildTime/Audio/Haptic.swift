import UIKit

/// Haptic feedback. `UIFeedbackGenerator` MUST run on the main thread — calling
/// it from a background context (e.g. a Firebase listener callback) crashes with
/// "Call must be made on main thread". So every entry point hops to main if it
/// isn't already there, making Haptic safe to call from anywhere.
enum Haptic {
    static func light()     { run { UIImpactFeedbackGenerator(style: .light).impactOccurred() } }
    static func medium()    { run { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } }
    static func heavy()     { run { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() } }
    static func soft()      { run { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } }
    static func success()   { run { UINotificationFeedbackGenerator().notificationOccurred(.success) } }
    static func warning()   { run { UINotificationFeedbackGenerator().notificationOccurred(.warning) } }
    static func selection() { run { UISelectionFeedbackGenerator().selectionChanged() } }

    private static func run(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() }
        else { DispatchQueue.main.async(execute: work) }
    }
}
