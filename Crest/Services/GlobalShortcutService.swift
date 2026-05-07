import AppKit
import Observation

@MainActor @Observable
final class GlobalShortcutService {
    private let meetingAlertService: MeetingAlertService
    private var globalMonitor: Any?
    private var localMonitor: Any?

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppSettingsKey.joinMeetingShortcutEnabled) as? Bool
            ?? AppSettingsDefault.joinMeetingShortcutEnabled
    }

    init(meetingAlertService: MeetingAlertService) {
        self.meetingAlertService = meetingAlertService
        registerShortcuts()
    }

    func registerShortcuts() {
        unregisterShortcuts()
        guard isEnabled else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    func unregisterShortcuts() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCmd = flags.contains(.command)
        let isShift = flags.contains(.shift)
        let keyJ = event.charactersIgnoringModifiers?.lowercased() == "j"

        guard isCmd, isShift, keyJ,
              !flags.contains(.option),
              !flags.contains(.control)
        else { return false }

        joinNextMeeting()
        return true
    }

    private func joinNextMeeting() {
        guard let meeting = meetingAlertService.nextMeetingLink() else { return }
        NSWorkspace.shared.open(meeting.link.url)
    }
}
