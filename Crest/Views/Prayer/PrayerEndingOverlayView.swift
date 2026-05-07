import SwiftUI

struct PrayerEndingOverlayView: View {
    let prayer: Prayer
    let prayerEndTime: Date
    let nextPrayer: Prayer?
    let nextPrayerStartTime: Date?
    let onDismiss: () -> Void

    @State private var remainingSeconds: Int
    @State private var dismissText = ""
    @State private var timer: Timer?
    @State private var shakeOffset: CGFloat = 0
    @FocusState private var isTextFieldFocused: Bool

    init(prayer: Prayer, prayerEndTime: Date,
         nextPrayer: Prayer?, nextPrayerStartTime: Date?,
         onDismiss: @escaping () -> Void) {
        self.prayer = prayer
        self.prayerEndTime = prayerEndTime
        self.nextPrayer = nextPrayer
        self.nextPrayerStartTime = nextPrayerStartTime
        self.onDismiss = onDismiss
        let remaining = Int(max(0, prayerEndTime.timeIntervalSince(Date())))
        _remainingSeconds = State(initialValue: remaining)
    }

    private var countdownText: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private var canDismiss: Bool {
        dismissText.lowercased().trimmingCharacters(in: .whitespaces) == "inshallah"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var urgencyColor: Color {
        Color(red: 0.85, green: 0.25, blue: 0.15)
    }

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
                    .init(color: urgencyColor.opacity(0.3), location: 0.0),
                    .init(color: urgencyColor.opacity(0.18), location: 0.15),
                    .init(color: urgencyColor.opacity(0.08), location: 0.3),
                    .init(color: urgencyColor.opacity(0.03), location: 0.5),
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
                .foregroundStyle(urgencyColor)
                .padding(.bottom, 24)

            Text(remainingSeconds > 0 ? "\(prayer.displayName) Ending Soon" : "\(prayer.displayName) Time Has Ended")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .padding(.bottom, 16)

            Text("\"Verily, the prayer is enjoined on the believers at fixed hours.\" (Surah An-Nisa 4:103)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
                .padding(.bottom, 20)

            if let next = nextPrayer, let startTime = nextPrayerStartTime {
                HStack(spacing: 6) {
                    Image(systemName: next.systemImage)
                        .font(.caption)
                    Text("\(next.displayName) begins at \(Self.timeFormatter.string(from: startTime))")
                        .font(.callout)
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08), in: Capsule())
                .padding(.bottom, 20)
            }

            dismissField
                .padding(.bottom, 32)

            Button(action: onDismiss) {
                Text("Dismiss")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(urgencyColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canDismiss)
            .opacity(canDismiss ? 1 : 0.4)

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

    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [prayerEndTime] _ in
            Task { @MainActor in
                let remaining = Int(max(0, prayerEndTime.timeIntervalSince(Date())))
                remainingSeconds = remaining
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
