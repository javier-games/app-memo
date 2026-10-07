//
//  PracticeView.swift
//  Memo
//
//  Created by Francisco Javier García Gutiérrez on 2024/01/25.
//

import SwiftUI
import SwiftData

struct PracticeView: View {

    @Environment(\.dismiss) private var dismiss

    let deck: Deck

    /// Captured when the run starts, so changing options mid-run cannot
    /// reshape a session already in progress.
    let settings: PracticeSettings

    @State private var session: PracticeSession

    @State private var flip = false
    @State private var offset: CGSize = .zero
    @State private var interactivity: CardInteractivity = [.flipTap, .flipDrag]

    @State private var hasBeenFlipped = false
    @State private var isRevealed = false
    @State private var cardScale: CGFloat = 0
    @State private var showHint = false
    @State private var editingCard: Card?

    init(deck: Deck, settings: PracticeSettings) {
        self.deck = deck
        self.settings = settings
        // Seeded through `State(initialValue:)` rather than by assigning the
        // wrapped value, which would re-plan on every view re-init while
        // SwiftUI kept only the first result.
        _session = State(
            initialValue: PracticeSession(
                cards: PracticePlanner.cards(for: deck, settings: settings)
            )
        )
    }

    /// Which way round the current card is, per the inverse setting.
    private var faces: CardFaces? {
        session.currentCard.map { CardFaces(card: $0, inverted: settings.isInverted) }
    }

