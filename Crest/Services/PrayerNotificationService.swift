import Foundation
@preconcurrency import UserNotifications
import Observation

extension String {
    var deletingPathExtension: String {
        let parts = self.split(separator: ".")
        if parts.count > 1 {
            return parts.dropLast().joined(separator: ".")
        }
        return self
    }
    var pathExtension: String {
        let parts = self.split(separator: ".")
        if parts.count > 1 {
            return String(parts.last!)
        }
        return ""
    }
}

@MainActor @Observable
final class PrayerNotificationService {
    private let prayerTimeService: PrayerTimeService
    private var refreshTimer: Timer?
    private var lastScheduledDay: Int = -1

    private(set) var isAuthorized = false

    init(prayerTimeService: PrayerTimeService) {
        self.prayerTimeService = prayerTimeService
        checkAuthorization()
        scheduleAll()
        startDailyRefresh()
        
        NotificationCenter.default.addObserver(
            forName: .prayerTimesDidRecompute,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleAll()
        }
    }

    func requestAuthorization() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                self.isAuthorized = granted
                if granted { self.scheduleAll() }
            } catch {}
        }
    }

    func scheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard prayerTimeService.isEnabled else { return }

        let now = Date()

        let prayerNotifEnabled = UserDefaults.standard.object(forKey: AppSettingsKey.prayerNotificationsEnabled) as? Bool
            ?? AppSettingsDefault.prayerNotificationsEnabled

        if prayerNotifEnabled {
            let perPrayer = (UserDefaults.standard.dictionary(forKey: AppSettingsKey.prayerNotificationPerPrayer) as? [String: Bool])
                ?? AppSettingsDefault.defaultPrayerNotificationPerPrayer

            let sounds = (UserDefaults.standard.dictionary(forKey: AppSettingsKey.prayerSoundName) as? [String: String])
                ?? AppSettingsDefault.defaultPrayerSoundName

            for prayerTime in prayerTimeService.todayPrayers {
                let prayer = prayerTime.prayer
                guard prayer != .sunrise else { continue }
                guard perPrayer[prayer.rawValue] ?? true else { continue }
                guard prayerTime.time > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(prayer.displayName) Prayer"
                content.body = "It's time for \(prayer.displayName) (\(prayer.arabicName))"

                let soundName = sounds[prayer.rawValue] ?? "Soft Chime"
                let soundFilename: String?
                switch soundName {
                case "Adhan — Makkah": soundFilename = "adhan_makkah.caf"
                case "Adhan — Madinah": soundFilename = "adhan_madinah.caf"
                case "Adhan — Egypt": soundFilename = "adhan_egypt.caf"
                case "Soft Chime": soundFilename = "chime.caf"
                case "Tasbih Bell": soundFilename = "bell.caf"
                case "Silent": soundFilename = nil
                default: soundFilename = "chime.caf"
                }

                if let soundFilename {
                    let name = soundFilename.deletingPathExtension
                    let ext = soundFilename.pathExtension
                    if Bundle.main.url(forResource: name, withExtension: ext) != nil {
                        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundFilename))
                    } else if soundName.contains("Adhan"),
                              Bundle.main.url(forResource: "adhan", withExtension: "caf") != nil {
                        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "adhan.caf"))
                    } else {
                        content.sound = .default
                    }
                } else {
                    content.sound = nil // Silent
                }

                let interval = prayerTime.time.timeIntervalSince(now)
                guard interval > 0 else { continue }

                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "prayer-\(prayer.rawValue)",
                    content: content,
                    trigger: trigger
                )
                center.add(request)
            }
        }

        lastScheduledDay = Calendar.current.component(.day, from: Date())
    }

    // MARK: - Private

    private func checkAuthorization() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            self.isAuthorized = settings.authorizationStatus == .authorized
        }
    }

    private func startDailyRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let today = Calendar.current.component(.day, from: Date())
                if today != self.lastScheduledDay {
                    self.scheduleAll()
                }
            }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }
}
