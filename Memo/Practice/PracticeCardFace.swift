//
//  PracticeCardFace.swift
//  Memo
//

import SwiftUI

/// One side of a card as it looks while practising: the deck's colour, the
/// text large, the hint under it when asked for.
///
/// Its own view so the practice screen and the review of a finished session
/// draw a card the same way.
struct PracticeCardFace: View {

    let text: String
    let hint: String
    let showsHint: Bool
    let deck: Deck

    /// Matches ``CardView``'s own frame.
    static let size = CGSize(width: 200, height: 300)

    /// Keeps the text off the card's edges.
    static let textInset: CGFloat = 16

    var body: some View {
        VStack(spacing: 10) {
            Text(text)
                // Roughly twice the body text this used to use. Short entries —
                // a word, a character — get the whole size; long ones shrink to
                // fit rather than spilling out of a card this size.
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
                // Imported material runs long — a term over its reading, a
                // translation over its gloss — so shrink rather than truncate.
                .minimumScaleFactor(0.4)

            if showsHint, !hint.isEmpty {
                // Scaled up too, but less: a hint is secondary to the card.
                Text(hint)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
        }
        // Inset before the fixed frame, so the text is laid out in the card
        // minus this margin and never runs into its edges.
        .padding(Self.textInset)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(deck.color)
        .foregroundStyle(deck.contrastingTextColor)
    }
}
