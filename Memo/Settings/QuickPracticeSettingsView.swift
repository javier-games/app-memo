//
//  QuickPracticeSettingsView.swift
//  Memo
//

import SwiftUI
import SwiftData

/// The options for Quick Practice, started from the deck list.
struct QuickPracticeSettingsView: View {

    @Environment(PracticeSettingsStore.self) private var store

    @Query(sort: [SortDescriptor(\Deck.sortIndex), SortDescriptor(\Deck.createdAt)])
    private var decks: [Deck]

    var body: some View {

        @Bindable var store = store

        Form {
            Section {
                Toggle("All Decks", isOn: allDecksBinding)

                if store.quickPractice.deckIDs != nil {
                    ForEach(decks) { deck in
                        Button {
                            toggle(deck)
                        } label: {
                            HStack {
                                Text(deck.icon)
                                    .frame(width: 30)
                                Text(deck.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isChosen(deck) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text("Decks")
            } footer: {
                Text(
                    store.quickPractice.deckIDs == nil
                        ? "Cards are drawn from every deck, including ones you add later."
                        : "Cards are drawn from the decks ticked here."
                )
            }

            Section {
                Toggle("Inverse", isOn: $store.quickPractice.isInverted)

                Stepper(
                    value: $store.quickPractice.cardCount,
                    in: QuickPracticeSettings.cardCountRange
                ) {
                    HStack {
                        Text("Cards")
                        Spacer()
                        Text("\(store.quickPractice.cardCount)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } footer: {
                Text("A quick run deals this many cards, picked at random from the chosen decks.")
            }

            Section {
                Stepper(
                    value: $store.quickPractice.practiceTarget,
                    in: PracticeSettings.practiceTargetRange
                ) {
                    HStack {
                        Text("Practice Target")
                        Spacer()
                        Text(
                            store.quickPractice.practiceTarget == 0
                                ? String(localized: "Off")
                                : "\(store.quickPractice.practiceTarget)"
                        )
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }

                Picker("After a Wrong Answer", selection: $store.quickPractice.errorPenalty) {
                    ForEach(PracticeErrorPenalty.allCases) { penalty in
                        Text(penalty.title).tag(penalty)
                    }
                }
                .disabled(store.quickPractice.practiceTarget == 0)
            } footer: {
                Text(
                    store.quickPractice.practiceTarget == 0
                        ? String(localized: "Progress is not recorded during a quick run.")
                        : String(localized: "Correct answers a card needs before it counts as learned, during a quick run. \(store.quickPractice.errorPenalty.explanation)")
                )
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    store.quickPractice = .default
                }
                .disabled(store.quickPractice == .default)
            }
        }
        .navigationTitle("Quick Practice")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Turning "All Decks" off starts from every deck ticked, so nothing is
    /// lost until the user unticks something.
    private var allDecksBinding: Binding<Bool> {
        Binding(
            get: { store.quickPractice.deckIDs == nil },
            set: { isAll in
                store.quickPractice.deckIDs = isAll ? nil : decks.map(\.uuid)
            }
        )
    }

    private func isChosen(_ deck: Deck) -> Bool {
        store.quickPractice.deckIDs?.contains(deck.uuid) ?? true
    }

    private func toggle(_ deck: Deck) {
        var ids = store.quickPractice.deckIDs ?? decks.map(\.uuid)

        if let index = ids.firstIndex(of: deck.uuid) {
            ids.remove(at: index)
        } else {
            ids.append(deck.uuid)
        }

        store.quickPractice.deckIDs = ids
    }
}

#Preview {
    NavigationStack {
        QuickPracticeSettingsView()
    }
    .modelContainer(PreviewData.container())
    .environment(PracticeSettingsStore(
        defaults: UserDefaults(suiteName: "preview.practice.settings")!
    ))
}
