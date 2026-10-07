//
//  DeckDefaultsSettingsView.swift
//  Memo
//

import SwiftUI

/// The practice options a deck uses until it is given its own.
struct DeckDefaultsSettingsView: View {

    @Environment(PracticeSettingsStore.self) private var store

    var body: some View {

        @Bindable var store = store

        Form {

            Section {
                Text("These are the practice options for every deck that has not been given its own. Change one deck's options from its Practice Options panel.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            PracticeOptionsSections(settings: $store.settings, deckCardCount: nil)

            Section {
                Picker("Use This Mode", selection: $store.settings.bookmarkFallbackMode) {
                    ForEach(PracticeMode.bookmarkFallbacks) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("When a Deck Has No Bookmarks")
            } footer: {
                Text("Only matters for a deck set to Bookmarked mode. If none of its cards are bookmarked, it is practised in this mode. It applies to every deck.")
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    store.reset()
                }
                .disabled(store.settings == .default)
            }
        }
        .navigationTitle("Decks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DeckDefaultsSettingsView()
    }
    .environment(PracticeSettingsStore(
        defaults: UserDefaults(suiteName: "preview.practice.settings")!
    ))
}
