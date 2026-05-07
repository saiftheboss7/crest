import Foundation
import AppKit

@MainActor
final class SleepWakeService {
    private let prayerTimeService: PrayerTimeService
    private let prayerOverlayService: PrayerOverlayService
    private let prayerEndingOverlayService: PrayerEndingOverlayService
    private let prayerNotificationService: PrayerNotificationService
    private let meetingAlertService: MeetingAlertService

    init(prayerTimeService: PrayerTimeService,
         prayerOverlayService: PrayerOverlayService,
         prayerEndingOverlayService: PrayerEndingOverlayService,
         prayerNotificationService: PrayerNotificationService,
         meetingAlertService: MeetingAlertService) {
        self.prayerTimeService = prayerTimeService
        self.prayerOverlayService = prayerOverlayService
        self.prayerEndingOverlayService = prayerEndingOverlayService
        self.prayerNotificationService = prayerNotificationService
        self.meetingAlertService = meetingAlertService

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc nonisolated private func handleWake() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.prayerTimeService.recompute()
            self.prayerOverlayService.handleWake()
            self.prayerEndingOverlayService.handleWake()
            self.prayerNotificationService.scheduleAll()
            self.meetingAlertService.scheduleAlerts()
        }
    }
}
