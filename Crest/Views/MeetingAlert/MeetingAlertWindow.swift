import AppKit
import SwiftUI
import EventKit

enum MeetingAlertAction {
    case join
    case dismiss
    case snooze(minutes: Int)
}

final class MeetingAlertWindow: NSPanel {
    private let onAction: (MeetingAlertAction) -> Void

    init(event: EKEvent, meetingLink: MeetingLink, onAction: @escaping (MeetingAlertAction) -> Void) {
        self.onAction = onAction

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false

        let alertView = MeetingAlertView(
            eventTitle: event.title ?? "Untitled Event",
            eventStartDate: event.startDate,
            timeRange: DateFormatting.eventTimeRange(
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay
            ),
            calendarName: event.calendar.title,
            calendarColor: Color(cgColor: event.calendar.cgColor),
            serviceName: meetingLink.service.rawValue,
            attendees: (event.attendees ?? []).compactMap { $0.name ?? $0.url.absoluteString },
            onJoin: { onAction(.join) },
            onDismiss: { onAction(.dismiss) },
            onSnooze: { minutes in onAction(.snooze(minutes: minutes)) }
        )

        let hostingView = NSHostingView(rootView: alertView)
        hostingView.frame = frame
        self.contentView = hostingView

        setupObservers()
    }

    init(title: String, startDate: Date, timeRange: String, serviceName: String, onAction: @escaping (MeetingAlertAction) -> Void) {
        self.onAction = onAction

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame

        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false

        let alertView = MeetingAlertView(
            eventTitle: title,
            eventStartDate: startDate,
            timeRange: timeRange,
            calendarName: "Test Calendar",
            calendarColor: .blue,
            serviceName: serviceName,
            attendees: [],
            onJoin: { onAction(.join) },
            onDismiss: { onAction(.dismiss) },
            onSnooze: { minutes in onAction(.snooze(minutes: minutes)) }
        )

        let hostingView = NSHostingView(rootView: alertView)
        hostingView.frame = frame
        self.contentView = hostingView

        setupObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func handleScreenParametersChanged() {
        updateFrameToMainScreen()
    }

    @objc private func handleSystemWake() {
        updateFrameToMainScreen()
    }

    private func updateFrameToMainScreen() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        self.setFrame(frame, display: true, animate: false)
        if let contentView = self.contentView {
            contentView.frame = CGRect(origin: .zero, size: frame.size)
        }
    }

    func showFullscreen() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onAction(.dismiss)
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
}
