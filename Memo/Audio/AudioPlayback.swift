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
///
/// Nothing slow happens on the main thread. Setting up the audio session and
/// decoding a clip both take long enough to stall a card's animation, so they
/// run on ``AudioSession``'s queue and only the start itself comes back here.
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
    /// Set the moment a clip is asked for, so its button responds at once.
    private(set) var playingID: String?

    /// How far through the playing clip, 0...1.
    private(set) var progress: Double = 0

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    /// Identifies the latest request, so a clip that finishes preparing after
    /// something newer was asked for is dropped instead of played.
    @ObservationIgnored private var request = UUID()

    @ObservationIgnored
    private static let logger = Logger(subsystem: AppConfiguration.loggingSubsystem, category: "Audio")

    func isPlaying(_ id: String) -> Bool { playingID == id }

    func play(_ data: Data, id: String, trigger: Trigger) {
        stop()

        let request = UUID()
        self.request = request
        playingID = id
        progress = 0

        AudioSession.shared.queue.async { [weak self] in
            let prepared: AVAudioPlayer?
            do {
                try AudioSession.shared.prepare(for: trigger)
                let player = try AVAudioPlayer(data: data)
                player.prepareToPlay()
                prepared = player
            } catch {
                Self.logger.error("Could not play audio: \(error.localizedDescription)")
                prepared = nil
            }

            DispatchQueue.main.async {
                guard let self, self.request == request else { return }
                guard let prepared, prepared.play() else {
                    self.finish()
                    return
                }
                self.player = prepared
                self.track(prepared)
            }
        }
    }

    func stop() {
        guard playingID != nil || player != nil else { return }
        request = UUID()
        finish()
    }

    private func track(_ player: AVAudioPlayer) {
        ticker = Task { @MainActor [weak self] in
            while let self, self.player === player, player.isPlaying {
                self.progress = player.duration > 0 ? player.currentTime / player.duration : 0
                try? await Task.sleep(for: .milliseconds(50))
            }
            guard !Task.isCancelled, let self, self.player === player else { return }
            self.finish()
        }
    }

    /// Ends whatever is playing and lets go of the audio session, which tells
    /// any app it interrupted that it may carry on.
    private func finish() {
        ticker?.cancel()
        ticker = nil
        player?.stop()
        player = nil
        playingID = nil
        progress = 0
        AudioSession.shared.release()
    }
}

/// The app's one audio session, set up off the main thread.
///
/// Changing the category, and activating or deactivating the session, can
/// each take a noticeable moment; done on the main thread they made a card's
/// flip stutter. Everything here runs in order on one queue, so a release
/// followed straight away by a new clip cannot arrive the wrong way round.
final class AudioSession {

    static let shared = AudioSession()

    let queue = DispatchQueue(label: "games.javier.memo.audio-session", qos: .userInitiated)

    /// What the session is set up for now. Only touched on `queue`.
    private var configured: AudioPlayer.Trigger?
    private var isActive = false

    /// Ambient for automatic playback, which is what makes the silent switch
    /// silence it; playback for anything pressed, which ignores the switch.
    /// Both mix with other audio, so music is neither paused nor lowered. The category is only changed when it has to be: changing
    /// it under an active session is what could stop other apps' audio.
    ///
    /// Call on `queue`.
    func prepare(for trigger: AudioPlayer.Trigger) throws {
        let session = AVAudioSession.sharedInstance()

        if configured != trigger {
            if isActive {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)
                isActive = false
            }

            switch trigger {
            case .automatic:
                // Ambient always mixes; it does not take the option itself.
                try session.setCategory(.ambient, mode: .default)
            case .user:
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            }
            configured = trigger
        }

        if !isActive {
            try session.setActive(true)
            isActive = true
        }
    }

    /// Deactivates the session once nothing is playing, telling other apps
    /// they may resume if the system paused them.
    func release() {
        queue.async { [self] in
            guard isActive else { return }
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isActive = false
        }
    }

    /// Forgets the set-up, for when something else, such as the recorder,
    /// has changed the session itself.
    func invalidate() {
        queue.async { [self] in
            configured = nil
            isActive = false
        }
    }
}
