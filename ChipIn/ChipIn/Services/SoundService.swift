import AudioToolbox
import AVFoundation
import UIKit

#if targetEnvironment(simulator)
private let chipInSoundHapticsEnabled = false
#else
private let chipInSoundHapticsEnabled = true
#endif

enum AppSound: String, CaseIterable {
    case expenseAdd = "expense_add"
    case moneyIn = "money_in"
    case moneyOut = "money_out"
    case settled = "settled"
}

@MainActor
class SoundService {
    static let shared = SoundService()
    private var players: [AppSound: AVAudioPlayer] = [:]

    private var soundEnabled: Bool {
        UserDefaults.standard.bool(forKey: "soundEnabled")
    }

    private init() {
        AppSound.allCases.forEach { sound in
            if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf"),
               let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players[sound] = player
            }
        }
        configureSessionIfNeeded()
    }

    private func configureSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        #if targetEnvironment(simulator)
        // Simulator is often muted for “ambient”; playback makes ChipIn tones easier to hear while testing.
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        #else
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        #endif
        try? session.setActive(true, options: [])
    }

    func play(_ sound: AppSound, haptic: UIImpactFeedbackGenerator.FeedbackStyle? = nil) {
        configureSessionIfNeeded()
        if soundEnabled {
            if let player = players[sound] {
                player.stop()
                player.currentTime = 0
                if !player.play() {
                    playSystemFallback(for: sound)
                }
            } else {
                playSystemFallback(for: sound)
            }
        }
        if chipInSoundHapticsEnabled, let style = haptic {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }

    /// Works when `.caf` files are not bundled. Avoid 1025 — it is a keyboard click, not a tone (often silent/wrong on Simulator).
    private func playSystemFallback(for sound: AppSound) {
        let id: SystemSoundID
        switch sound {
        case .expenseAdd: id = 1104
        case .moneyIn: id = 1013 // SMS received chime (1025 is a keyboard click)
        case .moneyOut: id = 1053
        case .settled: id = 1111
        }
        AudioServicesPlaySystemSound(id)
    }

}
