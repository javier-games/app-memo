//
//  ImportReviewView.swift
//  Memo
//

import SwiftUI

/// Shows what an import would do, and asks before doing it.
///
/// Parsing a file is never the same step as committing it: the user sees what
/// was found first. Where the file disagrees with an edit made here, they see
/// both versions and choose.
struct ImportReviewView: View {

    @Environment(\.dismiss) private var dismiss

    let plan: DeckImportPlan

    /// Called with whether conflicts should be overwritten by the file.
    let onApply: (_ overwritingConflicts: Bool) -> Void

    var body: some View {

        NavigationStack {
            Form {

                Section {
                    if plan.hasChangesToApply {
                        count("New Decks", plan.newDeckCount)
                        count("New Cards", plan.newCardCount)
                        count("Decks Updated", plan.updatedDeckCount)
                        count("Cards Updated", plan.updatedCardCount)
                    } else if plan.hasConflicts {
                        Text("Nothing in the file is new besides the differences below.")
                    } else {
                        Text("Everything in the file is already in your library.")
                    }
                } footer: {
                    if plan.skippedCardCount > 0 {
                        Text("\(plan.skippedCardCount) card(s) were left out for having no front or no back.")
                    }
                }

                if plan.hasConflicts {
                    Section {
                        ForEach(plan.conflicts) { conflict in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(conflict.deckName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                LabeledContent("Yours", value: conflict.mine)
                                LabeledContent("File", value: conflict.theirs)
                            }
                        }
                    } header: {
                        Text("Conflicts")
                    } footer: {
                        Text("These were changed here after the file was made, or changed in the file without a newer date. Overwrite replaces yours with the file's. Don't Apply keeps yours. The rest of the import goes ahead either way.")
                    }

                    Section {
                        Button("Overwrite", role: .destructive) { finish(overwriting: true) }
                        Button("Don't Apply") { finish(overwriting: false) }
                    }
                } else if plan.hasChangesToApply {
                    Section {
                        Button("Import") { finish(overwriting: false) }
                    }
                }
            }
            .navigationTitle("Import Decks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isNothingToDo ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    private var isNothingToDo: Bool {
        !plan.hasChangesToApply && !plan.hasConflicts
    }

    /// A count that is zero says nothing worth a row.
    @ViewBuilder
    private func count(_ title: LocalizedStringKey, _ value: Int) -> some View {
        if value > 0 {
            LabeledContent(title, value: "\(value)")
        }
    }

    private func finish(overwriting: Bool) {
        onApply(overwriting)
        dismiss()
    }
}
