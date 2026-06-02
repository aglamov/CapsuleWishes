//
//  AudioFeedbackService.swift
//  CapsuleWishes
//
//  Created by Codex on 02.05.2026.
//

import AVFoundation
import Foundation

@MainActor
final class AudioFeedbackService {
    static let shared = AudioFeedbackService()

    private var players: [AudioCue: AVAudioPlayer] = [:]

    private init() {
        configureAudioSession()

        AudioCue.allCases.forEach { cue in
            players[cue] = makePlayer(for: cue)
        }
    }

    func play(_ cue: AudioCue) {
        guard UserDefaults.standard.object(forKey: AudioFeedbackPreferences.enabledKey) as? Bool ?? AudioFeedbackPreferences.defaultEnabled else { return }
        guard let player = players[cue] ?? makePlayer(for: cue) else { return }

        players[cue] = player
        player.stop()
        player.currentTime = 0
        player.volume = cue.volume
        player.play()
    }

    private func makePlayer(for cue: AudioCue) -> AVAudioPlayer? {
        guard let url = soundURL(for: cue) else {
            AppLog.audio.error("Missing audio cue: \(cue.fileName, privacy: .public)")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = cue.volume
            player.prepareToPlay()
            return player
        } catch {
            AppLog.audio.error("Could not prepare audio cue \(cue.fileName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func soundURL(for cue: AudioCue) -> URL? {
        Bundle.main.url(forResource: cue.fileName, withExtension: "wav", subdirectory: "Resources/Sounds") ??
        Bundle.main.url(forResource: cue.fileName, withExtension: "wav", subdirectory: "Sounds") ??
        Bundle.main.url(forResource: cue.fileName, withExtension: "wav")
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            AppLog.audio.error("Could not configure audio session: \(error.localizedDescription, privacy: .public)")
        }
    }
}
