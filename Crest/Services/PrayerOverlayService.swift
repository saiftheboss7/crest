import Foundation
import Observation
import AppKit

@MainActor @Observable
final class PrayerOverlayService {
    private let prayerTimeService: PrayerTimeService
    private var scheduledTimers: [String: Timer] = [:]
    private var dismissedPrayers: Set<String> = []
    private var refreshTimer: Timer?
    private(set) var overlayWindow: PrayerOverlayWindow?
    private(set) var activePrayer: Prayer?

    private let warningMinutes: TimeInterval = 15
    private let wakeGraceMinutes: TimeInterval = 15

    init(prayerTimeService: PrayerTimeService) {
        self.prayerTimeService = prayerTimeService
        startPeriodicRefresh()
        scheduleOverlays()
    }

    func scheduleOverlays() {
        scheduledTimers.values.forEach { $0.invalidate() }
        scheduledTimers.removeAll()

        guard prayerTimeService.isEnabled else { return }

        let perPrayer = (UserDefaults.standard.dictionary(forKey: AppSettingsKey.overlay1PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay1PerPrayer

        let now = Date()

        for prayerTime in prayerTimeService.todayPrayers {
            let prayer = prayerTime.prayer
            guard prayer != .sunrise else { continue }
            guard perPrayer[prayer.rawValue] ?? true else { continue }
            guard !dismissedPrayers.contains(prayer.rawValue) else { continue }

            let fireTime = overlayFireTime(for: prayerTime)
            guard fireTime > now else { continue }

            let delay = fireTime.timeIntervalSince(now)
            let timer = Timer.scheduledTimer(withTimeInterval: max(delay, 0.1), repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.fireOverlay(for: prayer, triggerTime: fireTime)
                }
            }
            RunLoop.main.add(timer, forMode: .common)
            scheduledTimers[prayer.rawValue] = timer
        }
    }

    func dismissOverlay() {
        if let prayer = activePrayer {
            dismissedPrayers.insert(prayer.rawValue)
        }
        overlayWindow?.close()
        overlayWindow = nil
        activePrayer = nil
    }

    func snoozeOverlay(minutes: Int) {
        guard let prayer = activePrayer else { return }
        overlayWindow?.close()
        overlayWindow = nil
        activePrayer = nil

        let snoozeTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.fireOverlay(for: prayer, triggerTime: Date())
            }
        }
        RunLoop.main.add(snoozeTimer, forMode: .common)
        scheduledTimers["\(prayer.rawValue)-snooze"] = snoozeTimer
    }

    /// Called by SleepWakeService on wake — fires any missed overlays still within the valid window.
    func handleWake() {
        guard prayerTimeService.isEnabled else { return }

        let perPrayer = (UserDefaults.standard.dictionary(forKey: AppSettingsKey.overlay1PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay1PerPrayer

        let now = Date()
        let wakeGraceInterval = wakeGraceMinutes * 60

        for prayerTime in prayerTimeService.todayPrayers {
            let prayer = prayerTime.prayer
            guard prayer != .sunrise else { continue }
            guard perPrayer[prayer.rawValue] ?? true else { continue }
            guard !dismissedPrayers.contains(prayer.rawValue) else { continue }

            let fireTime = overlayFireTime(for: prayerTime)
            let validUntil = overlayWakeValidUntil(for: prayerTime, fireTime: fireTime)

            if fireTime <= now && validUntil > now && now.timeIntervalSince(fireTime) <= wakeGraceInterval {
                fireOverlay(for: prayer, triggerTime: fireTime)
                return
            }
        }

        scheduleOverlays()
    }

    @discardableResult
    func triggerOverlay1TestNow() -> Bool {
        guard prayerTimeService.isEnabled else { return false }

        let now = Date()

        if let next = prayerTimeService.nextPrayer,
           next != .sunrise {
            dismissedPrayers.remove(next.rawValue)
            fireOverlay(for: next, triggerTime: now)
            return true
        }

        if let fallbackPrayer = Prayer.adjustable.first {
            dismissedPrayers.remove(fallbackPrayer.rawValue)
            fireOverlay(for: fallbackPrayer, triggerTime: now)
            return true
        }

        return false
    }

    // MARK: - Private

    private func fireOverlay(for prayer: Prayer, triggerTime: Date) {
        guard prayerTimeService.isEnabled else { return }
        guard !dismissedPrayers.contains(prayer.rawValue) else { return }

        let defaults = UserDefaults.standard
        let pKey = prayer.rawValue

        let dnds = (defaults.dictionary(forKey: AppSettingsKey.prayerOverrideDND) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerOverrideDND
        let overrideDND = dnds[pKey] ?? true

        if !overrideDND {
            // Respect DND/Focus is active — skip if DND active
            if let dndEnabled = UserDefaults(suiteName: "com.apple.notificationcenterui")?.bool(forKey: "doNotDisturb"),
               dndEnabled {
                return
            }
        }

        showOverlayWindow(prayer: prayer, prayerTime: triggerTime)
        scheduledTimers.removeValue(forKey: prayer.rawValue)
    }

    private func showOverlayWindow(prayer: Prayer, prayerTime: Date) {
        dismissOverlayWindowOnly()

        Task { @MainActor in
            AlertSoundService.shared.playPrayerOverlayAlert(for: prayer)
        }

        activePrayer = prayer
        let endTime = prayerTimeService.prayerEndTime(prayer)
        let window = PrayerOverlayWindow(
            prayer: prayer,
            prayerTime: prayerTime,
            prayerEndTime: endTime,
            onDismiss: { [weak self] in self?.dismissOverlay() },
            onSnooze: { [weak self] minutes in self?.snoozeOverlay(minutes: minutes) }
        )
        overlayWindow = window
        window.showFullscreen()
    }

    private func dismissOverlayWindowOnly() {
        overlayWindow?.close()
        overlayWindow = nil
    }

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupDismissed()
                self?.scheduleOverlays()
            }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }

    private func cleanupDismissed() {
        let now = Date()
        var toRemove: [String] = []
        for key in dismissedPrayers {
            guard let prayer = Prayer(rawValue: key),
                  let time = prayerTimeService.timeForPrayer(prayer) else {
                toRemove.append(key)
                continue
            }
            // Clear dismissed state after the prayer time has passed
            if time < now {
                toRemove.append(key)
            }
        }
        toRemove.forEach { dismissedPrayers.remove($0) }
    }

    private func overlayFireTime(for prayerTime: PrayerTime) -> Date {
        if let jamaatTime = resolvedJamaatTime(for: prayerTime) {
            return jamaatTime
        }

        let warningInterval = warningMinutes * 60
        return prayerTime.time.addingTimeInterval(-warningInterval)
    }

    private func overlayWakeValidUntil(for prayerTime: PrayerTime, fireTime: Date) -> Date {
        if resolvedJamaatTime(for: prayerTime) != nil {
            return fireTime.addingTimeInterval(wakeGraceMinutes * 60)
        }

        return prayerTime.time
    }

    private func resolvedJamaatTime(for prayerTime: PrayerTime) -> Date? {
        let jamaatEnabled = UserDefaults.standard.object(forKey: AppSettingsKey.jamaatTimesEnabled) as? Bool
            ?? AppSettingsDefault.jamaatTimesEnabled
        guard jamaatEnabled else { return nil }
        return prayerTime.jamaatTime
    }
}
