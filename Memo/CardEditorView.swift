//
//  CardEditorView.swift
//  Memo
//

import SwiftUI

/// The in-flight contents of the card editor.
///
/// Editing works against a draft rather than the live model so that a cancelled
/// edit leaves nothing behind, and so validation reads the values the user has
/// actually typed.
struct CardDraft {

    var frontText = ""
    var frontHintText = ""
    var backText = ""
    var backHintText = ""

    /// Correct answers recorded for this card so far.
    ///
    /// Editable so a card practised elsewhere can be brought up to date by
    /// hand; during a run it is maintained by ``CardPracticeProgressRecorder``.
    var practiceProgress: Int = 0

    var isBookmarked = false

    /// A recording as the editor holds it, before it is saved to the card.
    struct Recording: Equatable {
        var data: Data
        var duration: TimeInterval
        var fileExtension: String
    }

    /// The card's recordings by slot. Changed freely while editing; only
    /// ``apply(to:)`` touches the card's own.
    var audio: [AudioSlot: Recording] = [:]

    init() {}

    init(card: Card) {
        frontText = card.frontText
        frontHintText = card.frontHintText
        backText = card.backText
        backHintText = card.backHintText
        practiceProgress = card.practiceProgress
        isBookmarked = card.isBookmarked

        for slot in AudioSlot.allCases {
            if let recording = card.audio(for: slot), let data = recording.data {
                audio[slot] = Recording(
                    data: data,
                    duration: recording.duration,
                    fileExtension: recording.fileExtension
                )
            }
        }
    }

    var isValid: Bool {
        !frontText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !backText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func apply(to card: Card) {
        let texts = [frontText, frontHintText, backText, backHintText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        // Only what the card says counts as an edit. Progress and bookmarks
        // change all the time and are not what an import compares.
        if texts != [card.frontText, card.frontHintText, card.backText, card.backHintText] {
            card.modifiedAt = Date()
        }

        card.frontText = texts[0]
        card.frontHintText = texts[1]
        card.backText = texts[2]
        card.backHintText = texts[3]
        card.practiceProgress = max(0, practiceProgress)
        card.isBookmarked = isBookmarked

        if applyAudio(to: card) {
            card.modifiedAt = Date()
        }
    }

    /// Brings the card's recordings into line with the draft, replacing only
    /// those that changed. Returns whether anything did.
    ///
    /// The card has to be in a model context already for a new recording to
    /// be saved with it.
    private func applyAudio(to card: Card) -> Bool {
        var changed = false

        for slot in AudioSlot.allCases {
            let current = card.audio(for: slot)
            let wanted = audio[slot]

            if let current, current.data == wanted?.data { continue }
            if current == nil, wanted == nil { continue }

            changed = true

            // Every recording in the slot, in case two devices each added one.
            // Taken off the card as well as deleted: a deletion only reaches
            // the relationship when the store next saves, and until then the
            // card would go on reporting, and playing, the old recording.
            let old = (card.audios ?? []).filter { $0.slot == slot }
            card.audios?.removeAll { $0.slot == slot }
            for recording in old {
                card.modelContext?.delete(recording)
            }

            if let wanted {
                let recording = CardAudio(
                    slot: slot,
                    data: wanted.data,
                    duration: wanted.duration,
                    fileExtension: wanted.fileExtension
                )
                card.modelContext?.insert(recording)
                recording.card = card
            }
        }

        return changed
    }
}

/// One editor for creating and for editing, reachable from the deck and from a
/// practice run, since the two differ only in their seed values and button.
struct CardEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AudioPlayer.self) private var player

    let title: LocalizedStringKey
    let saveTitle: LocalizedStringKey

    /// The practice target of the deck the card belongs to, which bounds its
    /// progress. Passed in because it differs from deck to deck.
    let practiceTarget: Int

    let onSave: (CardDraft) -> Void

    @State private var draft: CardDraft

    /// The slot being recorded, while the recorder is up.
    @State private var recordingSlot: AudioSlot?

    /// The slot whose recording is waiting on a confirmed removal.
    @State private var removingSlot: AudioSlot?

