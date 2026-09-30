//
//  DeckEditorView.swift
//  Memo
//

import SwiftUI

/// The in-flight contents of the deck editor.
struct DeckDraft {

    var name = ""
    var icon = ""
    var color = Color.white

    init() {
        icon = Self.randomIcon()
    }

    init(deck: Deck) {
        name = deck.name
        icon = deck.icon
        color = deck.color
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func apply(to deck: Deck) {
        deck.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        deck.icon = icon
        deck.setColor(color)
    }

    /// A starting suggestion, so a new deck is never iconless.
    static func randomIcon() -> String {
        [
            "✍️", "🗝️", "🔑", "📝",
            "✏️", "🖍️", "✒️", "🖊️",
            "😀", "🤯", "🤓", "🤔",
        ].randomElement() ?? "📝"
    }
}

/// One editor for creating a deck and for changing an existing one, since the
/// two differ only in their seed values and their button.
struct DeckEditorView: View {

    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let saveTitle: LocalizedStringKey
    let onSave: (DeckDraft) -> Void

    @State private var draft: DeckDraft

    init(
        title: LocalizedStringKey,
        saveTitle: LocalizedStringKey,
        draft: DeckDraft,
        onSave: @escaping (DeckDraft) -> Void
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {

        NavigationStack {
            Form {

                Section {
                    HStack {
                        EmojiTextField(text: $draft.icon, placeholder: "")
                            .frame(width: 30)

                        TextField("Name", text: $draft.name)
                    }

                    ColorPicker("Color", selection: $draft.color)
                } footer: {
                    Text("The colour is used for this deck's cards while practising.")
                }

                Section {
                    HStack {
                        Spacer()
                        Button(saveTitle) {
                            onSave(draft)
                            dismiss()
                        }
                        .disabled(!draft.isValid)
                        Spacer()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DeckEditorView(
        title: "Edit Deck",
        saveTitle: "Save",
        draft: DeckDraft(deck: Deck(name: "Spanish Food", icon: "🥩"))
    ) { _ in }
}
