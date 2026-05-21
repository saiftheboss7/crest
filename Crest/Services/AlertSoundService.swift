import AVFoundation
import AppKit

@MainActor
final class AlertSoundService {
    static let shared = AlertSoundService()

    private var player: AVAudioPlayer?

    private init() {}

    func playMeetingAlert() {
        let url = URL(fileURLWithPath: "/System/Library/Sounds/Funk.aiff")
        play(url: url, volume: 1.0)
    }

    func playPrayerOverlayAlert(for prayer: Prayer) {
        let defaults = UserDefaults.standard
        let pKey = prayer.rawValue
        
        let sounds = (defaults.dictionary(forKey: AppSettingsKey.prayerSoundName) as? [String: String])
            ?? AppSettingsDefault.defaultPrayerSoundName
        let soundName = sounds[pKey] ?? "Soft Chime"
        
        let volumes = (defaults.dictionary(forKey: AppSettingsKey.prayerSoundVolume) as? [String: Double])
            ?? AppSettingsDefault.defaultPrayerSoundVolume
        let volume = volumes[pKey] ?? 0.7
        
        if soundName == "Silent" {
            return
        }
        
        // Map user-facing sound options to resource filenames or system fallbacks
        let resourceName: String
        let systemFallback: String
        
        switch soundName {
        case "Adhan — Makkah":
            resourceName = "adhan_makkah"
            systemFallback = "Hero"
        case "Adhan — Madinah":
            resourceName = "adhan_madinah"
            systemFallback = "Ping"
        case "Adhan — Egypt":
            resourceName = "adhan_egypt"
            systemFallback = "Sosumi"
        case "Soft Chime":
            resourceName = "chime"
            systemFallback = "Glass"
        case "Tasbih Bell":
            resourceName = "bell"
            systemFallback = "Tink"
        default:
            resourceName = "chime"
            systemFallback = "Glass"
        }
        
        // Attempt to play from app bundle first (e.g. custom wav, mp3, or caf files)
        let extensions = ["mp3", "caf", "wav", "aiff"]
        for ext in extensions {
            if let customURL = Bundle.main.url(forResource: resourceName, withExtension: ext) {
                play(url: customURL, volume: volume)
                return
            }
        }
        
        // Fall back to system default adhan.caf if it exists and the user selected an Adhan
        if soundName.contains("Adhan"),
           let adhanURL = Bundle.main.url(forResource: "adhan", withExtension: "caf") {
            play(url: adhanURL, volume: volume)
            return
        }
        
        // Fall back to system Library sound
        let systemURL = URL(fileURLWithPath: "/System/Library/Sounds/\(systemFallback).aiff")
        play(url: systemURL, volume: volume)
    }

    func playPreview(soundName: String, volume: Double) {
        let systemURL = URL(fileURLWithPath: "/System/Library/Sounds/\(soundName).aiff")
        play(url: systemURL, volume: volume)
    }

    func stopPreview() {
        player?.stop()
        player = nil
    }

    private func play(url: URL, volume: Double) {
        player?.stop()
        player = nil

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = Float(volume)
            player?.prepareToPlay()
            player?.play()
        } catch {
            NSSound.beep()
        }
    }
}
