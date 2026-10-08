//
//  DeckSettingsView.swift
//  Memo
//

import SwiftUI

/// Everything about one deck in one place: what it is called and looks like,
/// how it is practised, and sharing it.
///
/// Changes take effect as they are made, like the practice options always
/// have, so there is no Save and nothing to cancel. The one exception is a
/// blank name, which is not applied: a deck has to be called something.
struct DeckSettingsView: View {

    @Environment(PracticeSettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let deck: Deck

    @State private var draft: DeckDraft

    init(deck: Deck) {
        self.deck = deck
        _draft = State(initialValue: DeckDraft(deck: deck))
    }

    var body: some View {

        NavigationStack {
            Form {

                Section {
                    HStack {
                        EmojiTextField(text: $draft.icon, placeholder: "")
                            .frame(width: 30)

                        TextField("Name", text: $draft.name)
                    }

                    ColorPicker("Color", selection: $draft.color)
                } header: {
                    Text("Deck")
                } footer: {
                    Text(
                        draft.isValid
                            ? "The colour is used for this deck's cards while practising."
                            : "A deck needs a name. The last one is kept until you enter another."
                    )
                }

                PracticeOptionsSections(
                    settings: settingsBinding,
                    deckCardCount: deck.practisableCards.count,
                    title: "Practice"
                )

                Section {
                    Button("Reset Practice Options", role: .destructive) {
                        deck.practiceSettings = nil
                    }
                    .disabled(deck.practiceSettings == nil)
                }

                Section {
                    ShareLink(item: jsonExport, preview: SharePreview(deck.name)) {
                        Label("JSON", systemImage: "curlybraces")
                    }

                    ShareLink(item: csvExport, preview: SharePreview(deck.name)) {
                        Label("CSV", systemImage: "tablecells")
                    }
                } header: {
                    Text("Share")
                } footer: {
                    Text("JSON keeps the deck's name, icon and colour, and can be imported again to update the deck. CSV holds the cards only. Neither includes practice progress or bookmarks.")
                }
                .disabled(deck.isEmpty)
            }
            .navigationTitle("Deck Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: draft) {
                if draft.isValid { draft.apply(to: deck) }
            }
        }
    }

    // MARK: - Practice options

    /// Options that end up equal to the standard ones are not stored, so a
    /// deck nobody has customised carries nothing.
    private var settingsBinding: Binding<PracticeSettings> {
        Binding(
            get: {
                deck.resolvedPracticeSettings(
                    bookmarkFallback: store.settings.bookmarkFallbackMode
                )
            },
            set: { newValue in
                var standard = PracticeSettings.default
                standard.bookmarkFallbackMode = newValue.bookmarkFallbackMode
                deck.practiceSettings = newValue == standard ? nil : newValue
            }
        )
    }

    // MARK: - Sharing

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
}

#Preview {
    let container = PreviewData.container()
    return DeckSettingsView(deck: PreviewData.sampleDeck(in: container))
        .modelContainer(container)
        .environment(PracticeSettingsStore(
            defaults: UserDefaults(suiteName: "preview.practice.settings")!
        ))
}
