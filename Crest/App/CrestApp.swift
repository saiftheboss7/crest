import AppKit
import SwiftUI

@main
struct CrestApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var clock = ClockService()
    @State private var calendarService = CalendarService()
    @State private var locationService = LocationService()
    @State private var prayerTimeService: PrayerTimeService?

    var body: some Scene {
        let prayerService = resolvedPrayerTimeService
        let _ = appDelegate.setup(
            calendarService: calendarService,
            prayerTimeService: prayerService
        )

        MenuBarExtra {
            PopoverView(
                clock: clock,
                calendarService: calendarService,
                prayerTimeService: prayerService
            )
        } label: {
            MenuBarLabel(
                clock: clock,
                calendarService: calendarService,
                prayerTimeService: prayerService
            )
        }
        .menuBarExtraStyle(.window)

            Settings {
                SettingsView(
                    updater: appDelegate.updaterController.updater,
                    locationService: locationService,
                    prayerTimeService: prayerService,
                    notificationService: appDelegate.prayerNotificationService,
                onOverlaySettingsChanged: { appDelegate.prayerOverlayService?.scheduleOverlays() },
                onMeetingAlertSettingsChanged: { appDelegate.meetingAlertService?.scheduleAlerts() },
                onTestOverlay1Now: appDelegate.prayerOverlayService == nil ? nil : { appDelegate.triggerOverlay1TestNow() },
                onTestOverlay2Now: appDelegate.prayerEndingOverlayService == nil ? nil : { appDelegate.triggerOverlay2TestNow() },
                onTestMeetingAlertNow: appDelegate.meetingAlertService == nil ? nil : { appDelegate.triggerMeetingAlertTestNow() },
                onTestJamaatAlertNow: appDelegate.prayerNotificationService == nil ? nil : { appDelegate.triggerJamaatAlertTestNow() }
            )
        }
    }

    private static let menuBarIcon: NSImage = {
        let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "Crest")!
            .withSymbolConfiguration(config)!
        image.isTemplate = true
        return image
    }()

    private var resolvedPrayerTimeService: PrayerTimeService {
        if let existing = prayerTimeService { return existing }
        let service = PrayerTimeService(locationService: locationService)
        Task { @MainActor in prayerTimeService = service }
        return service
    }
}
