import SwiftUI
import Adhan

struct PrayerEndingOverlayView: View {
    let prayer: Prayer
    let prayerEndTime: Date
    let nextPrayer: Prayer?
    let nextPrayerStartTime: Date?
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void

    @State private var remainingSeconds: Int
    @State private var timer: Timer?
    @State private var elapsedSeconds: Int = 0
    /// Locked at first appearance so the ring's `trim` shrinks from full to empty
    /// as the prayer window closes. Same pattern as `MeetingAlertView`.
    @State private var totalDuration: Double = 0.0

    init(prayer: Prayer, prayerEndTime: Date,
         nextPrayer: Prayer?, nextPrayerStartTime: Date?,
         onDismiss: @escaping () -> Void,
         onSnooze: @escaping (Int) -> Void) {
        self.prayer = prayer
        self.prayerEndTime = prayerEndTime
        self.nextPrayer = nextPrayer
        self.nextPrayerStartTime = nextPrayerStartTime
        self.onDismiss = onDismiss
        self.onSnooze = onSnooze
        let remaining = Int(max(0, prayerEndTime.timeIntervalSince(Date())))
        _remainingSeconds = State(initialValue: remaining)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var waqtEndsText: String? {
        guard remainingSeconds > 0 else { return nil }
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        if hours > 0 {
            return String(format: "Waqt ends in %dh %dm %ds", hours, minutes, seconds)
        } else {
            return String(format: "Waqt ends in %dm %ds", minutes, seconds)
        }
    }

    /// Brighter alert red than the previous #d94026 (which only made ~4.4:1).
    /// #FF7C7C measures ~8.2:1 on the dark canvas and ~7.2:1 even at the warmest
    /// part of the radial glow — comfortably WCAG AAA.
    private var urgencyColor: Color {
        Color(red: 255/255, green: 124/255, blue: 124/255) // #FF7C7C
    }

    private var autoDismissMinutes: Int {
        let defaults = UserDefaults.standard
        let autoDismiss = (defaults.dictionary(forKey: AppSettingsKey.prayerAutoDismissMinutes) as? [String: Int])
            ?? AppSettingsDefault.defaultPrayerAutoDismissMinutes
        return autoDismiss[prayer.rawValue] ?? 0
    }

    private var hijriDateString: String {
        let date = Date()
        let defaults = UserDefaults.standard
        let adjustment = defaults.integer(forKey: AppSettingsKey.hijriDateOffset)
        let calendar = Calendar.current
        let adjustedDate = calendar.date(byAdding: .day, value: adjustment, to: date) ?? date
        
        let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)
        let components = hijriCalendar.dateComponents([.year, .month, .day], from: adjustedDate)
        
        let monthNames = [
            1: "Muharram", 2: "Safar", 3: "Rabi al-Awwal", 4: "Rabi al-Thani",
            5: "Jumada al-Ula", 6: "Jumada al-Thani", 7: "Rajab", 8: "Sha'ban",
            9: "Ramadan", 10: "Shawwal", 11: "Dhul Qi'dah", 12: "Dhul Hijjah"
        ]
        
        if let day = components.day, let month = components.month, let year = components.year {
            let monthName = monthNames[month] ?? "Unknown"
            return "\(day) \(monthName) \(year) AH"
        } else {
            let formatter = DateFormatter()
            formatter.calendar = hijriCalendar
            formatter.dateStyle = .long
            return formatter.string(from: adjustedDate)
        }
    }

    private var qiblaText: String {
        let defaults = UserDefaults.standard
        // Manual ("static") mode overrides automatic. Coordinates live under different
        // keys in different storage shapes: cached coords are Double, static coords are
        // String (because the manual-entry text fields bind to String via @AppStorage).
        let isAutomatic = !defaults.bool(forKey: AppSettingsKey.staticLocationEnabled)
        let lat: Double
        let lon: Double
        if isAutomatic {
            lat = defaults.double(forKey: AppSettingsKey.cachedLatitude)
            lon = defaults.double(forKey: AppSettingsKey.cachedLongitude)
        } else {
            lat = Double(defaults.string(forKey: AppSettingsKey.staticLatitude) ?? "") ?? 0
            lon = Double(defaults.string(forKey: AppSettingsKey.staticLongitude) ?? "") ?? 0
        }

        if lat != 0.0 || lon != 0.0 {
            let coords = Coordinates(latitude: lat, longitude: lon)
            let direction = Qibla(coordinates: coords).direction
            return String(format: "Qibla %.0f°", direction)
        }
        return "Qibla 287°"
    }

