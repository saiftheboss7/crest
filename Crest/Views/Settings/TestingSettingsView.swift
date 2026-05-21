import SwiftUI

struct TestingSettingsView: View {
    var onTestMeetingAlertNow: (() -> Bool)?
    var onTestOverlay1Now: (() -> Bool)?
    var onTestOverlay2Now: (() -> Bool)?
    var onTestJamaatAlertNow: (() -> Bool)?

    @AppStorage(AppSettingsKey.islamicModeEnabled) private var islamicModeEnabled = AppSettingsDefault.islamicModeEnabled
    @AppStorage(AppSettingsKey.meetingAlertSoundEnabled) private var meetingAlertSoundEnabled = AppSettingsDefault.meetingAlertSoundEnabled
    @AppStorage(AppSettingsKey.prayerOverlaySoundEnabled) private var prayerOverlaySoundEnabled = AppSettingsDefault.prayerOverlaySoundEnabled

    @State private var meetingStatus: String?
    @State private var overlay1Status: String?
    @State private var overlay2Status: String?
    @State private var jamaatStatus: String?
    @State private var meetingSoundStatus: String?
    @State private var prayerSoundStatus: String?

    var body: some View {
        Form {
            Section("Sounds") {
                testButtonRow(
                    title: "Meeting Alert Sound",
                    buttonTitle: "Test Meeting Sound Now",
                    status: meetingSoundStatus,
                    isEnabled: meetingAlertSoundEnabled,
                    disabledHint: "Enable Play sound for meeting alerts in General settings first.",
                    action: triggerMeetingSound
                )

                testButtonRow(
                    title: "Prayer Overlay Sound",
                    buttonTitle: "Test Prayer Sound Now",
                    status: prayerSoundStatus,
                    isEnabled: prayerOverlaySoundEnabled,
                    disabledHint: "Enable Play sound on start reminder in Islamic Mode settings first.",
                    action: triggerPrayerSound
                )
            }

            Section("Alerts") {
                testButtonRow(
                    title: "Meeting Alert",
                    buttonTitle: "Test Meeting Alert Now",
                    status: meetingStatus,
                    isEnabled: onTestMeetingAlertNow != nil,
                    action: triggerMeetingAlert
                )

                testButtonRow(
                    title: "Overlay 1",
                    buttonTitle: "Test Overlay 1 Now",
                    status: overlay1Status,
                    isEnabled: onTestOverlay1Now != nil,
                    action: triggerOverlay1
                )

                testButtonRow(
                    title: "Overlay 2",
                    buttonTitle: "Test Overlay 2 Now",
                    status: overlay2Status,
                    isEnabled: onTestOverlay2Now != nil,
                    action: triggerOverlay2
                )

                testButtonRow(
                    title: "Jamaat Alert",
                    buttonTitle: "Test Jamaat Alert Now",
                    status: jamaatStatus,
                    isEnabled: onTestJamaatAlertNow != nil,
                    action: triggerJamaatAlert
                )
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func testButtonRow(
        title: String,
        buttonTitle: String,
        status: String?,
        isEnabled: Bool,
        disabledHint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.callout.weight(.medium))

            Button(buttonTitle, action: action)
                .disabled(!isEnabled)

            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !isEnabled, let hint = disabledHint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func triggerMeetingSound() {
        AlertSoundService.shared.playMeetingAlert()
        meetingSoundStatus = "Meeting alert sound played."
    }

    private func triggerPrayerSound() {
        AlertSoundService.shared.playPrayerOverlayAlert(for: .fajr)
        prayerSoundStatus = "Prayer overlay sound played."
    }

    private func triggerMeetingAlert() {
        let didTrigger = onTestMeetingAlertNow?() ?? false
        meetingStatus = didTrigger ? "Meeting alert test triggered." : "Unable to trigger meeting alert."
    }

    private func triggerOverlay1() {
        guard islamicModeEnabled else {
            overlay1Status = "Enable Islamic Mode first."
            return
        }

        let didTrigger = onTestOverlay1Now?() ?? false
        overlay1Status = didTrigger
            ? "Overlay 1 test triggered."
            : "Unable to trigger Overlay 1. Check Islamic Mode and service setup."
    }

    private func triggerOverlay2() {
        guard islamicModeEnabled else {
            overlay2Status = "Enable Islamic Mode first."
            return
        }

        let didTrigger = onTestOverlay2Now?() ?? false
        overlay2Status = didTrigger
            ? "Overlay 2 test triggered."
            : "Unable to trigger Overlay 2. Check Islamic Mode and service setup."
    }

    private func triggerJamaatAlert() {
        guard islamicModeEnabled else {
            jamaatStatus = "Enable Islamic Mode first."
            return
        }

        let didTrigger = onTestJamaatAlertNow?() ?? false
        jamaatStatus = didTrigger
            ? "Jamaat alert test triggered."
            : "Unable to trigger Jamaat alert. Check Islamic Mode and service setup."
    }
}
