//
//  ReviewScheduleSettingsView.swift
//  Memo
//

import SwiftUI

/// The app-wide Review Schedule: the intervals that lower a learned card's
/// progress over time, one after another from the day it was learned.
struct ReviewScheduleSettingsView: View {

    @Environment(PracticeSettingsStore.self) private var store

    var body: some View {

        @Bindable var store = store

        Form {
            Section {
                ForEach($store.reviewSchedule.intervals) { $interval in
                    NavigationLink {
                        ReviewIntervalEditor(interval: $interval)
                    } label: {
                        Text(interval.summary)
                    }
                }
                .onDelete { store.reviewSchedule.intervals.remove(atOffsets: $0) }
                .onMove { store.reviewSchedule.intervals.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    store.reviewSchedule.intervals.append(
                        ReviewInterval(
                            every: .init(value: 1, unit: .month),
                            lasting: .init(value: 3, unit: .month)
                        )
                    )
                } label: {
                    Label("Add Interval", systemImage: "plus")
                }
            } header: {
                Text("Intervals")
            } footer: {
                Text("Once a card is learned, its progress goes down by these steps, one interval after another. A period in which the card was answered takes nothing off. This brings cards you have not seen for a while back up in Least Practiced. Each card can turn this off in its editor.")
            }

            Section {
                Button("Reset to Defaults", role: .destructive) {
                    store.reviewSchedule = .default
                }
                .disabled(store.reviewSchedule == .default)
            }
        }
        .navigationTitle("Review Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !store.reviewSchedule.intervals.isEmpty {
                EditButton()
            }
        }
    }
}

/// One interval: how often, by how much, and for how long.
private struct ReviewIntervalEditor: View {

    @Binding var interval: ReviewInterval

    var body: some View {
        Form {
            Section("Every") {
                durationRows($interval.every)
            }

            Section {
                Toggle("Back to Zero", isOn: $interval.resetsProgress)

                if !interval.resetsProgress {
                    Stepper(value: $interval.decrease, in: ReviewInterval.decreaseRange) {
                        valueRow("Lower By", value: interval.decrease)
                    }
                }
            } header: {
                Text("Progress")
            }

            Section {
                durationRows($interval.lasting)
            } header: {
                Text("For")
            } footer: {
                Text(interval.summary)
            }
        }
        .navigationTitle("Interval")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func durationRows(_ duration: Binding<ReviewDuration>) -> some View {
        Stepper(value: duration.value, in: ReviewDuration.valueRange) {
            valueRow("Amount", value: duration.wrappedValue.value)
        }

        Picker("Unit", selection: duration.unit) {
            ForEach(ReviewDuration.Unit.allCases) { unit in
                Text(unit.title).tag(unit)
            }
        }
    }

    private func valueRow(_ title: LocalizedStringKey, value: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

#Preview {
    NavigationStack {
        ReviewScheduleSettingsView()
    }
    .environment(PracticeSettingsStore(
        defaults: UserDefaults(suiteName: "preview.review.schedule")!
    ))
}
