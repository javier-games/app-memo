//
//  AudioRecorderView.swift
//  Memo
//

import SwiftUI

/// Records one clip for a card, lets it be heard, and hands it back.
struct AudioRecorderView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(AudioPlayer.self) private var player

    /// What is being recorded, such as "Front".
    let title: String

    let onUse: (_ data: Data, _ duration: TimeInterval) -> Void

    @State private var recorder = VoiceRecorder()

    private static let previewID = "recorder-preview"

    var body: some View {

        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                levels

                Text("\(Self.format(shownTime)) / \(Self.format(VoiceRecorder.limit))")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()

                recordButton

                if recorder.state == .recorded {
                    HStack(spacing: 32) {
                        Button {
                            if player.isPlaying(Self.previewID) {
                                player.stop()
                            } else if let data = recorder.recording?.data {
                                player.play(data, id: Self.previewID, trigger: .user)
                            }
                        } label: {
                            Label(
                                player.isPlaying(Self.previewID) ? "Stop" : "Listen",
                                systemImage: player.isPlaying(Self.previewID) ? "stop.fill" : "play.fill"
                            )
                        }

                        Button {
                            player.stop()
                            Task { await recorder.start() }
                        } label: {
                            Label("Redo", systemImage: "arrow.counterclockwise")
                        }
                    }
                }

                message

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        if let recording = recorder.recording {
                            onUse(recording.data, recording.duration)
                        }
                        dismiss()
                    }
                    .disabled(recorder.state != .recorded)
                }
            }
            .onDisappear {
                player.stop()
                recorder.discard()
            }
        }
    }

    private var shownTime: TimeInterval {
        recorder.state == .recorded ? (recorder.recording?.duration ?? 0) : recorder.elapsed
    }

    private var levels: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(recorder.levels.enumerated()), id: \.offset) { _, level in
                Capsule()
                    .fill(recorder.state == .recording ? Color.red : Color.secondary.opacity(0.4))
                    .frame(width: 4, height: 6 + 50 * level)
            }
        }
        .frame(height: 60)
        .animation(.linear(duration: 0.06), value: recorder.levels)
        .accessibilityHidden(true)
    }

    private var recordButton: some View {
        Button {
            if recorder.state == .recording {
                recorder.stop()
            } else {
                player.stop()
                Task { await recorder.start() }
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.red, lineWidth: 3)
                    .frame(width: 72, height: 72)

                if recorder.state == .recording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 28, height: 28)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 58, height: 58)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: recorder.state)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.state == .recording ? "Stop recording" : "Record")
    }

    @ViewBuilder
    private var message: some View {
        switch recorder.state {
        case .idle:
            Text("Tap to record. Recording stops on its own after \(Int(VoiceRecorder.limit)) seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .denied:
            VStack(spacing: 8) {
                Text("Memo needs permission to use the microphone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            }
        case .failed(let reason):
            Text(reason)
                .font(.footnote)
                .foregroundStyle(.red)
        case .recording, .recorded:
            EmptyView()
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
