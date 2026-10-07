//
//  SettingsView.swift
//  Memo
//

import SwiftUI

/// Settings that apply to the whole app, as opposed to one deck or one
/// practice run. Opens on a list of areas, each with a screen of its own.
struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {

        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DecksSettingsView()
                    } label: {
                        Label("Decks", systemImage: "rectangle.stack")
                    }

                    NavigationLink {
                        AIConnectionSettingsView()
                    } label: {
                        Label("AI Connection", systemImage: "sparkles")
                    }
                }

                if AppConfiguration.isCloudSyncAvailable {
                    CloudSyncSettings()
                }
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

private struct AIConnectionSettingsView: View {

    var body: some View {
        Form {
            AIToolsSettings()
        }
        .navigationTitle("AI Connection")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Says whether decks are reaching iCloud. There is nothing to switch: sync
/// follows the iCloud account signed in on the device.
private struct CloudSyncSettings: View {

    @Environment(CloudSyncMonitor.self) private var monitor

    @State private var account: CloudSyncStatus?

    var body: some View {

        let activity = monitor.activity

        Section {
            LabeledContent("Account", value: account?.userDescription ?? "…")
                .task { account = await CloudSyncStatus.current() }

            if account == .available {
                LabeledContent("Sync", value: activity.summary)

                if let lastSuccess = activity.lastSuccess {
                    LabeledContent(
                        "Last Synced",
                        value: lastSuccess.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                if let error = activity.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("iCloud")
        } footer: {
            Text("Your decks are kept the same on every device signed in to your iCloud account. Nobody else can see them.")
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

        Section {
            Picker("Assistant", selection: $ai.settings.provider) {
                Text("None").tag(AIProvider?.none)

                ForEach(AIProvider.allCases) { provider in
                    Text(provider.title).tag(AIProvider?.some(provider))
                }
            }
            .disabled(isConnecting)
        } header: {
            Text("AI Tools")
        } footer: {
            Text("Used to create decks from text files and PDFs. The assistant you connect charges your API account for every file you send, separately from any subscription you have with it.")
        }

        if let provider = ai.settings.provider {
            connection(for: provider)
        }
    }

    @ViewBuilder
    private func connection(for provider: AIProvider) -> some View {
        if ai.isConnected(provider) {
            Section {
                LabeledContent("Method", value: String(localized: "API Key"))
                LabeledContent("Status", value: String(localized: "Connected"))
                    // The services add and retire models, so the list saved
                    // at connection time is refreshed whenever this is shown.
                    .task(id: provider) { await refreshModels(for: provider) }

                let models = ai.availableModels(for: provider)
                if models.isEmpty {
                    LabeledContent("Model", value: ai.model(for: provider))
                } else {
                    let groups = provider.grouped(models)

                    Picker("Model", selection: modelBinding(for: provider)) {
                        if !groups.known.isEmpty {
                            Section("Recommended") {
                                ForEach(groups.known, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                        }

                        // Not checked by Memo. One that cannot read files
                        // fails on the first import with the service's own
                        // message.
                        if !groups.other.isEmpty {
                            Section("Other") {
                                ForEach(groups.other, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
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
                Text("Your key is kept in this device's Keychain and is sent only to \(provider.company).")
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

    /// A failure here is not shown: the saved list still works, and the user
    /// did not ask for anything.
    private func refreshModels(for provider: AIProvider) async {
        guard let key = ai.apiKey(for: provider),
              let models = try? await provider.makeClient().models(apiKey: key)
        else { return }

        ai.updateModels(models, for: provider)
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
        .environment(CloudSyncMonitor())
        .environment(PracticeSettingsStore(
            defaults: UserDefaults(suiteName: "preview.practice.settings")!
        ))
        .environment(AISettingsStore(
            defaults: UserDefaults(suiteName: "preview.ai.settings")!
        ))
}
