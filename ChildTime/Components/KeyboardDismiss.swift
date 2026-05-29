import SwiftUI

extension View {
    /// Dismisses the keyboard when the user taps anywhere on this view. Uses a
    /// *simultaneous* gesture so buttons and text fields keep working normally.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                )
            }
        )
    }
}
