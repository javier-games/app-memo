//
//  PracticeReviewView.swift
//  Memo
//

import SwiftUI

/// The cards of a finished session that ended one way: the ones answered
/// correctly, the ones answered wrongly, or the ones skipped.
///
/// Shown over the results, and a card chosen here opens in the editor over
/// this list in turn. Something noticed in the middle of a run — a typo, a
/// wrong answer on the card itself — can be put right now that the run is
/// over, without leaving its results to go and find the card.
struct PracticeReviewView: View {

    @Environment(\.dismiss) private var dismiss

    let outcome: PracticeSession.Outcome
    let cards: [PracticeSession.ReviewedCard]

    /// The deck's practice target, which bounds a card's progress in the
    /// editor.
    let practiceTarget: Int

    @State private var editing: Card?

    var body: some View {

        NavigationStack {
            List {
                Section {
                    ForEach(cards) { reviewed in
                        Button {
                            editing = reviewed.card
                        } label: {
                            row(for: reviewed)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                reviewed.card.isBookmarked.toggle()
                            } label: {
                                Label(
                                    reviewed.card.isBookmarked ? "Remove Bookmark" : "Bookmark",
                                    systemImage: reviewed.card.isBookmarked ? "bookmark.slash" : "bookmark"
                                )
                            }
                            .tint(.orange)
                        }
                    }
                } footer: {
                    Text("Tap a card to edit it. Swipe one to the right to bookmark it for later.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editing) { card in
                CardEditorView(
                    title: "Edit Card",
                    saveTitle: "Save",
                    practiceTarget: practiceTarget,
                    draft: CardDraft(card: card)
                ) { draft in
                    draft.apply(to: card)
                }
            }
        }
    }

    private var title: LocalizedStringKey {
        switch outcome {
        case .correct:   "Correct"
        case .incorrect: "Wrong"
        case .skipped:   "Skipped"
        }
    }

    private func row(for reviewed: PracticeSession.ReviewedCard) -> some View {
        let card = reviewed.card

        return HStack {
            // The mark alone says it; a word beside every card would be noise.
            Image(systemName: card.isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.caption)
                .foregroundStyle(card.isBookmarked ? Color.orange : Color.secondary.opacity(0.25))
                .accessibilityLabel(card.isBookmarked ? "Bookmarked" : "Not bookmarked")

            Text(card.backText)
            Spacer()
            Text(card.frontText)
                .fontWeight(.light)

            // A card skipped more than once is still one card in this list.
            if reviewed.times > 1 {
                Text("×\(reviewed.times)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
    }
}
