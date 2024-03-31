//
//  EmojiTextFieldUI.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/27.
//

import Foundation
import SwiftUI

class UIEmojiTextField: UITextField {
    
    var isEmoji = false {
        didSet {
            self.reloadInputViews()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override var textInputContextIdentifier: String? {
        return ""
    }
    
    override var textInputMode: UITextInputMode? {
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage == "emoji" && self.isEmoji{
                self.keyboardType = .default
                return mode
            }
        }
        return nil
    }
    
}

struct EmojiTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    
    func makeUIView(context: Context) -> UIEmojiTextField {
        let emojiTextField = UIEmojiTextField()
        emojiTextField.placeholder = placeholder
        emojiTextField.text = text
        emojiTextField.delegate = context.coordinator
        emojiTextField.isEmoji = true
        return emojiTextField
    }
    
    func updateUIView(_ uiView: UIEmojiTextField, context: Context) {
        
        if text.count > 1 {
            let startIndex = text.index(before: text.endIndex)
            let endIndex = text.endIndex
            text = String(text[startIndex..<endIndex])
        }
        
        uiView.text = text
        uiView.isEmoji = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiTextField
        
        init(parent: EmojiTextField) {
            self.parent = parent
        }
        
        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }
    }
}
