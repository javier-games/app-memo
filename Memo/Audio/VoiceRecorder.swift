//
//  VoiceRecorder.swift
//  Memo
//

import AVFoundation
import OSLog

/// Records one clip for a card.
@Observable
final class VoiceRecorder {

    enum State: Equatable {
        case idle
        case recording
        case recorded
        /// The user has not allowed the microphone.
        case denied
        case failed(String)
    }

    /// Long enough for a word, a sentence, or a short example, and short
    /// enough that clips stay small for iCloud and for exports.
    static let limit: TimeInterval = 30

    /// AAC in an M4A file: what iOS records natively, smaller than MP3 at the
    /// same quality, and playable everywhere. Mono at a speech bitrate is
    /// about a quarter of a megabyte a minute.
    static let settings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: 44_100,
        AVNumberOfChannelsKey: 1,
        AVEncoderBitRateKey: 32_000,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]

    private(set) var state = State.idle
    private(set) var elapsed: TimeInterval = 0

    /// Recent input levels, 0...1, oldest first, for drawing.
    private(set) var levels: [Double] = Array(repeating: 0, count: 24)

    private(set) var recording: (data: Data, duration: TimeInterval)?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var ticker: Task<Void, Never>?

    private let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("memo-recording-\(UUID().uuidString).m4a")

    @ObservationIgnored
    private static let logger = Logger(subsystem: AppConfiguration.loggingSubsystem, category: "Audio")

    @MainActor
    func start() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            state = .denied
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            // Mixing, so music the user is listening to keeps going.
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)

            let recorder = try AVAudioRecorder(url: url, settings: Self.settings)
            recorder.isMeteringEnabled = true
            guard recorder.record(forDuration: Self.limit) else {
                state = .failed(String(localized: "Recording could not start."))
                return
            }

            self.recorder = recorder
            recording = nil
            elapsed = 0
            state = .recording

            ticker = Task { @MainActor [weak self] in
                while let self, let recorder = self.recorder, recorder.isRecording {
                    recorder.updateMeters()
                    self.elapsed = recorder.currentTime
                    self.push(level: Self.normalized(recorder.averagePower(forChannel: 0)))
                    try? await Task.sleep(for: .milliseconds(60))
                }
                guard !Task.isCancelled else { return }
                self?.finish()
            }
        } catch {
            Self.logger.error("Could not record: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    /// Ends the recording early. Reaching the limit ends it on its own.
    func stop() {
        recorder?.stop()
    }

    /// Throws away whatever was recorded.
    func discard() {
        ticker?.cancel()
        ticker = nil
        recorder?.stop()
        recorder = nil
        try? FileManager.default.removeItem(at: url)
    }

    private func finish() {
        ticker = nil
        recorder = nil

        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            state = .failed(String(localized: "Nothing was recorded."))
            return
        }

        let duration = (try? AVAudioPlayer(data: data).duration) ?? elapsed
        recording = (data, duration)
        state = .recorded
    }

    private func push(level: Double) {
        levels.removeFirst()
        levels.append(level)
    }

    /// Decibels, -160...0, onto 0...1, with quiet room noise near the bottom.
    static func normalized(_ power: Float) -> Double {
        let floor: Float = -50
        guard power > floor else { return 0 }
        return Double((power - floor) / -floor)
    }
}
