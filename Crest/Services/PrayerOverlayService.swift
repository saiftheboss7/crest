import Foundation
import Observation
import AppKit

extension Notification.Name {
    /// Posted after a prayer overlay window (start or ending) closes without
    /// being replaced. Overlays from the two services stack when the user
    /// leaves one open (most recently fired on top); this lets the sibling
    /// service restore key status to its still-visible window underneath so
    /// its keyboard shortcuts keep working.
    static let prayerOverlayWindowDidClose = Notification.Name("prayerOverlayWindowDidClose")
}

@MainActor @Observable
final class PrayerOverlayService {
    private let prayerTimeService: PrayerTimeService
    /// Timers armed from the daily schedule; rebuilt on every refresh pass.
    private var scheduledTimers: [String: Timer] = [:]
    /// User-initiated snooze timers, kept separate from `scheduledTimers` so
    /// the periodic schedule rebuild cannot invalidate a pending snooze.
    private var snoozeTimers: [String: Timer] = [:]
    private var dismissedPrayers: Set<String> = []
    /// Prayers whose reminder already showed for the current waqt, so the
    /// catch-up path in `scheduleOverlays` does not re-fire them every minute.
    private var firedPrayers: Set<String> = []
    private var refreshTimer: Timer?
    private(set) var overlayWindow: PrayerOverlayWindow?
    private(set) var activePrayer: Prayer?
    /// True while the visible overlay came from the Testing tab; dismissing a
    /// test overlay must not mark the real reminder as dismissed for the day.
    private var activeOverlayIsTest = false

    init(prayerTimeService: PrayerTimeService) {
        self.prayerTimeService = prayerTimeService
        startPeriodicRefresh()
        scheduleOverlays()

        NotificationCenter.default.addObserver(
            forName: .prayerOverlayWindowDidClose,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.restoreKeyWindowIfVisible()
            }
        }
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
            let action = PrayerOverlayScheduling.startReminderAction(
                prayer: prayer,
                prayerStart: prayerTime.time,
                jamaatTime: resolvedJamaatTime(for: prayerTime),
                isEnabled: perPrayer[prayer.rawValue] ?? true,
                isDismissed: dismissedPrayers.contains(prayer.rawValue),
                hasAlreadyFired: firedPrayers.contains(prayer.rawValue),
                now: now
            )

