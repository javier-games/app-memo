//
//  DecksSettingsView.swift
//  Memo
//

import SwiftUI
import SwiftData

/// The settings that apply to every deck.
///
/// Practice options are not here: each deck has its own, set from its
/// Practice Options panel. What is here is the one choice a deck cannot make
/// for itself, and the export that takes every deck at once.
struct DecksSettingsView: View {

    @Environment(PracticeSettingsStore.self) private var store

    @Query(sort: [SortDescriptor(\Deck.sortIndex), SortDescriptor(\Deck.createdAt)])
    private var decks: [Deck]

    var body: some View {

        @Bindable var store = store

        Form {
            Section {
                Picker("Use This Mode", selection: $store.settings.bookmarkFallbackMode) {
                    ForEach(PracticeMode.bookmarkFallbacks) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("When a Deck Has No Bookmarks")
            } footer: {
                Text("Only matters for a deck set to Bookmarked mode. If none of its cards are bookmarked, it is practised in this mode.")
            }

            Section {
                ShareLink(
                    item: allDecksExport,
                    preview: SharePreview(DeckExporter.libraryFileName)
                ) {
                    Label("Export All Decks", systemImage: "square.and.arrow.up")
                }
                .disabled(decks.isEmpty)
            } header: {
                Text("Export")
            } footer: {
                Text("One JSON file holding every deck. Importing it, here or on another device, updates the decks it came from and adds the ones that are missing.")
            }
        }
        .navigationTitle("Decks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension DecksSettingsView {

    /// Encoding a handful of strings cannot realistically fail, and a share
    /// sheet is no place to raise it if it somehow did.
    private var allDecksExport: ExportedDeckJSON {
        ExportedDeckJSON(
            data: (try? DeckExporter.jsonData(for: decks)) ?? Data(),
            fileName: DeckExporter.libraryFileName
        )
    }
}

#Preview {
    NavigationStack {
        DecksSettingsView()
    }
    .modelContainer(PreviewData.container())
    .environment(PracticeSettingsStore(
        defaults: UserDefaults(suiteName: "preview.practice.settings")!
    ))
}
