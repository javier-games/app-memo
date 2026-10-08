//
//  EmojiTextFieldUI.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/27.
//

import SwiftUI

/// A text field that opens on the emoji keyboard.
final class UIEmojiTextField: UITextField {

    /// Has to be non-nil for the system to consult ``textInputMode`` at all.
    override var textInputContextIdentifier: String? { "" }

    /// The emoji keyboard, if the user has it enabled; otherwise whatever
    /// keyboard they would normally get.
    ///
    /// A plain lookup. The system reads this whenever it likes, so it must
    /// not change the field while answering.
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" }
    }

    /// The field holds one emoji that typing replaces, so there is nothing to
    /// place a cursor in, select, or paste over.
    override func caretRect(for position: UITextPosition) -> CGRect { .zero }

    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] { [] }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool { false }
}

/// A one-emoji field for a deck's icon.
///
/// Picking an emoji replaces the one shown and puts the keyboard away. The
/// emoji keyboard has no return key, so without that there is no way to
/// dismiss it and it sits over the rest of the form.
struct EmojiTextField: UIViewRepresentable {

    @Binding var text: String
    var placeholder: String = ""

    func makeUIView(context: Context) -> UIEmojiTextField {
        let field = UIEmojiTextField()
        field.placeholder = placeholder
        field.text = text
        field.textAlignment = .center
        field.autocorrectionType = .no
        field.delegate = context.coordinator
        return field
    }

    /// Only ever copies the binding into the field. Writing to the binding or
    /// reloading the keyboard from here runs on every SwiftUI update,
    /// including the ones this field's own edits cause, and the two then
    /// chase each other.
    func updateUIView(_ uiView: UIEmojiTextField, context: Context) {
        context.coordinator.text = $text

        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    /// What the field should hold after `typed` is entered: its last
    /// character, since an icon is exactly one, or nothing when the entry is
    /// a deletion.
    static func icon(afterTyping typed: String) -> String {
        typed.last.map(String.init) ?? ""
    }

    final class Coordinator: NSObject, UITextFieldDelegate {

        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        /// Every edit is handled here, in one place, so the field never holds
        /// more than one character even for a moment.
        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let icon = EmojiTextField.icon(afterTyping: string)

            textField.text = icon
            text.wrappedValue = icon

            // An emoji was chosen, so the job is done. A deletion leaves the
            // keyboard up to choose a replacement.
            if !icon.isEmpty {
                textField.resignFirstResponder()
            }

            return false
        }
    }
}