            switch action {
            case .skip:
                continue

            case .fireNow:
                // Fire time already passed but is still within the grace
                // window: app launched mid-window, woke from sleep, or the
                // timer was lost to a reschedule race.
                fireOverlay(for: prayer)

            case .schedule(let fireTime):
                let delay = max(fireTime.timeIntervalSince(now), 0.1)
                let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        self?.fireOverlay(for: prayer)
                    }
                }
                RunLoop.main.add(timer, forMode: .common)
                scheduledTimers[prayer.rawValue] = timer
            }
        }
    }

    func dismissOverlay() {
        if let prayer = activePrayer, !activeOverlayIsTest {
            dismissedPrayers.insert(prayer.rawValue)
        }
        overlayWindow?.close()
        overlayWindow = nil
        activePrayer = nil
        activeOverlayIsTest = false
        NotificationCenter.default.post(name: .prayerOverlayWindowDidClose, object: nil)
    }

    func snoozeOverlay(minutes: Int) {
        guard let prayer = activePrayer else { return }
        overlayWindow?.close()
        overlayWindow = nil
        activePrayer = nil
        activeOverlayIsTest = false
        NotificationCenter.default.post(name: .prayerOverlayWindowDidClose, object: nil)

        snoozeTimers[prayer.rawValue]?.invalidate()
        let snoozeTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(minutes * 60), repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.fireOverlay(for: prayer)
            }
        }
        RunLoop.main.add(snoozeTimer, forMode: .common)
        snoozeTimers[prayer.rawValue] = snoozeTimer
    }

    /// Called by SleepWakeService on wake. A fresh scheduling pass re-arms
    /// future timers (run-loop timers drift across sleep) and its catch-up
    /// path fires any reminder whose fire time passed during sleep while the
    /// reminder window is still open.
    func handleWake() {
        scheduleOverlays()
    }

    @discardableResult
    func triggerOverlay1TestNow() -> Bool {
        guard prayerTimeService.isEnabled else { return false }

        // Pick the same prayer the production scheduling path would have used.
        let targetPrayer: Prayer?
        if let next = prayerTimeService.nextPrayer, next != .sunrise {
            targetPrayer = next
        } else {
            targetPrayer = Prayer.adjustable.first
        }
        guard let prayer = targetPrayer else { return false }

        // Bypass the production gates in `fireOverlay` (DND, dismissed set);
        // the test button exists to verify the overlay UI renders, so it
        // should always show. `isTest: true` keeps dismissing a test overlay
        // from suppressing the real reminder later today.
        showOverlayWindow(prayer: prayer,
                          prayerTime: prayerTimeService.timeForPrayer(prayer) ?? Date(),
                          isJamaat: false,
                          isTest: true)
        return true
    }

    /// Testing-tab preview of the gold-accented jamaat variant of Overlay 1.
    @discardableResult
    func triggerJamaatTestNow() -> Bool {
        guard prayerTimeService.isEnabled else { return false }

        let targetPrayer: Prayer?
        if let next = prayerTimeService.nextPrayer, next != .sunrise {
            targetPrayer = next
        } else {
            targetPrayer = Prayer.adjustable.first
        }
        guard let prayer = targetPrayer else { return false }

        let entry = prayerTimeService.todayPrayers.first { $0.prayer == prayer }
        let jamaatTime = entry.flatMap { resolvedJamaatTime(for: $0) }
        showOverlayWindow(prayer: prayer,
                          prayerTime: jamaatTime ?? prayerTimeService.timeForPrayer(prayer) ?? Date(),
                          isJamaat: true,
                          isTest: true)
        return true
    }

    // MARK: - Private

    private func fireOverlay(for prayer: Prayer) {
        guard prayerTimeService.isEnabled else { return }
        guard !dismissedPrayers.contains(prayer.rawValue) else { return }

        let defaults = UserDefaults.standard
        let pKey = prayer.rawValue

        let dnds = (defaults.dictionary(forKey: AppSettingsKey.prayerOverrideDND) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerOverrideDND
        let overrideDND = dnds[pKey] ?? true

        if !overrideDND {
            // Respect DND/Focus: skip while DND is active. `firedPrayers` is
            // deliberately not marked here, so the catch-up path retries on
            // the next refresh and the reminder still shows if Focus ends
            // while the reminder window is open.
            if let dndEnabled = UserDefaults(suiteName: "com.apple.notificationcenterui")?.bool(forKey: "doNotDisturb"),
               dndEnabled {
                return
            }
        }

        firedPrayers.insert(pKey)
        scheduledTimers.removeValue(forKey: pKey)?.invalidate()
        snoozeTimers.removeValue(forKey: pKey)?.invalidate()

        // Show the prayer's actual start time (or jamaat time when one
        // applies), not the moment the timer happened to fire. Jamaat firings
        // get their own gold-accented styling so the two reminders read
        // differently at a glance.
        let entry = prayerTimeService.todayPrayers.first { $0.prayer == prayer }
        let jamaatTime = entry.flatMap { resolvedJamaatTime(for: $0) }
        showOverlayWindow(prayer: prayer,
                          prayerTime: jamaatTime ?? entry?.time ?? Date(),
                          isJamaat: jamaatTime != nil,
                          isTest: false)
    }

    private func showOverlayWindow(prayer: Prayer, prayerTime: Date, isJamaat: Bool, isTest: Bool) {
        dismissOverlayWindowOnly()

        Task { @MainActor in
            AlertSoundService.shared.playPrayerOverlayAlert(for: prayer)
        }

        activePrayer = prayer
        activeOverlayIsTest = isTest
        let endTime = prayerTimeService.prayerEndTime(prayer)
        let window = PrayerOverlayWindow(
            prayer: prayer,
            prayerTime: prayerTime,
            prayerEndTime: endTime,
            isJamaat: isJamaat,
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

    /// When the sibling overlay (stacked on top) closes, hand key status back
    /// to this service's still-visible window so Esc/Return/snooze shortcuts
    /// work without requiring a click.
    private func restoreKeyWindowIfVisible() {
        guard let window = overlayWindow, window.isVisible else { return }
        window.makeKeyAndOrderFront(nil)
    }

    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupExpiredState()
                self?.scheduleOverlays()
            }
        }
        RunLoop.main.add(refreshTimer!, forMode: .common)
    }

    /// Clears dismissed/fired markers once a prayer's reminder window
    /// (fire time plus grace) has fully passed, so the same prayer can
    /// remind again tomorrow. Clearing any earlier would let the catch-up
    /// path re-fire a reminder the user already handled.
    private func cleanupExpiredState() {
        let now = Date()
        func isExpired(_ key: String) -> Bool {
            guard let prayer = Prayer(rawValue: key),
                  let entry = prayerTimeService.todayPrayers.first(where: { $0.prayer == prayer })
            else { return true }
            let deadline = PrayerOverlayScheduling.validUntil(
                prayerStart: entry.time,
                jamaatTime: resolvedJamaatTime(for: entry)
            )
            return deadline < now
        }
        dismissedPrayers = dismissedPrayers.filter { !isExpired($0) }
        firedPrayers = firedPrayers.filter { !isExpired($0) }
    }

    private func resolvedJamaatTime(for prayerTime: PrayerTime) -> Date? {
        let jamaatEnabled = UserDefaults.standard.object(forKey: AppSettingsKey.jamaatTimesEnabled) as? Bool
            ?? AppSettingsDefault.jamaatTimesEnabled
        guard jamaatEnabled else { return nil }
        return prayerTime.jamaatTime
    }
}
