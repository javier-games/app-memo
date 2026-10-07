//
//  CardEditorView.swift
//  Memo
//

import SwiftUI

/// The in-flight contents of the card editor.
///
/// Editing works against a draft rather than the live model so that a cancelled
/// edit leaves nothing behind, and so validation reads the values the user has
/// actually typed.
struct CardDraft {

    var frontText = ""
    var frontHintText = ""
    var backText = ""
    var backHintText = ""

    /// Correct answers recorded for this card so far.
    ///
    /// Editable so a card practised elsewhere can be brought up to date by
    /// hand; during a run it is maintained by ``CardPracticeProgressRecorder``.
    var practiceProgress: Int = 0

    var isBookmarked = false

    init() {}

    init(card: Card) {
        frontText = card.frontText
        frontHintText = card.frontHintText
        backText = card.backText
        backHintText = card.backHintText
        practiceProgress = card.practiceProgress
        isBookmarked = card.isBookmarked
    }

    var isValid: Bool {
        !frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func apply(to card: Card) {
        card.frontText = frontText.trimmingCharacters(in: .whitespacesAndNewlines)
        card.frontHintText = frontHintText.trimmingCharacters(in: .whitespacesAndNewlines)
        card.backText = backText.trimmingCharacters(in: .whitespacesAndNewlines)
        card.backHintText = backHintText.trimmingCharacters(in: .whitespacesAndNewlines)
        card.practiceProgress = max(0, practiceProgress)
        card.isBookmarked = isBookmarked
    }
}

/// One editor for creating and for editing, reachable from the deck and from a
/// practice run, since the two differ only in their seed values and button.
struct CardEditorView: View {

    @Environment(\.dismiss) private var dismiss

    let title: LocalizedStringKey
    let saveTitle: LocalizedStringKey

    /// The practice target of the deck the card belongs to, which bounds its
    /// progress. Passed in because it differs from deck to deck.
    let practiceTarget: Int

    let onSave: (CardDraft) -> Void

    @State private var draft: CardDraft

    init(
        title: LocalizedStringKey,
        saveTitle: LocalizedStringKey,
        practiceTarget: Int,
        draft: CardDraft,
        onSave: @escaping (CardDraft) -> Void
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.practiceTarget = practiceTarget
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {

        NavigationStack {
            Form {

                // Vertical axis throughout: card text is regularly more than
                // one line — a term above its reading, a translation above its
                // gloss — and a single-line field hides all but the last of it
                // while typing.
                Section {
                    TextField("Back", text: $draft.backText, axis: .vertical)
                        .lineLimit(2...8)
                    TextField("Hint", text: $draft.backHintText, axis: .vertical)
                        .lineLimit(1...4)
                }

                Section {
                    TextField("Front", text: $draft.frontText, axis: .vertical)
                        .lineLimit(2...8)
                    TextField("Hint", text: $draft.frontHintText, axis: .vertical)
                        .lineLimit(1...4)
                }

                practiceSection

                Section {
                    HStack {
                        Spacer()
                        Button(saveTitle) {
                            onSave(draft)
                            dismiss()
                        }
                        // Validates the draft, not the stored card, so clearing
                        // a field correctly disables saving.
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

    // MARK: - Practice progress

    private var practiceSection: some View {
        Section {
            Stepper(value: progressBinding, in: 0...max(0, target)) {
                HStack {
                    Text("Progress")
                    Spacer()
                    Text(progressDescription)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .disabled(!isTracked)

            Toggle("Bookmarked", isOn: $draft.isBookmarked)
        } header: {
            Text("Practice")
        } footer: {
            Text(progressFooter)
        }
    }

    private var target: Int { practiceTarget }

    private var isTracked: Bool { target > 0 }

    /// Clamped on the way out so a card whose progress outlived a lowered
    /// target still shows a value the stepper can work with. The stored value
    /// is only rewritten if the user actually moves the control.
    private var progressBinding: Binding<Int> {
        Binding(
            get: { min(max(0, draft.practiceProgress), target) },
            set: { draft.practiceProgress = $0 }
        )
    }

    private var progressDescription: String {
        isTracked
            ? "\(min(max(0, draft.practiceProgress), target)) of \(target)"
            : String(localized: "Off")
    }

    private var progressFooter: String {
        isTracked
            ? String(localized: "Correct answers recorded so far. Set it by hand if you have already practised this card elsewhere — a correct answer adds one, a wrong one sends it back to zero. Bookmarked cards are the ones Bookmarked mode practises.")
            : String(localized: "Progress tracking is switched off in Practice Options. Bookmarked cards are the ones Bookmarked mode practises.")
    }
}

#Preview {
    CardEditorView(
        title: "Edit Card",
        saveTitle: "Save",
        practiceTarget: 10,
        draft: CardDraft(card: Card(frontText: "Tea", backText: "Té", practiceProgress: 3))
    ) { _ in }
}
