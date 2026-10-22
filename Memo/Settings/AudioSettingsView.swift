//
//  AudioSettingsView.swift
//  Memo
//

import SwiftUI

/// When card audio plays during practice.
struct AudioSettingsView: View {

    @Environment(PracticeSettingsStore.self) private var store

    var body: some View {

        @Bindable var store = store

        Form {
            Section {
                Picker("Playback", selection: $store.settings.audioPlayback) {
                    ForEach(AudioPlaybackMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Playback")
            } footer: {
                Text(store.settings.audioPlayback.explanation)
            }

            Section {
            } footer: {
                Text("Audio that plays by itself is silenced by the silent switch; audio you play with a button is not. Music or anything else playing on your iPhone carries on while you practise.")
            }
        }
        .navigationTitle("Audio")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AudioSettingsView()
    }
    .environment(PracticeSettingsStore(
        defaults: UserDefaults(suiteName: "preview.practice.settings")!
    ))
}
