import AppKit
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var meetingAlertService: MeetingAlertService?
    var globalShortcutService: GlobalShortcutService?
    var prayerOverlayService: PrayerOverlayService?
    var prayerEndingOverlayService: PrayerEndingOverlayService?
    private(set) var prayerNotificationService: PrayerNotificationService?
    private var sleepWakeService: SleepWakeService?
    private var localKeyMonitor: Any?

    @discardableResult
    func setup(calendarService: CalendarService, prayerTimeService: PrayerTimeService) -> Bool {
        guard meetingAlertService == nil else { return false }

        let alertService = MeetingAlertService(calendarService: calendarService)
        meetingAlertService = alertService
        globalShortcutService = GlobalShortcutService(meetingAlertService: alertService)

        let notifService = PrayerNotificationService(prayerTimeService: prayerTimeService)
        prayerNotificationService = notifService

        let overlay1 = PrayerOverlayService(prayerTimeService: prayerTimeService)
        prayerOverlayService = overlay1

        let overlay2 = PrayerEndingOverlayService(prayerTimeService: prayerTimeService)
        prayerEndingOverlayService = overlay2

        sleepWakeService = SleepWakeService(
            prayerTimeService: prayerTimeService,
            prayerOverlayService: overlay1,
            prayerEndingOverlayService: overlay2,
            prayerNotificationService: notifService,
            meetingAlertService: alertService
        )

        registerLocalShortcuts()
        return true
    }

    private func registerLocalShortcuts() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            switch event.charactersIgnoringModifiers {
            case ",":
                Self.openSettings()
                return nil
            case "q":
                NSApp.terminate(nil)
                return nil
            default:
                return event
            }
        }
    }

    static func openSettings() {
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            for window in NSApp.windows where !window.title.isEmpty && window.title != "Item-0" {
                window.orderFrontRegardless()
            }
        }
    }

    @discardableResult
    func triggerOverlay1TestNow() -> Bool {
        prayerOverlayService?.triggerOverlay1TestNow() ?? false
    }

    @discardableResult
    func triggerOverlay2TestNow() -> Bool {
        prayerEndingOverlayService?.triggerOverlay2TestNow() ?? false
    }

    @discardableResult
    func triggerMeetingAlertTestNow() -> Bool {
        meetingAlertService?.triggerTestAlert() ?? false
    }

    @discardableResult
    func triggerJamaatAlertTestNow() -> Bool {
        prayerOverlayService?.triggerOverlay1TestNow() ?? false
    }
}