    var body: some View {
        ZStack {
            overlayBackground
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startCountdown()
        }
        .onDisappear { timer?.invalidate() }
    }

    private var overlayBackground: some View {
        // Scale the glow with the viewport so it stays proportional to the
        // up-sized typography.
        GeometryReader { geo in
            let diagonal = sqrt(geo.size.width * geo.size.width + geo.size.height * geo.size.height)
            let core = max(120, min(geo.size.width * 0.08, 260))
            let edge = max(1000, min(diagonal * 0.65, 2600))

            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06) // #0a0a0c

                // Glow peak kept at 0.08 (so accent-coloured text in the centre
                // still clears WCAG AAA 7:1). Stops pushed further from centre so
                // the urgent red wash reaches toward the corners of the canvas.
                RadialGradient(
                    stops: [
                        .init(color: urgencyColor.opacity(0.08), location: 0.0),
                        .init(color: urgencyColor.opacity(0.06), location: 0.25),
                        .init(color: urgencyColor.opacity(0.03), location: 0.55),
                        .init(color: urgencyColor.opacity(0.01), location: 0.85),
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
            // Same responsive scale as Overlay 1 so both feel cohesive on every
            // display, just driven by the urgency palette.
            let titleSize = max(80, min(geo.size.width * 0.10, 140))
            let timeSize = max(30, min(geo.size.width * 0.025, 44))
            // Ring is the new focal element — go larger than the old static emoji circle.
            let ringSize = max(200, min(geo.size.width * 0.18, 280))
            let ringStroke = max(5, min(geo.size.width * 0.004, 8))
            let ringDigitSize = ringSize * 0.26
            let ringEmojiSize = ringSize * 0.16
            let ringLabelSize = ringSize * 0.06
            let pillTextSize = max(17, min(geo.size.width * 0.013, 22))
            let buttonTextSize = max(20, min(geo.size.width * 0.013, 24))
            let snoozeTextSize = max(15, min(geo.size.width * 0.011, 18))
            let verseSize = max(15, min(geo.size.width * 0.011, 18))

            // Trim fraction shrinks from 1.0 → 0.0 as the prayer window closes.
            let progress = totalDuration > 0
                ? max(0.0, min(1.0, Double(remainingSeconds) / totalDuration))
                : 0.0

            VStack(spacing: 0) {
                Spacer()

                // CIRCULAR COUNTDOWN RING — replaces the old static emoji circle.
                // Same construction as MeetingAlertView's ring: a faint track + a
                // trimmed arc in the urgency colour, rotating from 12 o'clock.
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: ringStroke)
                        .frame(width: ringSize, height: ringSize)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(urgencyColor, style: StrokeStyle(lineWidth: ringStroke, lineCap: .round))
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: urgencyColor.opacity(0.35), radius: 10)
                        .animation(.linear(duration: 1), value: progress)

                    VStack(spacing: ringSize * 0.025) {
                        // Small prayer emoji at the top of the dial for context.
                        Text(prayer.emoji)
                            .font(.system(size: ringEmojiSize))
                            .foregroundStyle(prayer == .fajr
                                             ? Color(red: 94/255, green: 124/255, blue: 226/255)
                                             : urgencyColor.opacity(0.9))

                        // Live MM:SS countdown — white@1.0 against the dark canvas is ~19:1.
                        Text(countdownDisplay)
                            .font(.system(size: ringDigitSize, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                            .tracking(-1)

                        // Label: uppercase letter-spaced, brighter than the old @0.4.
                        Text("REMAINING")
                            .font(.system(size: ringLabelSize, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(width: ringSize, height: ringSize)
                .padding(.bottom, 44)

                // Title — bigger. Urgent red lifted from #d94026 (4.4:1) to #FF7C7C
                // (~8.2:1) so it's now AAA on the dark canvas.
                Text("\(prayer.displayName) Ending")
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundColor(urgencyColor)
                    .tracking(-1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 18)

                // Waqt-ends-at subtitle — was 24pt @0.55 (6.2:1) → bigger, @0.92.
                Text("Waqt ends at \(Self.timeFormatter.string(from: prayerEndTime))")
                    .font(.system(size: timeSize, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(0.5)
                    .padding(.bottom, 10)

                // Hijri Date — was 14pt @0.35 (3.1:1) → bigger, @0.85 (~14:1).
                Text(hijriDateString)
                    .font(.system(size: pillTextSize - 2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(0.4)
                    .padding(.bottom, 32)

                // Waqt countdown pill — urgent red on red-tinted backdrop.
                if let waqtText = waqtEndsText {
                    HStack(spacing: 10) {
                        Text("⏱")
                            .font(.system(size: pillTextSize))
                        Text(waqtText)
                            .font(.system(size: pillTextSize, weight: .semibold))
                    }
                    .foregroundStyle(urgencyColor)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(urgencyColor.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(urgencyColor.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.bottom, 18)
                }

                // Next prayer / Qibla pill — text @0.92 (~16:1).
                if let next = nextPrayer, let startTime = nextPrayerStartTime {
                    HStack(spacing: 10) {
                        Text(next.emoji)
                            .font(.system(size: pillTextSize))
                        Text("Next: \(next.displayName) begins at \(Self.timeFormatter.string(from: startTime))")
                            .font(.system(size: pillTextSize - 2, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .padding(.bottom, 64)
                } else {
                    HStack(spacing: 10) {
                        Text("↖")
                            .font(.system(size: pillTextSize))
                        Text(qiblaText)
                            .font(.system(size: pillTextSize - 2, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                    .padding(.bottom, 64)
                }

                // Mark as Prayed — Tailwind dark-mode green pill:
                //   text   = green-400  (#4ade80)
                //   fill   = green-400 / 10
                //   border = green-500 / 20  (#22c55e at 20%)
                Button(action: onDismiss) {
                    Text("Mark as Prayed")
                        .font(.system(size: buttonTextSize, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(Color(red: 74/255, green: 222/255, blue: 128/255))
                        .frame(width: 340, height: 68)
                        .background(
                            Capsule()
                                .fill(Color(red: 74/255, green: 222/255, blue: 128/255).opacity(0.10))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.20), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .overlayButtonHover()
                .keyboardShortcut(.return, modifiers: [])
                .padding(.bottom, 26)

                // Snooze row — pills slightly bigger, text @0.92 (~16:1).
                // Each snooze pill is disabled when the snooze duration would
                // push past the waqt's end — no point reminding after the
                // window has closed. Dismiss is always enabled.
                HStack(spacing: 14) {
                    snoozePill(label: "Remind in 15m", key: "1", textSize: snoozeTextSize,
                               disabled: snoozeWouldExceedWaqt(minutes: 15),
                               action: { onSnooze(15) })
                        .keyboardShortcut("1", modifiers: [])
                    snoozePill(label: "Remind in 30m", key: "3", textSize: snoozeTextSize,
                               disabled: snoozeWouldExceedWaqt(minutes: 30),
                               action: { onSnooze(30) })
                        .keyboardShortcut("3", modifiers: [])
                    snoozePill(label: "Dismiss", key: "ESC", textSize: snoozeTextSize,
                               disabled: false, action: onDismiss)
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.bottom, 40)

                // Quran verse — was 13pt @0.4 (3.8:1) → bigger, italic, @0.78 (~11:1).
                Text("\"Verily, the prayer is enjoined on the believers at fixed hours.\" (Surah An-Nisa 4:103)")
                    .font(.system(size: verseSize, weight: .regular))
                    .italic()
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 64)
                    .padding(.bottom, 12)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// True when snoozing for `minutes` would push past the waqt's end.
    private func snoozeWouldExceedWaqt(minutes: Int) -> Bool {
        let snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        return snoozeUntil >= prayerEndTime
    }

    /// Snooze/Dismiss pill — shared shape across the three secondary actions.
    private func snoozePill(label: String, key: String, textSize: CGFloat, disabled: Bool, action: @escaping () -> Void) -> some View {
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
            .foregroundColor(.white.opacity(disabled ? 0.35 : 0.92))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(disabled ? 0.04 : 0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(disabled ? 0.10 : 0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .overlayButtonHover(enabled: !disabled)
        .disabled(disabled)
    }

    /// MM:SS for the ring's centre digits. Switches to H:MM:SS only when the
    /// remaining window is over an hour (shouldn't happen for prayer-ending, but
    /// guards against weird clock states).
    private var countdownDisplay: String {
        let total = max(0, remainingSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    private func startCountdown() {
        // Lock the ring's "full" reference at first appearance so the trim
        // shrinks smoothly from 1.0 → 0.0 across the visible prayer-ending window.
        if totalDuration == 0.0 {
            totalDuration = Double(max(1, remainingSeconds))
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [prayerEndTime] _ in
            Task { @MainActor in
                elapsedSeconds += 1
                if autoDismissMinutes > 0 && elapsedSeconds >= autoDismissMinutes * 60 {
                    onDismiss()
                    return
                }
                let remaining = Int(max(0, prayerEndTime.timeIntervalSince(Date())))
                remainingSeconds = remaining
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
