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

    @State private var presentedSheet: CardSheet?
    @State private var isPresentingPracticeOptions = false
    @State private var isPresentingDeckEditor = false

    private var cards: [Card] { deck.orderedCards }

    var body: some View {

        List {

            Section {
                ForEach(cards) { card in
                    Button {
                        presentedSheet = .edit(card)
                    } label: {
                        HStack {
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
        .navigationTitle("\(deck.icon) \(deck.name)")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                // Styled by the system rather than by hand. The previous
                // version drew its own blue rounded rectangle and nudged it
                // with an offset, which sat on top of the toolbar's material
                // instead of belonging to it — conspicuously so against the
                // Liquid Glass bar on iOS 26.
                NavigationLink(
                    destination: PracticeView(deck: deck, settings: practiceSettings.settings)
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

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingPracticeOptions = true
                } label: {
                    Label("Practice Options", systemImage: "slider.horizontal.3")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingDeckEditor = true
                } label: {
                    Label("Deck Settings", systemImage: "pencil")
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(
                        item: jsonExport,
                        preview: SharePreview(deck.name)
                    ) {
                        Label("JSON", systemImage: "curlybraces")
                    }

                    ShareLink(
                        item: csvExport,
                        preview: SharePreview(deck.name)
                    ) {
                        Label("CSV", systemImage: "tablecells")
                    }
                } label: {
                    Label("Share Deck", systemImage: "square.and.arrow.up")
                }
                .disabled(cards.isEmpty)
            }
        }
        // `sheet(item:)` rather than a Bool plus a separate enum: the presented
        // value and the presentation state cannot drift out of step.
        .sheet(isPresented: $isPresentingPracticeOptions) {
            PracticeSettingsView(deckCardCount: deck.practisableCards.count)
        }
        .sheet(isPresented: $isPresentingDeckEditor) {
            DeckEditorView(
                title: "Deck Settings",
                saveTitle: "Save",
                draft: DeckDraft(deck: deck)
            ) { draft in
                draft.apply(to: deck)
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .add:
                CardEditorView(
                    title: "New Card",
                    saveTitle: "Add",
                    draft: CardDraft()
                ) { draft in
                    addCard(from: draft)
                }

            case .edit(let card):
                CardEditorView(
                    title: "Edit Card",
                    saveTitle: "Save",
                    draft: CardDraft(card: card)
                ) { draft in
                    draft.apply(to: card)
                }
            }
        }
    }

    // MARK: - Exporting

    /// Encoding a handful of strings cannot realistically fail, and a share
    /// sheet is no place to raise it if it somehow did.
    private var jsonExport: ExportedDeckJSON {
        ExportedDeckJSON(
            data: (try? DeckExporter.jsonData(for: deck)) ?? Data(),
            fileName: DeckExporter.fileName(for: deck, kind: .json)
        )
    }

    private var csvExport: ExportedDeckCSV {
        ExportedDeckCSV(
            text: DeckExporter.csvText(for: deck),
            fileName: DeckExporter.fileName(for: deck, kind: .csv)
        )
    }

    private func progressLabel(for card: Card) -> (text: String, isFulfilled: Bool)? {
        let progress = practiceSettings.settings.progress(for: card)
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
