//
//  RepositorySettingsView.swift
//  Memo
//

import SwiftUI

/// Signs in to GitHub and chooses where decks are pushed and pulled.
struct RepositorySettingsView: View {

    @Environment(RepositorySettingsStore.self) private var repository
    @Environment(\.openURL) private var openURL

    private let client = GitHubClient()

    @State private var deviceCode: GitHubDeviceCode?
    @State private var signIn: Task<Void, Never>?
    @State private var repositories: [GitHubRepository] = []
    @State private var errorMessage: String?

    var body: some View {

        @Bindable var repository = repository

        Form {
            if repository.isSignedIn {
                Section {
                    LabeledContent("Account", value: repository.settings.accountLogin ?? "GitHub")
                        .task { await loadRepositories() }

                    Picker("Repository", selection: $repository.settings.repository) {
                        Text("None").tag(String?.none)

                        ForEach(repositoryNames, id: \.self) { name in
                            Text(name).tag(String?.some(name))
                        }
                    }

                    Toggle("One File for All Decks", isOn: $repository.settings.usesSingleFile)
                } header: {
                    Text("GitHub")
                } footer: {
                    Text(
                        repository.settings.usesSingleFile
                            ? "Every deck is kept in one file, \(RepositorySync.libraryPath)."
                            : "Each deck is kept in a file of its own, named after it."
                    )
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        repository.signOut()
                    }
                } footer: {
                    Text("Decks go to the repository as JSON, with their cards. Practice progress and bookmarks are never sent. An empty repository is set up the first time it is opened.")
                }
            } else if let deviceCode {
                Section {
                    Text(deviceCode.userCode)
                        .font(.system(.largeTitle, design: .monospaced).bold())
                        .frame(maxWidth: .infinity)
                        .textSelection(.enabled)

                    Button("Copy the Code and Open GitHub") {
                        UIPasteboard.general.string = deviceCode.userCode
                        openURL(deviceCode.verificationURL)
                    }

                    HStack {
                        ProgressView()
                        Text("Waiting for you to approve on GitHub…")
                            .padding(.leading, 8)
                    }

                    Button("Cancel", role: .cancel) { cancelSignIn() }
                } header: {
                    Text("Enter This Code on GitHub")
                } footer: {
                    Text("GitHub asks for this code and then for your approval. Come back here afterwards; nothing needs typing into Memo.")
                }
            } else {
                Section {
                    Button("Sign In with GitHub") { startSignIn() }
                } header: {
                    Text("GitHub")
                } footer: {
                    Text("Keep your decks in a GitHub repository, and push or pull them when you choose. You sign in on github.com; Memo never sees your password.")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Repository")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { signIn?.cancel() }
    }

    /// The chosen repository stays in the list even if the account can no
    /// longer see it, so the picker never shows a blank selection.
    private var repositoryNames: [String] {
        var names = repositories.map(\.fullName)
        if let chosen = repository.settings.repository, !names.contains(chosen) {
            names.insert(chosen, at: 0)
        }
        return names
    }

    private func startSignIn() {
        errorMessage = nil

        signIn = Task {
            do {
                let code = try await client.requestDeviceCode(clientID: AppConfiguration.gitHubClientID)
                deviceCode = code

                let token = try await client.waitForToken(
                    clientID: AppConfiguration.gitHubClientID,
                    code: code
                )
                let login = try await client.login(token: token)

                try repository.signIn(token: token, login: login)
            } catch is CancellationError {
                // Cancelled here; nothing to report.
            } catch {
                errorMessage = error.localizedDescription
            }

            deviceCode = nil
        }
    }

    private func cancelSignIn() {
        signIn?.cancel()
        deviceCode = nil
    }

    private func loadRepositories() async {
        guard let token = repository.token else { return }

        do {
            repositories = try await client.repositories(token: token)
        } catch is CancellationError {
            // The screen went away.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
