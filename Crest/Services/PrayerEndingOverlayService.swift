import Foundation
import Observation
import AppKit

@MainActor @Observable
final class PrayerEndingOverlayService {
    private let prayerTimeService: PrayerTimeService
    private var scheduledTimers: [String: Timer] = [:]
    private var dismissedPrayers: Set<String> = []
    private var refreshTimer: Timer?
    private(set) var overlayWindow: PrayerEndingOverlayWindow?
    private(set) var activePrayer: Prayer?

    init(prayerTimeService: PrayerTimeService) {
        self.prayerTimeService = prayerTimeService
        startPeriodicRefresh()
        scheduleOverlays()
    }

    private func warningMinutes(for prayer: Prayer) -> TimeInterval {
        let defaults = UserDefaults.standard
        let overridden = (defaults.dictionary(forKey: "prayerLateReminderOverridden") as? [String: Bool]) ?? [:]
        if overridden[prayer.rawValue] == true {
            let offsets = (defaults.dictionary(forKey: AppSettingsKey.prayerLateReminderOffset) as? [String: Int])
                ?? AppSettingsDefault.defaultPrayerLateReminderOffset
            return TimeInterval(offsets[prayer.rawValue] ?? 15)
        }
        let globalOffset = defaults.integer(forKey: "lateReminderOffsetGlobal")
        return TimeInterval(globalOffset == 0 ? 15 : globalOffset)
    }

