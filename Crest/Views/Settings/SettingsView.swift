import SwiftUI
import Sparkle

struct SettingsView: View {
    var updater: SPUUpdater
    var locationService: LocationService
    var prayerTimeService: PrayerTimeService
    var notificationService: PrayerNotificationService?
    var onOverlaySettingsChanged: (() -> Void)?
    var onMeetingAlertSettingsChanged: (() -> Void)?
    var onTestOverlay1Now: (() -> Bool)?
    var onTestOverlay2Now: (() -> Bool)?
    var onTestMeetingAlertNow: (() -> Bool)?
    var onTestJamaatAlertNow: (() -> Bool)?

    @AppStorage(AppSettingsKey.settingsSelectedTab) private var selectedTab = AppSettingsDefault.settingsSelectedTab

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                updater: updater,
                onMeetingAlertSettingsChanged: onMeetingAlertSettingsChanged
            )
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(0)

            CalendarSettingsView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(1)

            if let notifService = notificationService {
                IslamicSettingsView(
                    locationService: locationService,
                    prayerTimeService: prayerTimeService,
                    notificationService: notifService,
                    onOverlaySettingsChanged: onOverlaySettingsChanged
                )
                .tabItem {
                    Label("Islamic Mode", systemImage: "moon.stars")
                }
                .tag(2)
            } else {
                PlaceholderSettingsView(
                    title: "Islamic Mode",
                    description: "Prayer times, Hijri date, and overlay settings will appear here."
                )
                .tabItem {
                    Label("Islamic Mode", systemImage: "moon.stars")
                }
                .tag(2)
            }

            TestingSettingsView(
                onTestMeetingAlertNow: onTestMeetingAlertNow,
                onTestOverlay1Now: onTestOverlay1Now,
                onTestOverlay2Now: onTestOverlay2Now,
                onTestJamaatAlertNow: onTestJamaatAlertNow
            )
            .tabItem {
                Label("Testing", systemImage: "flask")
            }
            .tag(3)
        }
        .frame(width: 760, height: 600)
    }
}
