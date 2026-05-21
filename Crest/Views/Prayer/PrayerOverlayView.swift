import SwiftUI
import Adhan

struct PrayerOverlayView: View {
    let prayer: Prayer
    let prayerTime: Date
    let prayerEndTime: Date?
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void

    @State private var remainingSeconds: Int
    @State private var endRemainingSeconds: Int
    @State private var timer: Timer?
    @State private var elapsedSeconds: Int = 0

    init(prayer: Prayer, prayerTime: Date, prayerEndTime: Date?, onDismiss: @escaping () -> Void, onSnooze: @escaping (Int) -> Void) {
        self.prayer = prayer
        self.prayerTime = prayerTime
        self.prayerEndTime = prayerEndTime
        self.onDismiss = onDismiss
        self.onSnooze = onSnooze
        let remaining = Int(max(0, prayerTime.timeIntervalSince(Date())))
        _remainingSeconds = State(initialValue: remaining)
        let endRemaining = Int(max(0, (prayerEndTime ?? Date()).timeIntervalSince(Date())))
        _endRemainingSeconds = State(initialValue: endRemaining)
    }

    private var timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var waqtEndsText: String? {
        guard prayerEndTime != nil, endRemainingSeconds > 0 else { return nil }
        let hours = endRemainingSeconds / 3600
        let minutes = (endRemainingSeconds % 3600) / 60
        let seconds = endRemainingSeconds % 60
        if hours > 0 {
            return String(format: "Waqt ends in %dh %dm %ds", hours, minutes, seconds)
        } else {
            return String(format: "Waqt ends in %dm %ds", minutes, seconds)
        }
    }

    /// Brighter gold than the previous #c4973b. Lifts the title's contrast to ~10.6:1
    /// against the dark canvas and clears 7:1 even at the centre of the radial glow.
    private var themeColor: Color {
        Color(red: 228/255, green: 183/255, blue: 91/255) // #E4B75B
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
        // Manual ("static") mode overrides automatic. Cached coords are Double; static
        // coords are String (the manual entry @AppStorage binds to String).
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
        // up-sized typography. On a 1920×1200 display the glow extends to roughly
        // the screen edges; on a 5K external it reaches further still.
        GeometryReader { geo in
            let diagonal = sqrt(geo.size.width * geo.size.width + geo.size.height * geo.size.height)
            let core = max(120, min(geo.size.width * 0.08, 260))
            let edge = max(1000, min(diagonal * 0.65, 2600))

            ZStack {
                Color(red: 0.04, green: 0.04, blue: 0.06) // #0a0a0c

                // Glow peak kept at 0.08 (so accent-coloured text in the centre
                // still clears WCAG AAA 7:1). Stops pushed further from centre so
                // the warmth reaches toward the corners of the canvas.
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
            // Type scale derived from viewport width. Clamped so 13" MBPs don't
            // get clipped and 27" / external displays go genuinely big.
            let titleSize = max(80, min(geo.size.width * 0.10, 140))
            let timeSize = max(30, min(geo.size.width * 0.025, 44))
            let circleSize = max(140, min(geo.size.width * 0.13, 180))
            let emojiSize = circleSize * 0.46
            let pillTextSize = max(17, min(geo.size.width * 0.013, 22))
            let buttonTextSize = max(20, min(geo.size.width * 0.013, 24))
            let snoozeTextSize = max(15, min(geo.size.width * 0.011, 18))
            let verseSize = max(15, min(geo.size.width * 0.011, 18))

            VStack(spacing: 0) {
                Spacer()

                // Circular Icon — kept, but larger and with a slightly stronger fill
                // so the icon still feels grounded against the dimmer glow.
                Text(prayer.emoji)
                    .font(.system(size: emojiSize))
                    .foregroundColor(prayer == .fajr ? Color(red: 94/255, green: 124/255, blue: 226/255) : themeColor)
                    .frame(width: circleSize, height: circleSize)
                    .background(
                        Circle()
                            .fill(themeColor.opacity(0.12))
                    )
                    .overlay(
                        Circle()
                            .stroke(themeColor.opacity(0.35), lineWidth: 1.5)
                    )
                    .padding(.bottom, 44)

                // Prayer Name — bigger, lighter weight for a more elegant feel.
                Text(prayer.displayName)
                    .font(.system(size: titleSize, weight: .semibold))
                    .foregroundColor(themeColor)
                    .tracking(-1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 18)

                // Start Time — opacity lifted from 0.55 (6.2:1) to 0.92 (~16:1).
                Text(timeFormatter.string(from: prayerTime))
                    .font(.system(size: timeSize, weight: .light))
                    .foregroundStyle(.white.opacity(0.92))
                    .tracking(0.5)
                    .padding(.bottom, 10)

                // Hijri Date — was 14pt @0.35 (3.1:1) → bigger and @0.85 (~14:1).
                Text(hijriDateString)
                    .font(.system(size: pillTextSize - 2, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .tracking(0.4)
                    .padding(.bottom, 32)

                // Waqt countdown pill — accent color still, but pill backdrop bumped
                // for a more "glassy" look and a clearer affordance.
                if let waqtText = waqtEndsText {
                    HStack(spacing: 10) {
                        Text("⏱")
                            .font(.system(size: pillTextSize))
                        Text(waqtText)
                            .font(.system(size: pillTextSize, weight: .semibold))
                    }
                    .foregroundStyle(themeColor)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(themeColor.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .stroke(themeColor.opacity(0.35), lineWidth: 1)
                    )
                    .padding(.bottom, 18)
                }

                // Qibla pill — was 13pt @0.45 (4.6:1) → larger, @0.92 (~16:1).
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
                // push past the waqt's end (no point reminding after the
                // prayer's window has closed). Dismiss is always enabled.
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
                Text(quranVerse)
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

    /// True when snoozing for `minutes` would push past the waqt's end — no
    /// point reminding after the prayer's window has closed. If we don't have
    /// an end time, never disable (degrades gracefully).
    private func snoozeWouldExceedWaqt(minutes: Int) -> Bool {
        guard let end = prayerEndTime else { return false }
        let snoozeUntil = Date().addingTimeInterval(TimeInterval(minutes * 60))
        return snoozeUntil >= end
    }

    /// Snooze/Dismiss pill shared across the three secondary actions. White@0.92
    /// over the dark canvas measures ~16:1 — well clear of AAA.
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

    private var quranVerse: String {
        "\"Indeed, prayer has been decreed upon the believers a decree of specified times.\" (Surah An-Nisa 4:103)"
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [prayerTime, prayerEndTime] _ in
            Task { @MainActor in
                elapsedSeconds += 1
                if autoDismissMinutes > 0 && elapsedSeconds >= autoDismissMinutes * 60 {
                    onDismiss()
                    return
                }
                let remaining = Int(max(0, prayerTime.timeIntervalSince(Date())))
                remainingSeconds = remaining
                if let endTime = prayerEndTime {
                    let endRemaining = Int(max(0, endTime.timeIntervalSince(Date())))
                    endRemainingSeconds = endRemaining
                }
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
