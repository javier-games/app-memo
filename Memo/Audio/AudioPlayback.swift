//
//  AudioPlayback.swift
//  Memo
//

import AVFoundation
import OSLog

/// When card audio plays without being asked.
enum AudioPlaybackMode: String, Codable, CaseIterable, Identifiable {

    /// Each side plays as it is shown.
    case automatic

    /// Only the play buttons play anything.
    case manual

    /// Automatic while headphones are connected, manual otherwise.
    case automaticWithHeadphones

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:               String(localized: "Automatic")
        case .manual:                  String(localized: "Manual")
        case .automaticWithHeadphones: String(localized: "Automatic with Headphones")
        }
    }

    var explanation: String {
        switch self {
        case .automatic:
            String(localized: "Each side of a card plays its audio as it is shown.")
        case .manual:
            String(localized: "Audio plays only when you tap a play button.")
        case .automaticWithHeadphones:
            String(localized: "Automatic while headphones are connected, and manual when they are not, so practising in public stays quiet.")
        }
    }

    /// Asked at the moment a side is shown, so plugging headphones in or out
    /// takes effect on the very next card.
    func playsAutomatically(headphonesConnected: Bool) -> Bool {
        switch self {
        case .automatic:               true
        case .manual:                  false
        case .automaticWithHeadphones: headphonesConnected
        }
    }
}

enum AudioRoute {

    /// Wired and wireless headphones alike, AirPods included.
    static var hasHeadphones: Bool {
        let headphones: Set<AVAudioSession.Port> = [
            .headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE,
        ]
        return AVAudioSession.sharedInstance().currentRoute.outputs
            .contains { headphones.contains($0.portType) }
    }
}

/// Plays card audio, one clip at a time, for the whole app.
///
/// Anything that plays goes through the one shared instance, so starting a
/// clip always stops the last one: the hint stops the card, turning the card
/// stops the hint, a new card stops both.
///
/// Whatever else is playing on the phone — music, a podcast — carries on at
/// full volume underneath.
@Observable
final class AudioPlayer {

    /// Why a clip is playing, which decides whether the silent switch counts.
    enum Trigger {
        /// Played because a side was shown. Silenced by the silent switch.
        case automatic
        /// Played because the user pressed something. Plays regardless.
        case user
    }

    /// The caller's name for what is playing, or `nil` when nothing is.
    private(set) var playingID: String?

    /// How far through the playing clip, 0...1.
    private(set) var progress: Double = 0

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    @ObservationIgnored
    private static let logger = Logger(subsystem: AppConfiguration.loggingSubsystem, category: "Audio")

    func isPlaying(_ id: String) -> Bool { playingID == id }

    func play(_ data: Data, id: String, trigger: Trigger) {
        stop()

        do {
            try Self.prepareSession(for: trigger)

            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            guard player.play() else { return }

            self.player = player
            playingID = id
            progress = 0

            ticker = Task { @MainActor [weak self] in
                while let self, let player = self.player, player.isPlaying {
                    self.progress = player.duration > 0 ? player.currentTime / player.duration : 0
                    try? await Task.sleep(for: .milliseconds(50))
                }
                guard !Task.isCancelled else { return }
                self?.reset()
            }
        } catch {
            Self.logger.error("Could not play audio: \(error.localizedDescription)")
            reset()
        }
    }

    func stop() {
        ticker?.cancel()
        player?.stop()
        reset()
    }

    private func reset() {
        ticker = nil
        player = nil
        playingID = nil
        progress = 0
    }

    /// Ambient for automatic playback, which is what makes the silent switch
    /// silence it; playback for anything pressed, which ignores the switch.
    /// Both mix with other audio rather than pausing or lowering it.
    private static func prepareSession(for trigger: Trigger) throws {
        let session = AVAudioSession.sharedInstance()

        switch trigger {
        case .automatic:
            try session.setCategory(.ambient, mode: .default)
        case .user:
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        }

        try session.setActive(true)
    }
}
