//
//  SettingsView.swift
//  Memo
//

import SwiftUI

/// Settings that apply to the whole app, as opposed to one deck or one
/// practice run.
struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        NavigationStack {
            Form {
                AIToolsSettings()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Chooses the AI tool and connects it.
private struct AIToolsSettings: View {

    @Environment(AISettingsStore.self) private var ai

    @State private var draftKey = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {

        @Bindable var ai = ai
        let provider = ai.settings.provider

        Section {
            Picker("Assistant", selection: $ai.settings.provider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }
            .disabled(isConnecting)
        } header: {
            Text("AI Tools")
        } footer: {
            Text("Used to create decks from text files and PDFs.")
        }

        if ai.isConnected(provider) {
            Section {
                LabeledContent("Method", value: String(localized: "API Key"))
                LabeledContent("Status", value: String(localized: "Connected"))

                let models = ai.availableModels(for: provider)
                if models.isEmpty {
                    LabeledContent("Model", value: ai.model(for: provider))
                } else {
                    Picker("Model", selection: modelBinding(for: provider)) {
                        ForEach(models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }

                Button("Disconnect", role: .destructive) {
                    ai.disconnect(provider)
                }
            } footer: {
                Text("Your key is kept in this device's Keychain and is sent only to \(provider.company).")
            }
        } else {
            Section {
                LabeledContent("Method", value: String(localized: "API Key"))

                SecureField(provider.keyPlaceholder, text: $draftKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isConnecting)

                Button {
                    connect(provider)
                } label: {
                    if isConnecting {
                        ProgressView()
                    } else {
                        Text("Connect")
                    }
                }
                .disabled(trimmedKey.isEmpty || isConnecting)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                Link("Get an API Key", destination: provider.keysPage)
            } footer: {
                Text("\(provider.title) is connected with an API key from \(provider.company), billed to your own account. Signing in with a \(provider.title) subscription is not something \(provider.company) offers to other apps.")
            }
            .onChange(of: provider) {
                draftKey = ""
                errorMessage = nil
            }
        }
    }

    private var trimmedKey: String {
        draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func modelBinding(for provider: AIProvider) -> Binding<String> {
        Binding(
            get: { ai.model(for: provider) },
            set: { ai.setModel($0, for: provider) }
        )
    }

    /// Asks the service for its models before saving anything, so a mistyped
    /// key is caught here and not in the middle of an import.
    private func connect(_ provider: AIProvider) {
        let key = trimmedKey

        errorMessage = nil
        isConnecting = true

        Task {
            do {
                let models = try await provider.makeClient().models(apiKey: key)
                try ai.connect(provider, apiKey: key, models: models)
                draftKey = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }
}

#Preview {
    SettingsView()
        .environment(AISettingsStore(
            defaults: UserDefaults(suiteName: "preview.ai.settings")!
        ))
}
