import AVFoundation
import UIKit

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
    }

    func play(_ sound: AppSound, haptic: UIImpactFeedbackGenerator.FeedbackStyle? = nil) {
        if soundEnabled {
            players[sound]?.play()
        }
        if let style = haptic {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}
