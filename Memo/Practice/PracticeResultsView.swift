//
//  PracticeResultsView.swift
//  Memo
//

import SwiftUI

/// Shown once every card in a session has been dealt with.
///
/// Previously the session simply ran out of cards and left a blank screen with
/// no way forward but the back button.
struct PracticeResultsView: View {

    let session: PracticeSession
    let onPracticeAgain: () -> Void
    let onDone: () -> Void

    var body: some View {

        VStack(spacing: 32) {

            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)

                Text("Session complete")
                    .font(.title2)
                    .bold()

                Text("\(session.totalCount) \(session.totalCount == 1 ? "card" : "cards") practiced")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ResultRow(
                    label: "Correct",
                    count: session.correctCount,
                    iconName: "checkmark",
                    tint: .green
                )
                Divider().padding(.leading, 56)

                ResultRow(
                    label: "Wrong",
                    count: session.incorrectCount,
                    iconName: "xmark",
                    tint: .red
                )
                Divider().padding(.leading, 56)

                ResultRow(
                    label: "Skipped",
                    count: session.skippedCount,
                    iconName: "forward.fill",
                    tint: .accentColor
                )
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

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct ResultRow: View {

    let label: LocalizedStringKey
    let count: Int
    let iconName: String
    let tint: Color

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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        // Read as one unit rather than as an icon, a word and a loose number.
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    var session = PracticeSession(cards: (0..<6).map { index in
        Card(frontText: "Front \(index)", backText: "Back \(index)")
    })
    for outcome in [.correct, .correct, .correct, .incorrect, .incorrect, .skipped]
        as [PracticeSession.Outcome] {
        session.record(outcome)
    }

    return PracticeResultsView(
        session: session,
        onPracticeAgain: {},
        onDone: {}
    )
}
