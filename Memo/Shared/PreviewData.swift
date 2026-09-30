//
//  PreviewData.swift
//  Memo
//

import Foundation
import SwiftData
import SwiftUI

/// Sample data for SwiftUI previews, backed by an in-memory store so previews
/// never read or write the user's real library.
enum PreviewData {

    @MainActor
    static func container() -> ModelContainer {
        let container = MemoModelContainer.makeInMemoryContainer()
        let context = container.mainContext

        let spanish = Deck(name: "Spanish Food", icon: "🥩", sortIndex: 0)
        spanish.setColor(Color(red: 0.99, green: 0.98, blue: 0.4))
        context.insert(spanish)

        // Varied practice progress so previews show both states that matter:
        // partway and fulfilled.
        for (index, sample) in [
            ("Tea", "Té", "a hot drink", "", 3),
            ("Bread", "Pan", "", "goes with butter", 10),
            ("Cheese", "Queso", "", "", 0),
        ].enumerated() {
            let card = Card(
                frontText: sample.0,
                backText: sample.1,
                frontHintText: sample.2,
                backHintText: sample.3,
                sortIndex: index,
                practiceProgress: sample.4
            )
            context.insert(card)
            card.deck = spanish
        }

        let japanese = Deck(name: "Hiragana", icon: "🇯🇵", sortIndex: 1)
        japanese.setColor(Color(red: 0.4, green: 0.7, blue: 0.95))
        context.insert(japanese)

        return container
    }

    /// A single populated deck, for previews that need one.
    @MainActor
    static func sampleDeck(in container: ModelContainer) -> Deck {
        let descriptor = FetchDescriptor<Deck>(
            sortBy: [SortDescriptor(\Deck.sortIndex)]
        )
        return (try? container.mainContext.fetch(descriptor))?.first
            ?? Deck(name: "Empty", icon: "📝")
    }
}
