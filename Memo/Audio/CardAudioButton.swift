//
//  CardAudioButton.swift
//  Memo
//

import SwiftUI

/// Plays a clip, or stops it, with a ring that fills as it plays.
///
/// The same control everywhere audio appears: in the card editor, in the
/// corner of a card while practising, and beside the hint.
struct CardAudioButton: View {

    enum Style {
        /// On an ordinary background.
        case plain
        /// On a card's own colour.
        case onCard
    }

    @Environment(AudioPlayer.self) private var player

    /// What the player calls this clip while it plays.
    let id: String

    /// Read only when pressed, so a clip that is never played is never loaded.
    let data: () -> Data?

    var style = Style.plain
    var size: CGFloat = 30

    /// Shown beside the ring, for a button that needs a word.
    var label: LocalizedStringKey?

    private var isPlaying: Bool { player.isPlaying(id) }

    var body: some View {
        Button {
            if isPlaying {
                player.stop()
            } else if let data = data() {
                player.play(data, id: id, trigger: .user)
            }
        } label: {
            if let label {
                HStack(spacing: 6) {
                    ring
                    Text(label)
                }
            } else {
                ring
            }
        }
        .accessibilityLabel(isPlaying ? "Stop audio" : "Play audio")
    }

    private var ring: some View {
        AudioRing(isPlaying: isPlaying, progress: player.progress, style: style, size: size)
    }
}

/// The round play-or-stop face of an audio control, with the ring that fills
/// as a clip plays. Shared by every control that plays card audio, whatever
/// kind of control it sits in.
struct AudioRing: View {

    let isPlaying: Bool
    let progress: Double
    var style = CardAudioButton.Style.plain
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle()
                .fill(style == .onCard ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(.tertiarySystemFill)))

            if isPlaying {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.05), value: progress)
            }

            Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                .font(.system(size: size * 0.36))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: size, height: size)
    }
}