    init(
        title: LocalizedStringKey,
        saveTitle: LocalizedStringKey,
        practiceTarget: Int,
        draft: CardDraft,
        onSave: @escaping (CardDraft) -> Void
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.practiceTarget = practiceTarget
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    var body: some View {

        NavigationStack {
            Form {

                // Vertical axis throughout: card text is regularly more than
                // one line — a term above its reading, a translation above its
                // gloss — and a single-line field hides all but the last of it
                // while typing.
                Section {
                    side(
                        text: $draft.backText, prompt: "Back", slot: .back,
                        hint: $draft.backHintText, hintSlot: .backHint
                    )
                } header: {
                    Text("Back")
                }

                Section {
                    side(
                        text: $draft.frontText, prompt: "Front", slot: .front,
                        hint: $draft.frontHintText, hintSlot: .frontHint
                    )
                } header: {
                    Text("Front")
                } footer: {
                    Text("The button at the end of each row records audio for it. Hold a recorded one to record again or remove it.")
                }

                practiceSection

                Section {
                    HStack {
                        Spacer()
                        Button(saveTitle) {
                            onSave(draft)
                            dismiss()
                        }
                        // Validates the draft, not the stored card, so clearing
                        // a field correctly disables saving.
                        .disabled(!draft.isValid)
                        Spacer()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $recordingSlot) { slot in
                AudioRecorderView(title: slot.title) { data, duration in
                    draft.audio[slot] = CardDraft.Recording(
                        data: data,
                        duration: duration,
                        fileExtension: "m4a"
                    )
                }
            }
            .confirmationDialog(
                "Remove this recording?",
                isPresented: isConfirmingRemoval,
                titleVisibility: .visible,
                presenting: removingSlot
            ) { slot in
                Button("Remove", role: .destructive) {
                    player.stop()
                    draft.audio[slot] = nil
                }
            }
            .onDisappear { player.stop() }
        }
    }

    // MARK: - Text and audio

    /// One side of the card: its text and its hint, each in its own row with
    /// the button for its recording at the end of the row.
    @ViewBuilder
    private func side(
        text: Binding<String>,
        prompt: LocalizedStringKey,
        slot: AudioSlot,
        hint: Binding<String>,
        hintSlot: AudioSlot
    ) -> some View {
        HStack(spacing: 12) {
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(2...8)
            audioControl(slot)
        }

        HStack(spacing: 12) {
            TextField("Hint", text: hint, axis: .vertical)
                .lineLimit(1...4)
            audioControl(hintSlot)
        }
    }

    /// Records when the slot is empty. Once recorded, a tap plays or stops,
    /// and a hold opens a menu from the button itself to record again or
    /// remove, so it is clear which recording is meant.
    ///
    /// Borderless, so only the button responds: in a form, an ordinary button
    /// makes its whole row a button.
    @ViewBuilder
    private func audioControl(_ slot: AudioSlot) -> some View {
        let id = "draft-\(slot.rawValue)"

        if draft.audio[slot] != nil {
            Menu {
                Button {
                    player.stop()
                    recordingSlot = slot
                } label: {
                    Label("Record Again", systemImage: "record.circle")
                }

                Button(role: .destructive) {
                    removingSlot = slot
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                AudioRing(isPlaying: player.isPlaying(id), progress: player.progress)
            } primaryAction: {
                if player.isPlaying(id) {
                    player.stop()
                } else if let data = draft.audio[slot]?.data {
                    player.play(data, id: id, trigger: .user)
                }
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(player.isPlaying(id) ? "Stop \(slot.title) audio" : "Play \(slot.title) audio")
            .accessibilityHint("Hold for more options")
        } else {
            Button {
                player.stop()
                recordingSlot = slot
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                    Circle()
                        .fill(Color.red)
                        .frame(width: 11, height: 11)
                }
                .frame(width: 30, height: 30)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Record \(slot.title) audio")
        }
    }

    private var isConfirmingRemoval: Binding<Bool> {
        Binding(
            get: { removingSlot != nil },
            set: { if !$0 { removingSlot = nil } }
        )
    }

    // MARK: - Practice progress

    private var practiceSection: some View {
        Section {
            Stepper(value: progressBinding, in: 0...max(0, target)) {
                HStack {
                    Text("Progress")
                    Spacer()
                    Text(progressDescription)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .disabled(!isTracked)

            Toggle("Bookmarked", isOn: $draft.isBookmarked)
        } header: {
            Text("Practice")
        } footer: {
            Text(progressFooter)
        }
    }

    private var target: Int { practiceTarget }

    private var isTracked: Bool { target > 0 }

    /// Clamped on the way out so a card whose progress outlived a lowered
    /// target still shows a value the stepper can work with. The stored value
    /// is only rewritten if the user actually moves the control.
    private var progressBinding: Binding<Int> {
        Binding(
            get: { min(max(0, draft.practiceProgress), target) },
            set: { draft.practiceProgress = $0 }
        )
    }

    private var progressDescription: String {
        isTracked
            ? "\(min(max(0, draft.practiceProgress), target)) of \(target)"
            : String(localized: "Off")
    }

    private var progressFooter: String {
        isTracked
            ? String(localized: "Correct answers recorded so far. Set it by hand if you have already practised this card elsewhere — a correct answer adds one, and Practice Options decides what a wrong one does. Bookmarked cards are the ones Bookmarked mode practises.")
            : String(localized: "Progress tracking is switched off in Practice Options. Bookmarked cards are the ones Bookmarked mode practises.")
    }
}

#Preview {
    CardEditorView(
        title: "Edit Card",
        saveTitle: "Save",
        practiceTarget: 10,
        draft: CardDraft(card: Card(frontText: "Tea", backText: "Té", practiceProgress: 3))
    ) { _ in }
    .environment(AudioPlayer())
}
