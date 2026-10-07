//
//  AIImportView.swift
//  Memo
//

import SwiftUI
import SwiftData

/// Picks a file, sends it to the connected AI tool, and adds the decks it
/// comes back with.
struct AIImportView: View {

    @Environment(AISettingsStore.self) private var ai
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let kind: AIImportKind

    /// Decks already in the library, so the new ones are appended after them.
    let existingDeckCount: Int

    private enum Phase {
        case editing
        case generating
        case ready(DeckImporter.Preview)
    }

    @State private var document: AIDocument?
    @State private var customPrompt = ""
    @State private var phase = Phase.editing
    @State private var errorMessage: String?
    @State private var isPickingFile = false
    @State private var generation: Task<Void, Never>?

    var body: some View {

        NavigationStack {
            Form {

                Section {
                    Button {
                        isPickingFile = true
                    } label: {
                        Label(
                            document?.name ?? String(localized: "Choose File…"),
                            systemImage: kind.menuIcon
                        )
                    }
                    .disabled(isGenerating)
                } footer: {
                    Text("The file is sent to \(provider.title) with your API key, and \(provider.company) charges your account for it.")
                }

                Section {
                    TextField(
                        "For example: only chapter 2, answers in Spanish",
                        text: $customPrompt,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .disabled(isGenerating)
                } header: {
                    Text("Instructions (Optional)")
                } footer: {
                    Text("Added to Memo's own instructions, which ask for flashcards made from the file.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                switch phase {
                case .editing:
                    Section {
                        Button("Create Cards") { generate() }
                            .disabled(document == nil)
                    }

                case .generating:
                    Section {
                        HStack {
                            ProgressView()
                            Text("Reading the file…")
                                .padding(.leading, 8)
                        }
                        Button("Stop", role: .cancel) { stop() }
                    } footer: {
                        Text("This can take a minute or two for a long file.")
                    }

                case .ready(let preview):
                    Section {
                        ForEach(Array(preview.decks.enumerated()), id: \.offset) { _, deck in
                            HStack {
                                Text(deck.icon)
                                    .frame(width: 30)
                                Text(deck.name)
                                Spacer()
                                Text("\(deck.cardList.count) card(s)")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    } header: {
                        Text("Found")
                    } footer: {
                        if preview.skippedCardCount > 0 {
                            Text("\(preview.skippedCardCount) card(s) were left out for having no front or no back.")
                        }
                    }

                    Section {
                        Button("Add to Library") { commit(preview) }
                        Button("Try Again") { generate() }
                    }
                }
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isPickingFile,
                allowedContentTypes: kind.contentTypes
            ) { result in
                handlePickedFile(result)
            }
            .onDisappear { generation?.cancel() }
        }
    }

    private var provider: AIProvider { ai.settings.provider }

    private var isGenerating: Bool {
        if case .generating = phase { return true }
        return false
    }

    /// Read straight away, while the picker's permission to the file is live.
    private func handlePickedFile(_ result: Result<URL, Error>) {
        errorMessage = nil
        phase = .editing

        do {
            document = try AIDeckGenerator.loadDocument(at: try result.get(), kind: kind)
        } catch {
            document = nil
            errorMessage = error.localizedDescription
        }
    }

    private func generate() {
        guard let document else { return }

        guard let apiKey = ai.apiKey(for: provider) else {
            errorMessage = AIFailure.notConnected.localizedDescription
            return
        }

        errorMessage = nil
        phase = .generating

        let client = provider.makeClient()
        let model = ai.model(for: provider)
        let instructions = customPrompt

        generation = Task {
            do {
                let preview = try await AIDeckGenerator.generate(
                    from: document,
                    customPrompt: instructions,
                    model: model,
                    apiKey: apiKey,
                    using: client
                )
                phase = .ready(preview)
            } catch is CancellationError {
                phase = .editing
            } catch {
                errorMessage = error.localizedDescription
                phase = .editing
            }
        }
    }

    private func stop() {
        generation?.cancel()
        phase = .editing
    }

    private func commit(_ preview: DeckImporter.Preview) {
        withAnimation {
            _ = DeckImporter.insert(preview, into: modelContext, after: existingDeckCount)
        }
        dismiss()
    }
}

#Preview {
    AIImportView(kind: .pdf, existingDeckCount: 0)
        .modelContainer(PreviewData.container())
        .environment(AISettingsStore(
            defaults: UserDefaults(suiteName: "preview.ai.settings")!
        ))
}
