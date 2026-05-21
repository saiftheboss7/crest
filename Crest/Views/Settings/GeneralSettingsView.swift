import SwiftUI
import ServiceManagement
import Sparkle

struct GeneralSettingsView: View {
    var updater: SPUUpdater
    var onMeetingAlertSettingsChanged: (() -> Void)?

    @AppStorage(AppSettingsKey.meetingAlertEnabled) private var meetingAlertEnabled = AppSettingsDefault.meetingAlertEnabled
    @AppStorage(AppSettingsKey.meetingAlertSoundEnabled) private var meetingAlertSoundEnabled = AppSettingsDefault.meetingAlertSoundEnabled
    @AppStorage(AppSettingsKey.joinMeetingShortcutEnabled) private var joinShortcutEnabled = AppSettingsDefault.joinMeetingShortcutEnabled
    @AppStorage(AppSettingsKey.meetingAlertOffsetMinutes) private var alertOffsetMinutes = AppSettingsDefault.meetingAlertOffsetMinutes

    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Section("Meetings") {
                Toggle("Fullscreen alert when meetings start", isOn: $meetingAlertEnabled)
                if meetingAlertEnabled {
                    Picker("Alert timing", selection: $alertOffsetMinutes) {
                        Text("At meeting start").tag(0)
                        Text("1 minute before").tag(1)
                        Text("2 minutes before").tag(2)
                        Text("5 minutes before").tag(5)
                    }
                    .onChange(of: alertOffsetMinutes) { _, _ in
                        onMeetingAlertSettingsChanged?()
                    }
                }
                Toggle("Play sound for meeting alerts", isOn: $meetingAlertSoundEnabled)

                Toggle("Global shortcut to join next meeting", isOn: $joinShortcutEnabled)
                if joinShortcutEnabled {
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        Text("⌘⇧J")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                    }
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("Updates") {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
