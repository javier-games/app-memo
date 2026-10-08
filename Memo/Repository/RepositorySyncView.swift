//
//  RepositorySyncView.swift
//  Memo
//

import SwiftUI
import SwiftData

/// Compares the decks on this device with the ones in the repository, and
/// pushes or pulls the ones the user picks.
struct RepositorySyncView: View {

    @Environment(RepositorySettingsStore.self) private var repository
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\Deck.sortIndex), SortDescriptor(\Deck.createdAt)])
    private var decks: [Deck]

    var files: GitHubFiles = GitHubClient()

    @State private var snapshot: RepositorySnapshot?
    @State private var selection: Set<String> = []
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var pendingImport: DeckImportPlan?

    private var items: [RepositoryItem] {
        snapshot.map { RepositorySync.items(local: decks, snapshot: $0) } ?? []
    }

    private var selected: [RepositoryItem] {
        items.filter { selection.contains($0.id) }
    }

    var body: some View {

        NavigationStack {
            List {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if let snapshot {
                    problems(in: snapshot)

                    Section {
                        ForEach(items) { item in
                            row(for: item)
                        }
                    } header: {
                        Text(repository.settings.repository ?? "")
                    } footer: {
                        Text("Pull brings the repository's version here, and asks before replacing an edit of yours. Push writes your version to the repository. Progress and bookmarks are never sent.")
                    }

                    Section {
                        Button("Pull") { pull() }
                            .disabled(isWorking || !selected.contains(where: \.canPull))
                        Button("Push") { push() }
                            .disabled(isWorking || !selected.contains(where: \.canPush))
                    }
                } else if errorMessage == nil {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Reading the repository…")
                                .padding(.leading, 8)
                        }
                    }
                }
            }
            .navigationTitle("Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button {
                            Task { await load() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
            .sheet(item: $pendingImport) { plan in
                ImportReviewView(plan: plan) { overwritingConflicts in
                    DeckImporter.apply(
                        plan,
                        overwritingConflicts: overwritingConflicts,
                        into: modelContext,
                        after: decks.count
                    )
                    selection = []
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Rows

    @ViewBuilder
    private func problems(in snapshot: RepositorySnapshot) -> some View {
        let duplicates = snapshot.duplicates

        if !duplicates.isEmpty || !snapshot.unreadablePaths.isEmpty {
            Section {
                ForEach(duplicates) { duplicate in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(duplicate.name) is in the repository more than once")
                        Text(duplicate.paths.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(snapshot.unreadablePaths, id: \.self) { path in
                    Text("\(path) could not be read as decks")
                }
            } header: {
                Text("Needs Attention")
            } footer: {
                if !duplicates.isEmpty {
                    Text("A deck in two files cannot be synced, because there is no telling which copy is the right one. Remove one of them in the repository and refresh.")
                }
            }
        }
    }

    private func row(for item: RepositoryItem) -> some View {
        let isSelectable = item.canPull || item.canPush

        return Button {
            if selection.contains(item.id) {
                selection.remove(item.id)
            } else {
                selection.insert(item.id)
            }
        } label: {
            HStack {
                Image(systemName: selection.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelectable ? Color.accentColor : .secondary.opacity(0.4))

                Text(item.icon)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .foregroundStyle(.primary)
                    Text(description(of: item.state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .disabled(!isSelectable || isWorking)
    }

    private func description(of state: RepositoryItem.State) -> String {
        switch state {
        case .onlyHere:         String(localized: "Not in the repository yet")
        case .onlyInRepository: String(localized: "Not on this device")
        case .same:             String(localized: "Up to date")
        case .different:        String(localized: "Different here and in the repository")
        case .duplicated:       String(localized: "In the repository more than once")
        }
    }

    // MARK: - Work

    private func load() async {
        guard let name = repository.settings.repository, let token = repository.token else {
            errorMessage = GitHubFailure.notSignedIn.localizedDescription
            return
        }

        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            var entries = try await files.entries(in: name, token: token)

            // A repository with no commits has nowhere to put a file, so it
            // is given its first one.
            if entries == nil {
                try await files.write(
                    Data(RepositorySync.readme.utf8),
                    to: RepositorySync.readmePath,
                    replacing: nil,
                    message: "Set up the repository for Memo Decks",
                    in: name,
                    token: token
                )
                entries = []
            }

            let paths = RepositorySync.deckPaths(
                among: entries ?? [],
                usesSingleFile: repository.settings.usesSingleFile
            )

            var contents: [(entry: GitHubEntry, data: Data)] = []
            for entry in paths {
                let data = try await files.contents(of: entry.path, in: name, token: token)
                contents.append((entry, data))
            }

            let loaded = RepositorySync.snapshot(of: contents)
            snapshot = loaded

            // Anything picked before the refresh may no longer be on offer.
            let offered = Set(RepositorySync.items(local: decks, snapshot: loaded).map(\.id))
            selection.formIntersection(offered)
        } catch is CancellationError {
            // The screen went away; nothing to report.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Goes through the same review as a file import, so an edit made here is
    /// never replaced without being shown first.
    private func pull() {
        let incoming = selected.filter(\.canPull).compactMap(\.remote).map { deck in
            var deck = deck
            deck.cardList = deck.cardList.filter(\.isComplete)
            return deck
        }
        guard !incoming.isEmpty else { return }

        pendingImport = DeckImporter.plan(
            DeckImporter.Preview(decks: incoming, skippedCardCount: 0),
            against: decks
        )
    }

    private func push() {
        guard let snapshot,
              let name = repository.settings.repository,
              let token = repository.token
        else { return }

        let outgoing = selected.filter(\.canPush).compactMap(\.local)
        guard !outgoing.isEmpty else { return }

        isWorking = true
        errorMessage = nil

        Task {
            do {
                let writes = try RepositorySync.writes(
                    pushing: outgoing,
                    snapshot: snapshot,
                    usesSingleFile: repository.settings.usesSingleFile
                )

                for write in writes {
                    try await files.write(
                        write.data,
                        to: write.path,
                        replacing: write.sha,
                        message: write.message,
                        in: name,
                        token: token
                    )
                }

                selection = []
            } catch {
                errorMessage = error.localizedDescription
            }

            // Either way what the repository holds has changed or is in
            // doubt, and the next push needs the new versions to quote.
            await load()
        }
    }
}
