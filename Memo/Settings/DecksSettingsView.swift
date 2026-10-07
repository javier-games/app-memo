//
//  DecksSettingsView.swift
//  Memo
//

import SwiftUI

/// The settings that apply to every deck.
///
/// Practice options are not here: each deck has its own, set from its
/// Practice Options panel. What is here is the one choice a deck cannot make
/// for itself.
struct DecksSettingsView: View {

    @Environment(PracticeSettingsStore.self) private var store

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
        }
        .navigationTitle("Decks")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        DecksSettingsView()
    }
    .environment(PracticeSettingsStore(
        defaults: UserDefaults(suiteName: "preview.practice.settings")!
    ))
}
