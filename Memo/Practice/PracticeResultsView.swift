//
//  PracticeResultsView.swift
//  Memo
//

import SwiftUI

/// Shown once every card in a session has been dealt with.
///
/// Previously the session simply ran out of cards and left a blank screen with
/// no way forward but the back button.
///
/// How the numbers arrive is ``PracticeResultsReveal``'s business; this screen
/// only draws what it says is showing. Each of the three counts opens the
/// cards behind it.
struct PracticeResultsView: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let session: PracticeSession
    let deck: Deck
    let isInverted: Bool
    let onPracticeAgain: () -> Void
    let onDone: () -> Void

    @State private var reveal: PracticeResultsReveal

    /// Which of the three lists is open, if any.
    @State private var reviewing: PracticeSession.Outcome?

    init(
        session: PracticeSession,
        deck: Deck,
        isInverted: Bool,
        onPracticeAgain: @escaping () -> Void,
        onDone: @escaping () -> Void
    ) {
        self.session = session
        self.deck = deck
        self.isInverted = isInverted
        self.onPracticeAgain = onPracticeAgain
        self.onDone = onDone
        _reveal = State(initialValue: PracticeResultsReveal(log: session.outcomes))
    }

    var body: some View {

        VStack(spacing: 32) {

            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                    .scaleEffect(reveal.showsIcon ? 1 : 0.2)
                    .opacity(reveal.showsIcon ? 1 : 0)

                Text("Session Complete")
                    .font(.title2)
                    .bold()

                Text("\(reveal.tally.practiced) \(reveal.tally.practiced == 1 ? "card" : "cards") practiced")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            VStack(spacing: 0) {
                row(.correct, label: "Correct", count: reveal.tally.correct, iconName: "checkmark", tint: .green)
                Divider().padding(.leading, 56)

                row(.incorrect, label: "Wrong", count: reveal.tally.incorrect, iconName: "xmark", tint: .red)
                Divider().padding(.leading, 56)

                row(.skipped, label: "Skipped", count: reveal.tally.skipped, iconName: "forward.fill", tint: .accentColor)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 12))
            .padding(.horizontal)

            VStack(spacing: 12) {
                Button(action: onPracticeAgain) {
                    Text("Practice Again")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Button("Done", action: onDone)
            }
            .padding(.horizontal)
            // Nothing here should be pressed on the strength of numbers that
            // are still changing.
            .disabled(!reveal.isFinished)

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        // While the numbers are still arriving, one touch anywhere brings
        // them all in at once. Sits over everything so the touch lands here
        // whatever is underneath, and goes away once there is nothing to skip.
        .overlay {
            if !reveal.isFinished {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { reveal.finish() }
                    .accessibilityHidden(true)
            }
        }
        .sheet(item: $reviewing) { outcome in
            PracticeReviewView(
                outcome: outcome,
                cards: session.reviewedCards(outcome),
                deck: deck,
                isInverted: isInverted
            )
        }
        .onAppear {
            if reduceMotion {
                reveal.finish()
            } else {
                reveal.start()
            }
        }
    }

    /// One count, which opens its cards once the counting is over and there
    /// are any to show.
    private func row(
        _ outcome: PracticeSession.Outcome,
        label: LocalizedStringKey,
        count: Int,
        iconName: String,
        tint: Color
    ) -> some View {
        let canOpen = reveal.isFinished && count > 0

        return Button {
            reviewing = outcome
        } label: {
            ResultRow(label: label, count: count, iconName: iconName, tint: tint, showsDisclosure: canOpen)
        }
        .buttonStyle(.plain)
        .disabled(!canOpen)
    }
}

private struct ResultRow: View {

    let label: LocalizedStringKey
    let count: Int
    let iconName: String
    let tint: Color
    let showsDisclosure: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(tint)
                .clipShape(Circle())

            Text(label)

            Spacer()

            Text("\(count)")
                .font(.title3)
                .monospacedDigit()
                .bold()
                .contentTransition(.numericText())

            // Kept in the layout either way, so the numbers do not shift
            // sideways when the rows become tappable.
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .opacity(showsDisclosure ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.rect)
        // Read as one unit rather than as an icon, a word and a loose number.
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = PreviewData.container()
    let deck = PreviewData.sampleDeck(in: container)

    var session = PracticeSession(cards: (0..<6).map { index in
        Card(frontText: "Front \(index)", backText: "Back \(index)")
    })
    for outcome in [.skipped, .correct, .correct, .correct, .incorrect, .incorrect, .correct]
        as [PracticeSession.Outcome] {
        session.record(outcome)
    }

    return PracticeResultsView(
        session: session,
        deck: deck,
        isInverted: false,
        onPracticeAgain: {},
        onDone: {}
    )
    .modelContainer(container)
}
