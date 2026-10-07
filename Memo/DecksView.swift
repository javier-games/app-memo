//
//  DecksView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/03/27.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DecksView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AISettingsStore.self) private var ai

    @Query(sort: [SortDescriptor(\Deck.sortIndex), SortDescriptor(\Deck.createdAt)])
    private var decks: [Deck]

    @State private var isPresentingAddDeck = false
    @State private var isPresentingSettings = false

    /// Non-nil while the AI-assisted import sheet is up.
    @State private var aiImportKind: AIImportKind?

    /// Non-nil while the document picker is up; also names the format chosen.
    @State private var pickingKind: DeckTransferKind?
    /// Read by the picker's completion. `pickingKind` may already have been
    /// cleared by the time the result arrives.
    @State private var requestedKind: DeckTransferKind = .json

    @State private var pendingImport: DeckImporter.Preview?
    @State private var importError: String?

    var body: some View {

        NavigationStack {

            List {

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
            .navigationTitle("Decks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
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
                allowedContentTypes: pickingKind?.contentTypes ?? [.json]
            ) { result in
                handlePickedFile(result)
            }
            .alert(
                "Import Decks",
                isPresented: isConfirmingImport,
                presenting: pendingImport
            ) { preview in
                Button("Import") { commitImport(preview) }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: { preview in
                Text(importSummary(for: preview))
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

    // MARK: - Importing

    private var isPickingFile: Binding<Bool> {
        Binding(
            get: { pickingKind != nil },
            set: { if !$0 { pickingKind = nil } }
        )
    }

    private var isConfirmingImport: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        )
    }

    private var isShowingImportError: Binding<Bool> {
        Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )
    }

    /// Reads and parses the picked file, but writes nothing yet: the user
    /// confirms against what was actually found.
    private func handlePickedFile(_ result: Result<URL, Error>) {
        pickingKind = nil

        do {
            let url = try result.get()
            let data = try DeckImporter.read(contentsOf: url)

            pendingImport = try DeckImporter.preview(
                data: data,
                kind: requestedKind,
                // CSV has nowhere to put a deck name, so the file supplies it.
                fallbackDeckName: url.deletingPathExtension().lastPathComponent
            )
        } catch {
            importError = error.localizedDescription
        }
    }

    private func commitImport(_ preview: DeckImporter.Preview) {
        withAnimation {
            _ = DeckImporter.insert(preview, into: modelContext, after: decks.count)
        }
        pendingImport = nil
    }

    private func importSummary(for preview: DeckImporter.Preview) -> String {
        var lines = [
            String(localized: "\(preview.deckCount) deck(s) and \(preview.cardCount) card(s) will be added.")
        ]

        if preview.skippedCardCount > 0 {
            lines.append(
                String(localized: "\(preview.skippedCardCount) row(s) were left out for having no front or no back.")
            )
        }

        lines.append(String(localized: "Nothing already in your library is changed."))

        return lines.joined(separator: "\n\n")
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
        NavigationLink(destination: DeckView(deck: deck)) {
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
}
