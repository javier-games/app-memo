//
//  PracticeSettingsView.swift
//  Memo
//

import SwiftUI

/// The practice configuration panel.
///
/// Every control here is driven by ``PracticeSettings`` and ``PracticeMode``,
/// so a new rule appears by adding it to those types rather than by rewiring
/// this screen.
struct PracticeSettingsView: View {

    @Environment(PracticeSettingsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Cards available in the deck being configured, which bounds the limit.
    let deckCardCount: Int

    var body: some View {

        @Bindable var store = store

        NavigationStack {
            Form {

                Section {
                    Toggle("Inverse", isOn: $store.settings.isInverted)
                } footer: {
                    Text("Show the other side of the card first, and answer with the side you normally see.")
                }

                Section {
                    Picker("Mode", selection: $store.settings.mode) {
                        ForEach(PracticeMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                Section {
                    Stepper(value: cardLimitBinding, in: stepperRange) {
                        HStack {
                            Text("Cards")
                            Spacer()
                            Text(cardCountDescription)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .disabled(!isCardLimitAdjustable)
                } footer: {
                    if let explanation = store.settings.mode.cardLimitExplanation {
                        Text(explanation)
                    } else if deckCardCount == 0 {
                        Text("This deck has no cards to practise yet.")
                    } else {
                        Text("Practise a smaller slice of the deck. \"All\" uses every card.")
                    }
                }

                Section {
                    Stepper(
                        value: $store.settings.practiceTarget,
                        in: PracticeSettings.practiceTargetRange
                    ) {
                        HStack {
                            Text("Practice Target")
                            Spacer()
                            Text(practiceTargetDescription)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } footer: {
                    Text(practiceTargetFooter)
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        store.reset()
                    }
                    .disabled(store.settings == .default)
                }
            }
            .navigationTitle("Practice Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Card limit

    /// The limit is only adjustable when the mode allows it and there is a
    /// choice to make.
    private var isCardLimitAdjustable: Bool {
        store.settings.mode.allowsCardLimit && deckCardCount > 1
    }

    private var stepperRange: ClosedRange<Int> {
        1...max(1, deckCardCount)
    }

    /// Maps the optional stored limit onto a concrete stepper value.
    ///
    /// Stepping up to the deck size clears the limit rather than pinning it, so
    /// "All" keeps meaning "all" if the deck grows later.
    private var cardLimitBinding: Binding<Int> {
        Binding(
            get: { store.settings.cardCount(forDeckSize: max(1, deckCardCount)) },
            set: { newValue in
                store.settings.cardLimit = newValue >= deckCardCount ? nil : newValue
            }
        )
    }

    // MARK: - Practice target

    private var practiceTargetDescription: String {
        store.settings.practiceTarget == 0
            ? String(localized: "Off")
            : "\(store.settings.practiceTarget)"
    }

    private var practiceTargetFooter: String {
        store.settings.practiceTarget == 0
            ? String(localized: "Progress is not recorded for any card.")
            : String(localized: "Correct answers a card needs before it counts as learned. A wrong answer sends it back to zero. Individual cards can override this.")
    }

    private var cardCountDescription: String {
        let count = store.settings.cardCount(forDeckSize: deckCardCount)

        return store.settings.practisesWholeDeck(forDeckSize: deckCardCount)
            ? String(localized: "All (\(count))")
            : "\(count)"
    }
}

#Preview {
    PracticeSettingsView(deckCardCount: 12)
        .environment(PracticeSettingsStore(
            defaults: UserDefaults(suiteName: "preview.practice.settings")!
        ))
}
