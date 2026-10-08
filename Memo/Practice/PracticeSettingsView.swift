//
//  PracticeSettingsView.swift
//  Memo
//

import SwiftUI

/// The controls for one set of practice options.
///
/// Every control is driven by
/// ``PracticeSettings`` and ``PracticeMode``, so a new rule appears by adding
/// it to those types rather than by rewiring either screen.
struct PracticeOptionsSections: View {

    @Binding var settings: PracticeSettings

    /// Cards available in the deck being configured, which bounds the limit.
    /// `nil` when editing the defaults, where there is no deck to count and so
    /// no limit to offer.
    let deckCardCount: Int?

    /// A heading for the group, where these sit among other settings.
    var title: LocalizedStringKey?

    var body: some View {

        Section {
            Toggle("Inverse", isOn: $settings.isInverted)
        } header: {
            if let title { Text(title) }
        } footer: {
            Text("Show the other side of the card first, and answer with the side you normally see.")
        }

        Section {
            Picker("Mode", selection: $settings.mode) {
                ForEach(PracticeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } footer: {
            if settings.mode == .bookmarked {
                Text("Practises only the cards you have bookmarked. A deck with no bookmarks is practised in \(settings.resolvedBookmarkFallbackMode.title) mode instead.")
            }
        }

        if let deckCardCount {
            Section {
                Stepper(
                    value: cardLimitBinding(deckCardCount: deckCardCount),
                    in: 1...max(1, deckCardCount)
                ) {
                    HStack {
                        Text("Cards")
                        Spacer()
                        Text(cardCountDescription(deckCardCount: deckCardCount))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                // Only adjustable when the mode allows it and there is a
                // choice to make.
                .disabled(!settings.mode.allowsCardLimit || deckCardCount <= 1)
            } footer: {
                if let explanation = settings.mode.cardLimitExplanation {
                    Text(explanation)
                } else if deckCardCount == 0 {
                    Text("This deck has no cards to practise yet.")
                } else {
                    Text("Practise a smaller slice of the deck. \"All\" uses every card.")
                }
            }
        }

        Section {
            Stepper(
                value: $settings.practiceTarget,
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

            Picker("After a Wrong Answer", selection: $settings.errorPenalty) {
                ForEach(PracticeErrorPenalty.allCases) { penalty in
                    Text(penalty.title).tag(penalty)
                }
            }
            .disabled(settings.practiceTarget == 0)
        } footer: {
            Text(practiceTargetFooter)
        }
    }

    // MARK: - Card limit

    /// Maps the optional stored limit onto a concrete stepper value.
    ///
    /// Stepping up to the deck size clears the limit rather than pinning it, so
    /// "All" keeps meaning "all" if the deck grows later.
    private func cardLimitBinding(deckCardCount: Int) -> Binding<Int> {
        Binding(
            get: { settings.cardCount(forDeckSize: max(1, deckCardCount)) },
            set: { newValue in
                settings.cardLimit = newValue >= deckCardCount ? nil : newValue
            }
        )
    }

    private func cardCountDescription(deckCardCount: Int) -> String {
        let count = settings.cardCount(forDeckSize: deckCardCount)

        return settings.practisesWholeDeck(forDeckSize: deckCardCount)
            ? String(localized: "All (\(count))")
            : "\(count)"
    }

    // MARK: - Practice target

    private var practiceTargetDescription: String {
        settings.practiceTarget == 0
            ? String(localized: "Off")
            : "\(settings.practiceTarget)"
    }

    private var practiceTargetFooter: String {
        settings.practiceTarget == 0
            ? String(localized: "Progress is not recorded for any card.")
            : String(localized: "Correct answers a card needs before it counts as learned. \(settings.errorPenalty.explanation)")
    }
}