    func scheduleOverlays() {
        scheduledTimers.values.forEach { $0.invalidate() }
        scheduledTimers.removeAll()

        guard prayerTimeService.isEnabled else { return }

        // No master gate on `lateRemindersEnabled` — that toggle is a UI-level
        // mass-set shortcut that writes the same Bool to every per-prayer entry
        // in `overlay2PerPrayer`. The per-prayer dict is the single source of
        // truth here, so individual user overrides survive a global toggle.
        let perPrayer = (UserDefaults.standard.dictionary(forKey: AppSettingsKey.overlay2PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay2PerPrayer

        let now = Date()

        for prayerTime in prayerTimeService.todayPrayers {
            let prayer = prayerTime.prayer
            guard prayer != .sunrise else { continue }
            guard perPrayer[prayer.rawValue] ?? true else { continue }
            guard !dismissedPrayers.contains(prayer.rawValue) else { continue }

            guard let endTime = prayerTimeService.prayerEndTime(prayer) else { continue }

            let warningInterval = warningMinutes(for: prayer) * 60
            let fireTime = endTime.addingTimeInterval(-warningInterval)
            guard fireTime > now else { continue }

            let delay = fireTime.timeIntervalSince(now)
            let timer = Timer.scheduledTimer(withTimeInterval: max(delay, 0.1), repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.fireOverlay(for: prayer, prayerEndTime: endTime)
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

    /// Called by SleepWakeService on wake — fires any missed overlays still within the valid window.
    func handleWake() {
        guard prayerTimeService.isEnabled else { return }

        // See `scheduleOverlays()` — per-prayer dict is the source of truth.
        let perPrayer = (UserDefaults.standard.dictionary(forKey: AppSettingsKey.overlay2PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay2PerPrayer

        let now = Date()

        for prayerTime in prayerTimeService.todayPrayers {
            let prayer = prayerTime.prayer
            guard prayer != .sunrise else { continue }
            guard perPrayer[prayer.rawValue] ?? true else { continue }
            guard !dismissedPrayers.contains(prayer.rawValue) else { continue }

            guard let endTime = prayerTimeService.prayerEndTime(prayer) else { continue }
            let warningInterval = warningMinutes(for: prayer) * 60
            let fireTime = endTime.addingTimeInterval(-warningInterval)

            if fireTime <= now && endTime > now {
                fireOverlay(for: prayer, prayerEndTime: endTime)
                return
            }
        }

        scheduleOverlays()
    }

    @discardableResult
    func triggerOverlay2TestNow() -> Bool {
        guard prayerTimeService.isEnabled else { return false }

        let now = Date()
        let candidate = prayerTimeService.currentPrayer ?? prayerTimeService.nextPrayer ?? .fajr
        let prayer = candidate == .sunrise ? .dhuhr : candidate

        dismissedPrayers.remove(prayer.rawValue)
        let offset = warningMinutes(for: prayer)
        let prayerEndTime = prayerTimeService.prayerEndTime(prayer) ?? now.addingTimeInterval(offset * 60)
        fireOverlay(for: prayer, prayerEndTime: prayerEndTime)
        return true
    }

    // MARK: - Private

    private func fireOverlay(for prayer: Prayer, prayerEndTime: Date) {
        guard prayerTimeService.isEnabled else { return }
        guard !dismissedPrayers.contains(prayer.rawValue) else { return }

        let defaults = UserDefaults.standard
        let pKey = prayer.rawValue

        let overriddenDND = (defaults.dictionary(forKey: "prayerOverrideDNDOverridden") as? [String: Bool]) ?? [:]
        let overrideDND: Bool
        if overriddenDND[pKey] == true {
            let dnds = (defaults.dictionary(forKey: AppSettingsKey.prayerOverrideDND) as? [String: Bool])
                ?? AppSettingsDefault.defaultPrayerOverrideDND
            overrideDND = dnds[pKey] ?? true
        } else {
            let respectDNDGlobal = defaults.object(forKey: "lateReminderRespectDNDGlobal") as? Bool ?? true
            overrideDND = !respectDNDGlobal
        }

        if !overrideDND {
            // Respect DND Focus mode: skip if DND active
            if let dndEnabled = UserDefaults(suiteName: "com.apple.notificationcenterui")?.bool(forKey: "doNotDisturb"),
               dndEnabled {
                return
            }
        }

        let nextPrayer = nextPrayerAfter(prayer)
        let nextPrayerStartTime = nextPrayer.flatMap { prayerTimeService.timeForPrayer($0) }

        showOverlayWindow(prayer: prayer, prayerEndTime: prayerEndTime,
                          nextPrayer: nextPrayer, nextPrayerStartTime: nextPrayerStartTime)
        scheduledTimers.removeValue(forKey: prayer.rawValue)
    }

    private func nextPrayerAfter(_ prayer: Prayer) -> Prayer? {
        let sequence: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
        guard let idx = sequence.firstIndex(of: prayer) else { return nil }
        let nextIdx = idx + 1
        return nextIdx < sequence.count ? sequence[nextIdx] : .fajr
    }

    func snoozeOverlay(minutes: Int) {
        guard let prayer = activePrayer else { return }
        guard let endTime = prayerTimeService.prayerEndTime(prayer) else {
            dismissOverlay()
            return
        }

        dismissOverlayWindowOnly()
        activePrayer = nil

        let snoozeFireTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        guard snoozeFireTime < endTime else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fireOverlay(for: prayer, prayerEndTime: endTime)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        scheduledTimers[prayer.rawValue] = timer
    }

    private func showOverlayWindow(prayer: Prayer, prayerEndTime: Date,
                                    nextPrayer: Prayer?, nextPrayerStartTime: Date?) {
        dismissOverlayWindowOnly()

        activePrayer = prayer
        let window = PrayerEndingOverlayWindow(
            prayer: prayer,
            prayerEndTime: prayerEndTime,
            nextPrayer: nextPrayer,
            nextPrayerStartTime: nextPrayerStartTime,
            onDismiss: { [weak self] in self?.dismissOverlay() },
            onSnooze: { [weak self] mins in self?.snoozeOverlay(minutes: mins) }
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
                  let endTime = prayerTimeService.prayerEndTime(prayer) else {
                toRemove.append(key)
                continue
            }
            if endTime < now {
                toRemove.append(key)
            }
        }
        toRemove.forEach { dismissedPrayers.remove($0) }
    }
}
