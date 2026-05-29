import SwiftUI
import UIKit

/// A text field that is ALWAYS right-aligned / RTL, regardless of the app's
/// base language. SwiftUI's `TextField` maps `.multilineTextAlignment` through
/// the app's localization (English here → LTR), so a plain SwiftUI field shows
/// Hebrew on the left. This wraps UITextField and forces `.right` + RTL.
struct RTLTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var textColor: UIColor = .white
    var pointSize: CGFloat = 20

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.delegate = context.coordinator
        tf.textAlignment = .right
        tf.semanticContentAttribute = .forceRightToLeft
        tf.textColor = textColor
        tf.autocapitalizationType = .words
        tf.returnKeyType = .done
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let base = UIFont.systemFont(ofSize: pointSize, weight: .semibold)
        tf.font = UIFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor,
                         size: pointSize)
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: textColor.withAlphaComponent(0.5)]
        )
        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.editingChanged(_:)),
                     for: .editingChanged)
        return tf
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
        uiView.textColor = textColor
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        @objc func editingChanged(_ tf: UITextField) { text.wrappedValue = tf.text ?? "" }
        func textFieldShouldReturn(_ tf: UITextField) -> Bool { tf.resignFirstResponder(); return true }
    }
}
