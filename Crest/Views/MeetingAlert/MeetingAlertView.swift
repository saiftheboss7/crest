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
    @State private var totalDuration: Double = 0.0

    private var minutesUntilStart: Int {
        max(0, Int(ceil(eventStartDate.timeIntervalSince(currentTime) / 60)))
    }

    private var secondsUntilStart: Int {
        max(0, Int(eventStartDate.timeIntervalSince(currentTime)))
    }

    private var countdownText: String {
        let total = secondsUntilStart
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// Brighter sky-blue than the old `#0071E3`. Lifts contrast on the dark canvas
    /// from ~4:1 to ~8:1, comfortably clearing WCAG AAA 7:1 even at the centre
    /// of the radial glow.
    private let themeColor = Color(red: 90/255, green: 177/255, blue: 255/255) // #5AB1FF

    var body: some View {
        ZStack {
            overlayBackground
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if totalDuration == 0.0 {
                totalDuration = Double(max(1, secondsUntilStart))
            }
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
        // Matches the responsive glow used on the prayer overlays so all three
        // fullscreen alerts feel like siblings. Peak softened from 0.20 → 0.08 so
        // blue accent text in the centre still clears WCAG AAA 7:1.
        GeometryReader { geo in
            let diagonal = sqrt(geo.size.width * geo.size.width + geo.size.height * geo.size.height)
            let core = max(120, min(geo.size.width * 0.08, 260))
            let edge = max(1000, min(diagonal * 0.65, 2600))

            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06)

                RadialGradient(
                    stops: [
                        .init(color: themeColor.opacity(0.08), location: 0.0),
                        .init(color: themeColor.opacity(0.06), location: 0.25),
                        .init(color: themeColor.opacity(0.03), location: 0.55),
                        .init(color: themeColor.opacity(0.01), location: 0.85),
                        .init(color: .clear, location: 1.0)
                    ],
                    center: .center,
                    startRadius: core,
                    endRadius: edge
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .drawingGroup()
        }
    }

    private var mainContent: some View {
        GeometryReader { geo in
            // Same scale ladder as the prayer overlays — cohesive across all three
            // fullscreen alerts.
            let titleSize = max(60, min(geo.size.width * 0.07, 100))
            let timeSize = max(28, min(geo.size.width * 0.022, 40))
            let ringSize = max(200, min(geo.size.width * 0.18, 280))
            let ringStroke = max(5, min(geo.size.width * 0.004, 8))
            let ringDigitSize = ringSize * 0.26
            let ringLabelSize = ringSize * 0.06
            let pillTextSize = max(15, min(geo.size.width * 0.012, 20))
            let buttonTextSize = max(20, min(geo.size.width * 0.013, 24))
            let snoozeTextSize = max(15, min(geo.size.width * 0.011, 18))
            let metaSize = max(16, min(geo.size.width * 0.012, 22))

            let progress = max(0.0, min(1.0, Double(secondsUntilStart) / max(1.0, totalDuration)))

            VStack(spacing: 0) {
                Spacer()

                // COUNTDOWN RING — same construction as before, just scaled to the
                // viewport so it stays the focal element at any display size.
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: ringStroke)
                        .frame(width: ringSize, height: ringSize)
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(themeColor, style: StrokeStyle(lineWidth: ringStroke, lineCap: .round))
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: themeColor.opacity(0.4), radius: 10)
                        .animation(.linear(duration: 1), value: progress)

                    VStack(spacing: ringSize * 0.025) {
                        Text(countdownText)
                            .font(.system(size: ringDigitSize, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .tracking(-1)
                        // Was white@0.4 (~3.8:1) → @0.85 (~14:1).
                        Text(secondsUntilStart >= 60 ? "MINUTES" : "SECONDS")
                            .font(.system(size: ringLabelSize, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: ringSize, height: ringSize)
                .padding(.bottom, 36)

                // STARTING NOW / SOON pill — themeColor was #0071E3 (~4.2:1) →
                // #5AB1FF (~8:1). Pill text bumped up to a real size.
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color(red: 52/255, green: 199/255, blue: 89/255)) // System green
                        .frame(width: 10, height: 10)
                    Text(minutesUntilStart <= 0 ? "Starting now" : "Starting soon")
                        .font(.system(size: pillTextSize, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(themeColor)
                        .textCase(.uppercase)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(themeColor.opacity(0.14))
                )
                .overlay(
                    Capsule()
                        .stroke(themeColor.opacity(0.4), lineWidth: 1)
                )
                .padding(.bottom, 28)

                // TITLE — was 34pt → up to 100pt on big displays.
                Text(eventTitle)
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .tracking(-1.2)
                    .padding(.horizontal, 64)
                    .padding(.bottom, 14)

                // TIME RANGE — was title3 @0.7 (~9:1) → bigger, @0.92 (~16:1).
                Text(timeRange)
                    .font(.system(size: timeSize, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(0.5)
                    .padding(.bottom, 10)

                // ORGANIZER / ATTENDEES — was subheadline @0.5 (~5:1, AAA fail) →
                // bigger, @0.85 (~14:1).
                let organizerText = "Organized by \(calendarName) · \(attendees.count) attendees"
                Text(organizerText)
                    .font(.system(size: metaSize, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(0.4)
                    .padding(.bottom, 56)

                // PRIMARY ACTION — Join. Bigger tile, matches the prayer overlays.
                Button(action: onJoin) {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: buttonTextSize * 0.7))
                        Text("Join \(serviceName)")
                            .font(.system(size: buttonTextSize, weight: .bold))
                            .tracking(0.3)
                    }
                    .foregroundStyle(.white)
                    .frame(width: 360, height: 68)
                    .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
                .padding(.bottom, 22)

                // SNOOZE ROW — chunkier pills, AAA contrast text.
                HStack(spacing: 14) {
                    snoozePill(label: "Snooze 1m", key: "1", textSize: snoozeTextSize, action: { onSnooze(1) })
                    snoozePill(label: "Snooze 5m", key: "5", textSize: snoozeTextSize, action: { onSnooze(5) })
                    snoozePill(label: "Dismiss", key: "ESC", textSize: snoozeTextSize, action: onDismiss)
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.bottom, 40)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Snooze/Dismiss pill — same shape as the prayer overlays' snooze controls
    /// so all three fullscreen alerts feel like the same family.
    private func snoozePill(label: String, key: String, textSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(label)
                Text(key)
                    .font(.system(size: textSize - 4, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
            }
            .font(.system(size: textSize, weight: .medium))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
