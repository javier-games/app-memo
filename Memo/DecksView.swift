//
//  DecksView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/27.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Where the deck list can navigate to: a deck, optionally with one of its
/// cards to point out on arrival.
struct DeckRoute: Hashable {
    var deckID: UUID
    var cardID: UUID?
}

struct DecksView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AISettingsStore.self) private var ai
    @Environment(RepositorySettingsStore.self) private var repository

    @Query(sort: [SortDescriptor(\Deck.sortIndex), SortDescriptor(\Deck.createdAt)])
    private var decks: [Deck]

    @State private var isPresentingAddDeck = false
    @State private var isPresentingSettings = false
    @State private var isPresentingRepository = false

    /// Non-nil while the AI-assisted import sheet is up.
    @State private var aiImportKind: AIImportKind?

    /// Non-nil while the document picker is up; also names the format chosen.
    @State private var pickingKind: DeckTransferKind?
    /// Read by the picker's completion. `pickingKind` may already have been
    /// cleared by the time the result arrives.
    @State private var requestedKind: DeckTransferKind = .json

    /// What the picked files would do, awaiting the user's go-ahead.
    @State private var pendingImport: DeckImportPlan?
    @State private var importError: String?

    /// Held here so a search result can open a deck, which a link in a row
    /// cannot do for something that is not a row.
    @State private var path: [DeckRoute] = []

    @State private var searchText = ""
    @State private var isSearching = false

    private var query: String { CardSearch.normalized(searchText) }

    var body: some View {

        NavigationStack(path: $path) {

            List {
                if query.isEmpty {
                    library
                } else {
                    searchResults
                }
            }
            .navigationTitle("Decks")
            .navigationDestination(for: DeckRoute.self) { route in
                if let deck = decks.first(where: { $0.uuid == route.deckID }) {
                    DeckView(deck: deck, focusedCardID: route.cardID)
                } else {
                    ContentUnavailableView("Deck Not Found", systemImage: "rectangle.stack")
                }
            }
            .searchable(
                text: $searchText,
                isPresented: $isSearching,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search Decks and Cards"
            )
            .toolbar {
                // Only once there is somewhere to sync to; setting that up is
                // in Settings.
                if repository.isReady {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isPresentingRepository = true
                        } label: {
                            Label("Repository", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $isPresentingRepository) {
                RepositorySyncView()
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsView()
            }
            .sheet(item: $aiImportKind) { kind in
                AIImportView(kind: kind, existingDeckCount: decks.count)
            }
            .sheet(isPresented: $isPresentingAddDeck) {
                DeckEditorView(
                    title: "New Deck",
                    saveTitle: "Add",
                    draft: DeckDraft()
                ) { draft in
                    addDeck(draft)
                }
            }
            .fileImporter(
                isPresented: isPickingFile,
                allowedContentTypes: pickingKind?.contentTypes ?? [.json],
                allowsMultipleSelection: true
            ) { result in
                handlePickedFiles(result)
            }
            .sheet(item: $pendingImport) { plan in
                ImportReviewView(plan: plan) { overwritingConflicts in
                    commitImport(plan, overwritingConflicts: overwritingConflicts)
                }
            }
            .alert(
                "Could Not Import",
                isPresented: isShowingImportError,
                presenting: importError
            ) { _ in
                Button("OK", role: .cancel) { importError = nil }
            } message: { message in
                Text(message)
            }
        }
    }

    // MARK: - The library

    @ViewBuilder
    private var library: some View {
        Section {
            ForEach(decks) { deck in
                DeckRow(deck: deck)
            }
            .onDelete(perform: deleteDecks)
            .onMove(perform: moveDecks)
        } header: {
            if decks.isEmpty {
                Text("Memo looks quite empty uh? Try adding some decks.")
            } else {
                Spacer()
            }
        }

        Menu {
            Button {
                isPresentingAddDeck = true
            } label: {
                Label("New Deck", systemImage: "square.and.pencil")
            }

            Section("Import") {
                ForEach(DeckTransferKind.allCases) { kind in
                    Button {
                        requestedKind = kind
                        pickingKind = kind
                    } label: {
                        Label(kind.title, systemImage: kind.menuIcon)
                    }
                }
            }

            Section("AI Assisted") {
                if ai.isConnected {
                    ForEach(AIImportKind.allCases) { kind in
                        Button {
                            aiImportKind = kind
                        } label: {
                            Label(kind.title, systemImage: kind.menuIcon)
                        }
                    }
                } else {
                    // Nothing to import with yet, so the only useful
                    // step is the one that fixes that.
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Label("Connect an AI Tool…", systemImage: "sparkles")
                    }
                }
            }
        } label: {
            // Stretched to the full row and given a hit shape: a Menu
            // is only triggered by its label, so without this the row
            // looks tappable across its width but responds on about a
            // fifth of it.
            Label("Add", systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
    }

    // MARK: - Searching

    /// Decks by name, then cards by what they say. A card opens its deck with
    /// that card in view.
    @ViewBuilder
    private var searchResults: some View {
        let matchingDecks = CardSearch.decks(in: decks, matching: query)
        let hits = CardSearch.hits(in: decks, matching: query)

        if matchingDecks.isEmpty, hits.isEmpty {
            Section {
                Text("No decks or cards match.")
                    .foregroundStyle(.secondary)
            }
        }

        if !matchingDecks.isEmpty {
            Section("Decks") {
                ForEach(matchingDecks) { deck in
                    DeckRow(deck: deck)
                }
            }
        }

        if !hits.isEmpty {
            Section("Cards") {
                ForEach(hits) { hit in
                    Button {
                        open(hit)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(hit.card.backText)
                                Spacer()
                                Text(hit.card.frontText)
                                    .fontWeight(.light)
                            }
                            .foregroundStyle(.primary)

                            Text("\(hit.deck.icon) \(hit.deck.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func open(_ hit: CardSearch.Hit) {
        searchText = ""
        isSearching = false
        path.append(DeckRoute(deckID: hit.deck.uuid, cardID: hit.card.uuid))
    }

    // MARK: - Importing

    private var isPickingFile: Binding<Bool> {
        Binding(
            get: { pickingKind != nil },
            set: { if !$0 { pickingKind = nil } }
        )
    }

    private var isShowingImportError: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )
    }

    /// Reads and parses the picked files, but writes nothing yet: the user
    /// confirms against what was actually found, and against what it would
    /// change in decks they already have.
    private func handlePickedFiles(_ result: Result<[URL], Error>) {
        pickingKind = nil

        do {
            let files = try DeckImporter.readFiles(at: try result.get())
            let preview = try DeckImporter.preview(files: files, kind: requestedKind)

            pendingImport = DeckImporter.plan(preview, against: decks)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func commitImport(_ plan: DeckImportPlan, overwritingConflicts: Bool) {
        withAnimation {
            DeckImporter.apply(
                plan,
                overwritingConflicts: overwritingConflicts,
                into: modelContext,
                after: decks.count
            )
        }
    }

    /// Reorders the deck list.
    ///
    /// `onMove` supplies the long-press drag on its own; no edit mode and no
    /// control of its own are needed for it.
    private func moveDecks(from source: IndexSet, to destination: Int) {
        withAnimation {
            decks.applyMove(from: source, to: destination)
        }
    }

    private func addDeck(_ draft: DeckDraft) {
        let deck = Deck(sortIndex: (decks.map(\.sortIndex).max() ?? -1) + 1)
        draft.apply(to: deck)

        withAnimation {
            modelContext.insert(deck)
        }
    }

    private func deleteDecks(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(decks[index])
            }
        }
    }
}

struct DeckRow: View {

    let deck: Deck

    var body: some View {
        NavigationLink(value: DeckRoute(deckID: deck.uuid)) {
            HStack {
                Text(deck.icon)
                    .frame(width: 30)
                Text(deck.name)
            }
        }
    }
}

#Preview {
    DecksView()
        .modelContainer(PreviewData.container())
        .environment(PracticeSettingsStore(
            defaults: UserDefaults(suiteName: "preview.practice.settings")!
        ))
        .environment(AISettingsStore(
            defaults: UserDefaults(suiteName: "preview.ai.settings")!
        ))
        .environment(CloudSyncMonitor())
        .environment(RepositorySettingsStore(
            defaults: UserDefaults(suiteName: "preview.repository.settings")!
        ))
}
