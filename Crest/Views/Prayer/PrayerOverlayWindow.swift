import AppKit
import SwiftUI

final class PrayerOverlayWindow: NSPanel {
    private let onDismissAction: () -> Void
    private let onSnoozeAction: (Int) -> Void

    init(prayer: Prayer, prayerTime: Date, prayerEndTime: Date?, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void) {
        self.onDismissAction = onDismiss
        self.onSnoozeAction = onSnooze

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame

        super.init(
            contentRect: frame,
            styleMask: [.borderless],
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

        let overlayView = PrayerOverlayView(
            prayer: prayer,
            prayerTime: prayerTime,
            prayerEndTime: prayerEndTime,
            onDismiss: onDismiss,
            onSnooze: onSnooze
        )

        let hostingView = NSHostingView(rootView: overlayView)
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
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
    }

    override func keyDown(with event: NSEvent) {
        // Don't swallow keys here — the SwiftUI `.keyboardShortcut` declarations
        // on the buttons (1 → snooze 15m, 3 → snooze 30m, Esc → dismiss,
        // Return → Mark as Prayed) need them propagated to the responder
        // chain. The original "Esc is blocked, type inshallah" gate didn't
        // match the visible button labels.
        super.keyDown(with: event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
