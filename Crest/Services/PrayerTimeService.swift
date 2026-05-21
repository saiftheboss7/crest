import Foundation
import Observation
import Adhan

@MainActor @Observable
final class PrayerTimeService {
    private let locationService: LocationService
    private var timer: Timer?
    private var lastComputedDay: Int = -1
    private var rawPrayerTimes: PrayerTimes?

    private(set) var todayPrayers: [PrayerTime] = []
    private(set) var currentPrayer: Prayer?
    private(set) var nextPrayer: Prayer?
    private(set) var nextPrayerTime: Date?
    private(set) var countdownToNext: TimeInterval = 0
    private(set) var highlightedPrayer: Prayer?
    private(set) var isInActivePrayerWindow: Bool = false
    private(set) var highlightCountdown: TimeInterval = 0
    private(set) var hijriDateString: String = ""
    private(set) var islamicMidnight: Date?

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKey.islamicModeEnabled) as? Bool
            ?? AppSettingsDefault.islamicModeEnabled
    }

    init(locationService: LocationService) {
        self.locationService = locationService
        recompute()
        startTimer()
        
        let defaults = UserDefaults.standard
        let islamicEnabled = defaults.object(forKey: AppSettingsKey.islamicModeEnabled) as? Bool
            ?? AppSettingsDefault.islamicModeEnabled
        let staticEnabled = defaults.object(forKey: AppSettingsKey.staticLocationEnabled) as? Bool
            ?? AppSettingsDefault.staticLocationEnabled
        
        if islamicEnabled && !staticEnabled {
            locationService.requestLocation()
        }
        
        NotificationCenter.default.addObserver(
            forName: .locationDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.recompute()
        }
    }

    func recompute() {
        guard isEnabled, let prayers = prayerTimes(for: Date()) else {
            todayPrayers = []
            currentPrayer = nil
            nextPrayer = nil
            nextPrayerTime = nil
            countdownToNext = 0
            highlightedPrayer = nil
            isInActivePrayerWindow = false
            highlightCountdown = 0
            hijriDateString = ""
            islamicMidnight = nil
            rawPrayerTimes = nil
            return
        }

        rawPrayerTimes = prayers

        let jamaatEnabled = UserDefaults.standard.object(forKey: AppSettingsKey.jamaatTimesEnabled) as? Bool
            ?? AppSettingsDefault.jamaatTimesEnabled
        let jamaatOverrides = UserDefaults.standard.dictionary(forKey: "jamaatOverridePerPrayer") as? [String: Bool] ?? [:]
        let jamaatTimes = loadJamaatTimes()

        todayPrayers = [
            PrayerTime(prayer: .fajr, time: prayers.fajr,
                       jamaatTime: (jamaatEnabled && jamaatOverrides[Prayer.fajr.rawValue] == true) ? jamaatTime(for: .fajr, configuredTimes: jamaatTimes) : nil),
            PrayerTime(prayer: .sunrise, time: prayers.sunrise),
            PrayerTime(prayer: .dhuhr, time: prayers.dhuhr,
                       jamaatTime: (jamaatEnabled && jamaatOverrides[Prayer.dhuhr.rawValue] == true) ? jamaatTime(for: .dhuhr, configuredTimes: jamaatTimes) : nil),
            PrayerTime(prayer: .asr, time: prayers.asr,
                       jamaatTime: (jamaatEnabled && jamaatOverrides[Prayer.asr.rawValue] == true) ? jamaatTime(for: .asr, configuredTimes: jamaatTimes) : nil),
            PrayerTime(prayer: .maghrib, time: prayers.maghrib,
                       jamaatTime: (jamaatEnabled && jamaatOverrides[Prayer.maghrib.rawValue] == true) ? jamaatTime(for: .maghrib, configuredTimes: jamaatTimes) : nil),
            PrayerTime(prayer: .isha, time: prayers.isha,
                       jamaatTime: (jamaatEnabled && jamaatOverrides[Prayer.isha.rawValue] == true) ? jamaatTime(for: .isha, configuredTimes: jamaatTimes) : nil),
        ]

        islamicMidnight = SunnahTimes(from: prayers)?.middleOfTheNight

        let cal = Calendar(identifier: .gregorian)
        let dateComponents = cal.dateComponents([.year, .month, .day], from: Date())
        lastComputedDay = dateComponents.day ?? -1
        updateCurrentNext()
        computeHijriDate()
        NotificationCenter.default.post(name: .prayerTimesDidRecompute, object: nil)
    }

    func timeForPrayer(_ prayer: Prayer) -> Date? {
        todayPrayers.first(where: { $0.prayer == prayer })?.time
    }

    /// Returns the end of the prayer's valid window per Islamic fiqh.
    func prayerEndTime(_ prayer: Prayer) -> Date? {
        switch prayer {
        case .fajr:    return timeForPrayer(.sunrise)
        case .sunrise: return timeForPrayer(.dhuhr)
        case .dhuhr:   return timeForPrayer(.asr)
        case .asr:     return timeForPrayer(.maghrib)
        case .maghrib: return timeForPrayer(.isha)
        case .isha:    
            if let todayFajr = timeForPrayer(.fajr), Date() < todayFajr {
                return todayFajr
            }
            return tomorrowFajrTime()
        }
    }

    func tomorrowFajrTime() -> Date? {
        let cal = Calendar(identifier: .gregorian)
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) else { return nil }
        return prayerTimes(for: tomorrow)?.fajr
    }

    // MARK: - Private

    private func prayerTimes(for date: Date) -> PrayerTimes? {
        guard let coords = resolvedCoordinates() else { return nil }
        
        let methodRaw = UserDefaults.standard.string(forKey: AppSettingsKey.calculationMethod)
            ?? AppSettingsDefault.calculationMethod
        let madhabRaw = UserDefaults.standard.string(forKey: AppSettingsKey.madhab)
            ?? AppSettingsDefault.madhab
        let method = CalculationMethodOption(rawValue: methodRaw) ?? .moonsightingCommittee
        let madhab = MadhabOption(rawValue: madhabRaw) ?? .shafi
        let shafaqRaw = UserDefaults.standard.string(forKey: AppSettingsKey.shafaq)
            ?? AppSettingsDefault.shafaq
        let shafaq = ShafaqOption(rawValue: shafaqRaw) ?? .general

        var params = method.adhanMethod.params
        params.madhab = madhab.adhanMadhab
        params.shafaq = shafaq.adhanShafaq

        let adjustments = loadAdjustments()
        params.adjustments.fajr = adjustments["fajr"] ?? 0
        params.adjustments.dhuhr = adjustments["dhuhr"] ?? 0
        params.adjustments.asr = adjustments["asr"] ?? 0
        params.adjustments.maghrib = adjustments["maghrib"] ?? 0
        params.adjustments.isha = adjustments["isha"] ?? 0

        let cal = Calendar(identifier: .gregorian)
        let dateComponents = cal.dateComponents([.year, .month, .day], from: date)
        return PrayerTimes(coordinates: coords, date: dateComponents, calculationParameters: params)
    }

    private func updateCurrentNext() {
        let now = Date()

        var current: Prayer?
        var next: Prayer?

        if let todayFajr = timeForPrayer(.fajr), now < todayFajr {
            current = .isha
            next = .fajr
        } else {
            let ordered: [Prayer] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
            for (index, prayer) in ordered.enumerated() {
                guard let time = timeForPrayer(prayer) else { continue }
                if time <= now {
                    current = prayer
                    if index + 1 < ordered.count {
                        next = ordered[index + 1]
                    } else {
                        next = .fajr
                    }
                }
            }
        }

        currentPrayer = current
        nextPrayer = next

        if let next {
            if next == .fajr && current == .isha {
                if let todayFajr = timeForPrayer(.fajr), now < todayFajr {
                    nextPrayerTime = todayFajr
                    countdownToNext = max(0, todayFajr.timeIntervalSince(now))
                } else if let tFajr = tomorrowFajrTime() {
                    nextPrayerTime = tFajr
                    countdownToNext = max(0, tFajr.timeIntervalSince(now))
                } else {
                    nextPrayerTime = nil
                    countdownToNext = 0
                }
            } else if let time = timeForPrayer(next) {
                nextPrayerTime = time
                countdownToNext = max(0, time.timeIntervalSince(now))
            } else {
                nextPrayerTime = nil
                countdownToNext = 0
            }
        } else {
            nextPrayerTime = nil
            countdownToNext = 0
        }

        if let current = current,
           current != .sunrise,
           let endTime = prayerEndTime(current),
           endTime > now {
            highlightedPrayer = current
            isInActivePrayerWindow = true
            highlightCountdown = max(0, endTime.timeIntervalSince(now))
        } else {
            highlightedPrayer = next
            isInActivePrayerWindow = false
            highlightCountdown = countdownToNext
        }
    }

    private func computeHijriDate() {
        let offset = UserDefaults.standard.integer(forKey: AppSettingsKey.hijriDateOffset)
        let adjustedDate = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()

        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        let components = hijriCalendar.dateComponents([.year, .month, .day], from: adjustedDate)

        let formatter = DateFormatter()
        formatter.calendar = hijriCalendar
        formatter.dateStyle = .long

        let monthNames = [
            1: "Muharram", 2: "Safar", 3: "Rabi al-Awwal", 4: "Rabi al-Thani",
            5: "Jumada al-Ula", 6: "Jumada al-Thani", 7: "Rajab", 8: "Sha'ban",
            9: "Ramadan", 10: "Shawwal", 11: "Dhul Qi'dah", 12: "Dhul Hijjah"
        ]

        if let day = components.day, let month = components.month, let year = components.year {
            let monthName = monthNames[month] ?? "Unknown"
            hijriDateString = "\(day) \(monthName) \(year) AH"
        } else {
            hijriDateString = formatter.string(from: adjustedDate)
        }
    }

    private func loadAdjustments() -> [String: Int] {
        (UserDefaults.standard.dictionary(forKey: AppSettingsKey.prayerAdjustments) as? [String: Int])
            ?? AppSettingsDefault.defaultPrayerAdjustments
    }

    private func loadJamaatTimes() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: AppSettingsKey.jamaatTimes) as? [String: String])
            ?? AppSettingsDefault.defaultJamaatTimes
    }

    private func jamaatTime(for prayer: Prayer, configuredTimes: [String: String]) -> Date? {
        let timeString = configuredTimes[prayer.rawValue] ?? AppSettingsDefault.defaultJamaatTimes[prayer.rawValue]
        guard let timeString else { return nil }

        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0 ... 23).contains(hour),
              (0 ... 59).contains(minute)
        else {
            return nil
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: today)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateCurrentNext()

                let cal = Calendar(identifier: .gregorian)
                let today = cal.component(.day, from: Date())
                if today != self.lastComputedDay {
                    self.recompute()
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func resolvedCoordinates() -> Coordinates? {
        let defaults = UserDefaults.standard
        let staticEnabled = defaults.object(forKey: AppSettingsKey.staticLocationEnabled) as? Bool
            ?? AppSettingsDefault.staticLocationEnabled

        if staticEnabled {
            guard let latString = defaults.string(forKey: AppSettingsKey.staticLatitude),
                  let lonString = defaults.string(forKey: AppSettingsKey.staticLongitude),
                  let lat = Double(latString),
                  let lon = Double(lonString),
                  (-90.0 ... 90.0).contains(lat),
                  (-180.0 ... 180.0).contains(lon)
            else {
                return nil
            }
            return Coordinates(latitude: lat, longitude: lon)
        }

        return locationService.coordinates
    }

    /// Three-tier countdown — "1h 20m 45s" / "20m 45s" / "45s" — so the popover
    /// can show a live tick rather than the previous coarser "1h 20m" snap.
    static func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m \(secs)s"
        } else if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }

    /// Fraction of the active prayer window that's still ahead — full when the
    /// waqt just began, empty when it's about to end. Returns 0 when no prayer
    /// is currently active.
    var highlightProgress: Double {
        guard isInActivePrayerWindow,
              let prayer = highlightedPrayer,
              let start = timeForPrayer(prayer),
              let end = prayerEndTime(prayer)
        else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return max(0, min(1, highlightCountdown / total))
    }

    static func formatHighlightCountdown(_ seconds: TimeInterval, isActive: Bool) -> String {
        let timeString = formatCountdown(seconds)
        return isActive ? "\(timeString) left" : "Starts in \(timeString)"
    }

    func formattedCountdown() -> String {
        Self.formatCountdown(countdownToNext)
    }

    func formattedHighlightCountdown() -> String {
        Self.formatHighlightCountdown(highlightCountdown, isActive: isInActivePrayerWindow)
    }
}
