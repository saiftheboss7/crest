import SwiftUI

struct MeetingAlertView: View {
    let eventTitle: String
    let eventStartDate: Date
    let timeRange: String
    let calendarName: String
    let calendarColor: Color
    let serviceName: String
    let attendees: [String]
    let onJoin: () -> Void
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void

    @State private var currentTime = Date()
    @State private var timer: Timer?

    private var minutesUntilStart: Int {
        max(0, Int(ceil(eventStartDate.timeIntervalSince(currentTime) / 60)))
    }

    private var secondsUntilStart: Int {
        max(0, Int(eventStartDate.timeIntervalSince(currentTime)))
    }

    private var timeUntilText: String {
        let mins = minutesUntilStart
        if mins <= 0 { return "Starting now" }
        if mins == 1 { return "In 1 minute" }
        return "In \(mins) minutes"
    }

    private var countdownText: String {
        let total = secondsUntilStart
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private let themeColor = Color(red: 0.4, green: 0.3, blue: 0.8)

    var body: some View {
        ZStack {
            overlayBackground
            countdownBadge
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                Task { @MainActor in
                    currentTime = Date()
                }
            }
            if let timer { RunLoop.main.add(timer, forMode: .common) }
        }
        .onDisappear { timer?.invalidate() }
    }

    private var overlayBackground: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06)

            RadialGradient(
                stops: [
                    .init(color: themeColor.opacity(0.25), location: 0.0),
                    .init(color: themeColor.opacity(0.15), location: 0.15),
                    .init(color: themeColor.opacity(0.08), location: 0.3),
                    .init(color: themeColor.opacity(0.03), location: 0.5),
                    .init(color: .clear, location: 0.7)
                ],
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }

    private var countdownBadge: some View {
        VStack {
            Text(countdownText)
                .font(.system(size: 14, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "video.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeColor)
                .padding(.bottom, 24)

            Text(eventTitle)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 40)
                .padding(.bottom, 12)

            Text(timeUntilText)
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 6)

            Text(timeRange)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 32)

            actionButtons
                .padding(.bottom, 16)

            snoozeOptions

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(.white.opacity(0.1), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            Button(action: onJoin) {
                HStack(spacing: 6) {
                    Text("Join Video Call")
                        .font(.body.weight(.semibold))
                    Image(systemName: "video.fill")
                        .font(.caption)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [])
        }
    }

    private var snoozeOptions: some View {
        VStack(spacing: 10) {
            Text("Snooze")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.4))

            HStack(spacing: 8) {
                snoozeButton("1 minute", minutes: 1)
                snoozeButton("5 minutes", minutes: 5)
                snoozeButton("Until Event", minutes: max(1, minutesUntilStart))
            }
        }
    }

    private func snoozeButton(_ title: String, minutes: Int) -> some View {
        Button {
            onSnooze(minutes)
        } label: {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
