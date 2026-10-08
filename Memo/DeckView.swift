//
//  DeckView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/10.
//

import SwiftUI
import SwiftData

struct DeckView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(PracticeSettingsStore.self) private var practiceSettings

    let deck: Deck

    /// A card to scroll to and point out when the screen opens, for arriving
    /// from a search made on the deck list.
    var focusedCardID: UUID?

    @State private var presentedSheet: CardSheet?
    @State private var isPresentingSettings = false

    @State private var searchText = ""
    @State private var isSearching = false

    /// The card being pointed out, while its row is lit.
    @State private var highlightedCardID: UUID?
    @State private var hasShownFocusedCard = false

    private var cards: [Card] { deck.orderedCards }

    private var query: String { CardSearch.normalized(searchText) }

    /// This deck's options, or the standard ones while it has none of its own.
    private var settings: PracticeSettings {
        deck.resolvedPracticeSettings(
            bookmarkFallback: practiceSettings.settings.bookmarkFallbackMode
        )
    }

    var body: some View {

        ScrollViewReader { proxy in
            List {
                if query.isEmpty {
                    cardList
                } else {
                    searchResults(proxy: proxy)
                }
            }
            .task {
                guard !hasShownFocusedCard,
                      let card = cards.first(where: { $0.uuid == focusedCardID })
                else { return }

                hasShownFocusedCard = true
                reveal(card, with: proxy)
            }
        }
        .navigationTitle("\(deck.icon) \(deck.name)")
        // Always shown rather than revealed by pulling down: it is the quick
        // way to a card in a long deck, and a hidden field is not quick.
        .searchable(
            text: $searchText,
            isPresented: $isSearching,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Search Cards"
        )
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                // Styled by the system rather than by hand. The previous
                // version drew its own blue rounded rectangle and nudged it
                // with an offset, which sat on top of the toolbar's material
                // instead of belonging to it — conspicuously so against the
                // Liquid Glass bar on iOS 26.
                NavigationLink(
                    destination: PracticeView(deck: deck, settings: settings)
                ) {
                    // An explicit HStack rather than a Label: a toolbar Label
                    // collapses to its icon, and on iOS 26 that leaves the
                    // screen's primary action as an unlabelled glyph.
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("Practice")
                    }
                    // Widened past its intrinsic size: this is the screen's
                    // primary action and reads as an afterthought when it
                    // shrink-wraps the word.
                    .padding(.horizontal, 30)
                    // Pinned rather than inherited. A prominent button picks
                    // its own foreground from the tint, and against this blue
                    // it chooses black in dark mode — which clashed with the
                    // white icons on the practice screen it leads to.
                    .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!deck.hasPractisableCards)
            }

            // One button for everything about the deck: its details, how it
            // is practised, and sharing it.
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingSettings = true
                } label: {
                    Label("Deck Settings", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            DeckSettingsView(deck: deck)
        }
        // `sheet(item:)` rather than a Bool plus a separate enum: the presented
        // value and the presentation state cannot drift out of step.
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .add:
                CardEditorView(
                    title: "New Card",
                    saveTitle: "Add",
                    practiceTarget: settings.resolvedPracticeTarget,
                    draft: CardDraft()
                ) { draft in
                    addCard(from: draft)
                }

            case .edit(let card):
                CardEditorView(
                    title: "Edit Card",
                    saveTitle: "Save",
                    practiceTarget: settings.resolvedPracticeTarget,
                    draft: CardDraft(card: card)
                ) { draft in
                    draft.apply(to: card)
                }
            }
        }
    }

    // MARK: - The deck

    @ViewBuilder
    private var cardList: some View {
        Section {
            ForEach(cards) { card in
                Button {
                    presentedSheet = .edit(card)
                } label: {
                    row(for: card)
                }
                .listRowBackground(highlight(for: card))
                .swipeActions(edge: .leading) {
                    Button {
                        card.isBookmarked.toggle()
                    } label: {
                        Label(
                            card.isBookmarked ? "Remove Bookmark" : "Bookmark",
                            systemImage: card.isBookmarked ? "bookmark.slash" : "bookmark"
                        )
                    }
                    .tint(.orange)
                }
            }
            .onDelete(perform: deleteCards)
            .onMove(perform: moveCards)
        } header: {
            if cards.isEmpty {
                Text("This deck is empty. Add some cards to start practicing!")
            } else {
                Spacer()
            }
        }

        Button {
            presentedSheet = .add
        } label: {
            Label("Add", systemImage: "plus")
        }
    }

    private func row(for card: Card) -> some View {
        HStack {
            // Always there, faint when the card is not bookmarked, so every
            // row's text starts at the same place.
            Image(systemName: card.isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.caption)
                .foregroundStyle(card.isBookmarked ? Color.orange : Color.secondary.opacity(0.25))
                .accessibilityLabel(card.isBookmarked ? "Bookmarked" : "Not bookmarked")

            Text(card.backText)
            Spacer()
            Text(card.frontText)
                .fontWeight(.light)

            // Otherwise the target would be a number the user
            // sets and never sees the effect of.
            if let standing = progressLabel(for: card) {
                Text(standing.text)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(standing.isFulfilled ? Color.green : .secondary)
            }
        }
    }

    /// `nil` leaves the row's ordinary background alone.
    private func highlight(for card: Card) -> Color? {
        card.uuid == highlightedCardID ? Color.accentColor.opacity(0.3) : nil
    }

    // MARK: - Searching

    /// The matches only. Choosing one goes back to the whole deck with that
    /// card in view, where it can be opened, moved or swiped like any other.
    @ViewBuilder
    private func searchResults(proxy: ScrollViewProxy) -> some View {
        let matches = CardSearch.cards(in: cards, matching: query)

        Section {
            ForEach(matches) { card in
                Button {
                    reveal(card, with: proxy)
                } label: {
                    row(for: card)
                }
            }
        } header: {
            Text(matches.isEmpty ? "No cards match" : "\(matches.count) card(s)")
        }
    }

    /// Ends the search, scrolls the deck to `card` and lights its row for a
    /// moment.
    private func reveal(_ card: Card, with proxy: ScrollViewProxy) {
        searchText = ""
        isSearching = false

        Task {
            // The list has to be showing the whole deck again before there is
            // a row to scroll to.
            try? await Task.sleep(for: .milliseconds(350))

            withAnimation {
                proxy.scrollTo(card.id, anchor: .center)
            }
            withAnimation(.easeInOut(duration: 0.3)) {
                highlightedCardID = card.uuid
            }

            try? await Task.sleep(for: .seconds(1.5))

            withAnimation(.easeOut(duration: 0.6)) {
                highlightedCardID = nil
            }
        }
    }

    // MARK: - Editing

    private func progressLabel(for card: Card) -> (text: String, isFulfilled: Bool)? {
        let progress = settings.progress(for: card)
        guard let text = progress.shortDescription else { return nil }
        return (text, progress.isFulfilled)
    }

    private func addCard(from draft: CardDraft) {
        let card = Card()
        draft.apply(to: card)

        withAnimation {
            modelContext.insert(card)
            deck.append(card)
        }
    }

    /// Reorders the deck.
    ///
    /// `onMove` supplies the long-press drag on its own; the list needs no edit
    /// mode and no control of its own for it. Card order is user-visible in the
    /// In Order practice mode, not only in this list.
    private func moveCards(from source: IndexSet, to destination: Int) {
        withAnimation {
            cards.applyMove(from: source, to: destination)
        }
    }

    private func deleteCards(at offsets: IndexSet) {
        let ordered = cards

        withAnimation {
            for index in offsets {
                modelContext.delete(ordered[index])
            }
        }
    }
}

// MARK: - Sheet routing

private enum CardSheet: Identifiable {
    case add
    case edit(Card)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let card): card.uuid.uuidString
        }
    }
}

#Preview {
    let container = PreviewData.container()
    return NavigationStack {
        DeckView(deck: PreviewData.sampleDeck(in: container))
    }
    .modelContainer(container)
    .environment(PracticeSettingsStore(
        defaults: UserDefaults(suiteName: "preview.practice.settings")!
    ))
}