    var body: some View {
        Group {
            if session.isFinished {
                PracticeResultsView(
                    session: session,
                    onPracticeAgain: practiceAgain,
                    onDone: { dismiss() }
                )
            } else {
                practiceContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Practising

    private var practiceContent: some View {

        VStack(spacing: 0) {
            Spacer()

            CardView(
                flip: $flip,
                frontView: frontView,
                backView: backView,
                interactivity: $interactivity,
                offset: $offset,
                scale: $cardScale,
                flipAngle: 180,
                onFlip: onFlip,
                onRelease: onRelease
            )
            .onAppear(perform: showCard)

            // Under the card rather than in the navigation bar: it acts on the
            // card in front of you, and up there it sat next to Edit, away
            // from everything else you do with a card.
            HStack(spacing: 12) {
                Button {
                    session.currentCard?.isBookmarked.toggle()
                } label: {
                    Label(
                        isCurrentCardBookmarked ? "Bookmarked" : "Bookmark",
                        systemImage: isCurrentCardBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }
                .tint(isCurrentCardBookmarked ? .orange : nil)
                .disabled(session.currentCard == nil)

                if hasHintForVisibleFace {
                    Button {
                        showHint.toggle()
                    } label: {
                        Label("Show hint", systemImage: "questionmark.circle")
                    }
                }
            }
            .buttonStyle(.bordered)
            .padding(.top, 32)

            Spacer()

            HStack(spacing: 14) {
                CircleButtonView(
                    iconName: "forward.fill",
                    label: "Skip card",
                    buttonColor: .accentColor,
                    isEnabled: session.canSkip,
                    action: { skipCard() }
                )

                CircleButtonView(
                    iconName: "xmark",
                    label: "Mark incorrect",
                    buttonColor: .red,
                    isEnabled: hasBeenFlipped,
                    action: { finishCard(.incorrect) }
                )

                CircleButtonView(
                    iconName: "checkmark",
                    label: "Mark correct",
                    buttonColor: .green,
                    isEnabled: hasBeenFlipped,
                    action: { finishCard(.correct) }
                )

                CircleButtonView(
                    iconName: "arrow.2.squarepath",
                    label: "Flip card",
                    buttonColor: .accentColor,
                    isEnabled: true,
                    action: { flip.toggle() }
                )
            }
            .padding(.bottom, 32)
        }
        .sheet(item: $editingCard) { card in
            CardEditorView(
                title: "Edit Card",
                saveTitle: "Save",
                practiceTarget: settings.resolvedPracticeTarget,
                draft: CardDraft(card: card)
            ) { draft in
                draft.apply(to: card)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCard = session.currentCard
                } label: {
                    Label("Edit Card", systemImage: "square.and.pencil")
                }
                .disabled(session.currentCard == nil)
            }

            ToolbarItem(placement: .principal) {
                // Given an explicit width: a linear ProgressView in the
                // navigation bar's principal slot otherwise collapses to
                // almost nothing, which is why it read as "not working".
                VStack(spacing: 2) {
                    ProgressView(value: session.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 150)

                    Text("\(session.resolvedCount) / \(session.totalCount)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Card \(session.resolvedCount + 1) of \(session.totalCount)")
            }

        }
    }

    /// The face revealed by flipping: the answer.
    private var frontView: some View {
        cardFace(text: faces?.answerText ?? "", hint: faces?.answerHint ?? "")
    }

    /// The face shown first: the prompt.
    private var backView: some View {
        cardFace(text: faces?.promptText ?? "", hint: faces?.promptHint ?? "")
    }

    private func cardFace(text: String, hint: String) -> some View {
        VStack(spacing: 10) {
            Text(text)
                // Roughly twice the body text this used to use. Short entries —
                // a word, a character — get the whole size; long ones shrink to
                // fit rather than spilling out of a card this size.
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
                // Imported material runs long — a term over its reading, a
                // translation over its gloss — so shrink rather than truncate.
                .minimumScaleFactor(0.4)

            if showHint, !hint.isEmpty {
                // Scaled up too, but less: a hint is secondary to the card.
                Text(hint)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
            }
        }
        // Inset before the fixed frame, so the text is laid out in the card
        // minus this margin and never runs into its edges.
        .padding(Self.cardTextInset)
        .frame(width: Self.cardSize.width, height: Self.cardSize.height)
        .background(deck.color)
        .foregroundStyle(deck.contrastingTextColor)
    }

    /// Bookmarking here changes later runs, not this one: the cards of a run
    /// are settled when it starts.
    private var isCurrentCardBookmarked: Bool {
        session.currentCard?.isBookmarked ?? false
    }

    // MARK: - Card metrics

    /// Matches ``CardView``'s own frame.
    private static let cardSize = CGSize(width: 200, height: 300)

    /// Keeps the text off the card's edges.
    private static let cardTextInset: CGFloat = 16

    /// Whether the side currently facing the user carries a hint.
    private var hasHintForVisibleFace: Bool {
        guard let faces else { return false }
        return isRevealed ? faces.hasAnswerHint : faces.hasPromptHint
    }

    // MARK: - Flow

    /// Records an outcome for the current card, then either deals the next one
    /// or lets the session fall through to the results screen.
    private func finishCard(_ outcome: PracticeSession.Outcome) {
        // Recorded before the session advances, while the answered card is
        // still the current one.
        if let card = session.currentCard {
            CardPracticeProgressRecorder.record(
                outcome,
                on: card,
                target: settings.resolvedPracticeTarget
            )
        }

        hideCard {
            session.record(outcome)
            if !session.isFinished { prepareNextCard() }
        }
    }

    /// Sends the current card to the back of the deck and deals the next one.
    ///
    /// Distinct from answering: the card is deferred, not settled, so it does
    /// not move the progress bar and the session cannot end on a skip.
    private func skipCard() {
        guard session.canSkip else { return }

        hideCard {
            session.record(.skipped)
            prepareNextCard()
        }
    }

    private func prepareNextCard() {
        offset = .zero
        hasBeenFlipped = false
        showHint = false
        interactivity.insert(.flipTap)
        interactivity.insert(.flipDrag)
        showCard()
    }

    private func practiceAgain() {
        session.restart(with: PracticePlanner.cards(for: deck, settings: settings))
        offset = .zero
        hasBeenFlipped = false
        isRevealed = false
        showHint = false
        interactivity = [.flipTap, .flipDrag]
        showCard()
    }

    private func onFlip(isRevealed: Bool) {
        self.isRevealed = isRevealed

        if isRevealed {
            interactivity.remove(.flipDrag)
            interactivity.insert(.horizontalDrag)
            hasBeenFlipped = true
        } else {
            interactivity.remove(.horizontalDrag)
            interactivity.insert(.flipDrag)
        }
    }

    private func onRelease(isRevealed: Bool) {
        guard isRevealed else { return }

        if offset.width > 100 {
            finishCard(.correct)
        } else if offset.width < -100 {
            finishCard(.incorrect)
        } else {
            withAnimation { offset = .zero }
        }
    }

    // MARK: - Card animation

    private func showCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            cardScale = 1
        }
    }

    private func hideCard(completion: @escaping () -> Void) {
        if isRevealed { flip = true }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            cardScale = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: completion)
    }
}

/// A round, tinted action button.
///
/// These live in the content area rather than in a toolbar. The colours carry
/// meaning here — green is correct, red is wrong — and iOS 26 groups adjacent
/// toolbar buttons into a single glass container, which merges them into one
/// pill and flattens their tints. Keeping them out of the bar preserves the
/// semantics and avoids custom shapes sitting on top of the bar's material.
struct CircleButtonView: View {

    let iconName: String
    let label: LocalizedStringKey
    let buttonColor: Color
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(isEnabled ? buttonColor : Color.gray.opacity(0.5))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // These controls are icon-only, so they carry no implicit label.
        .accessibilityLabel(label)
    }
}

#Preview {
    let container = PreviewData.container()
    return NavigationStack {
        PracticeView(deck: PreviewData.sampleDeck(in: container), settings: .default)
    }
    .modelContainer(container)
}
