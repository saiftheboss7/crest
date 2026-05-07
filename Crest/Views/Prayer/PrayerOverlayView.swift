import SwiftUI

struct PrayerOverlayView: View {
    let prayer: Prayer
    let prayerTime: Date
    let prayerEndTime: Date?
    let onDismiss: () -> Void
    let onSnooze: (Int) -> Void

    @State private var remainingSeconds: Int
    @State private var endRemainingSeconds: Int
    @State private var dismissText = ""
    @State private var timer: Timer?
    @State private var selectedSnoozeDuration: Int = 5
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool

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

    private var countdownText: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var waqtEndsText: String? {
        guard prayerEndTime != nil, endRemainingSeconds > 0 else { return nil }
        let hours = endRemainingSeconds / 3600
        let minutes = (endRemainingSeconds % 3600) / 60
        if hours > 0 {
            return "Waqt ends in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "Waqt ends in \(minutes)m"
        } else {
            return "Waqt ends in < 1m"
        }
    }

    private var canDismiss: Bool {
        dismissText.lowercased().trimmingCharacters(in: .whitespaces) == "inshallah"
    }

    private var themeColor: Color { prayer.themeColor }

    var body: some View {
        ZStack {
            overlayBackground
            countdownBadge
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startCountdown()
            isTextFieldFocused = true
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

            Image(systemName: prayer.systemImage)
                .font(.system(size: 48))
                .foregroundStyle(themeColor)
                .padding(.bottom, 24)

            Text("It's time for \(prayer.displayName)")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 12)

            if let waqtText = waqtEndsText {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(waqtText)
                        .font(.callout.weight(.medium))
                }
                .foregroundStyle(themeColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(themeColor.opacity(0.15), in: Capsule())
                .padding(.bottom, 16)
            }

            Text(quranVerse)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .padding(.bottom, 32)

            dismissField
                .padding(.bottom, 32)

            actionButtons

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dismissField: some View {
        DismissPromptField(
            text: $dismissText,
            onSubmit: handleSubmit,
            isFocused: $isTextFieldFocused
        )
        .offset(x: shakeOffset)
        .animation(.default, value: shakeOffset)
    }

    private func handleSubmit() {
        if canDismiss {
            onDismiss()
        } else {
            triggerShake()
        }
    }

    private func triggerShake() {
        shakeOffset = 10
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { shakeOffset = -8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { shakeOffset = 6 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { shakeOffset = -4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shakeOffset = 0 }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button(action: { onSnooze(selectedSnoozeDuration) }) {
                    Label("Snooze (\(selectedSnoozeDuration)m)", systemImage: "moon.zzz")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(themeColor, in: Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onDismiss) {
                    Label("Skip", systemImage: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.1), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(!canDismiss)
                .opacity(canDismiss ? 1 : 0.4)
            }

            HStack(spacing: 8) {
                ForEach([5, 10, 15, 30], id: \.self) { duration in
                    Button {
                        selectedSnoozeDuration = duration
                    } label: {
                        Text("\(duration)m")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(selectedSnoozeDuration == duration ? .white : .white.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedSnoozeDuration == duration ? themeColor.opacity(0.6) : .white.opacity(0.08),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var quranVerse: String {
        "\"Indeed, prayer has been decreed upon the believers a decree of specified times.\" (Surah An-Nisa 4:103)"
    }

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [prayerTime, prayerEndTime] _ in
            Task { @MainActor in
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
