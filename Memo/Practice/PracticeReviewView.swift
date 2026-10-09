//
//  PracticeReviewView.swift
//  Memo
//

import SwiftUI

/// The cards of a finished session that ended one way: the ones answered
/// correctly, the ones answered wrongly, or the ones skipped.
///
/// Shown over the results, and a card chosen here is shown over this list in
/// turn, so looking closely at a session never means leaving it.
struct PracticeReviewView: View {

    @Environment(\.dismiss) private var dismiss

    let outcome: PracticeSession.Outcome
    let cards: [PracticeSession.ReviewedCard]
    let deck: Deck
    let isInverted: Bool

    @State private var previewing: Card?

    var body: some View {

        NavigationStack {
            List {
                Section {
                    ForEach(cards) { reviewed in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                previewing = reviewed.card
                            }
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
                    Text("Tap a card to see it. Swipe one to the right to bookmark it for later.")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay {
                if let previewing {
                    preview(of: previewing)
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

    /// The card over a dimmed list. A tap anywhere off the card puts it away.
    private func preview(of card: Card) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { closePreview() }

            VStack(spacing: 20) {
                PracticeCardPreview(card: card, deck: deck, isInverted: isInverted)
                    // A new card starts on its prompt, not on whichever side
                    // the last one was left showing.
                    .id(card.uuid)

                Text("Tap the card to turn it over")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    private func closePreview() {
        withAnimation(.easeOut(duration: 0.2)) {
            previewing = nil
        }
    }
}

/// A card to look at rather than to answer: it turns over when tapped, shows
/// its hints, and records nothing.
struct PracticeCardPreview: View {

    let card: Card
    let deck: Deck
    let isInverted: Bool

    @State private var isRevealed = false

    private var faces: CardFaces { CardFaces(card: card, inverted: isInverted) }

    var body: some View {
        ZStack {
            PracticeCardFace(
                text: faces.promptText, hint: faces.promptHint, showsHint: true, deck: deck
            )
            .opacity(isRevealed ? 0 : 1)

            PracticeCardFace(
                text: faces.answerText, hint: faces.answerHint, showsHint: true, deck: deck
            )
            // Turned to face the other way, so it reads correctly once the
            // whole card has turned over.
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            .opacity(isRevealed ? 1 : 0)
        }
        .clipShape(.rect(cornerRadius: 10))
        .shadow(radius: 10)
        .rotation3DEffect(.degrees(isRevealed ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.45)) {
                isRevealed.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isRevealed ? faces.answerText : faces.promptText)
        .accessibilityHint("Turns the card over")
    }
}
