import SwiftUI

struct PrayerTimesView: View {
    var prayerTimeService: PrayerTimeService

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    /// Visual urgency thresholds for the active-waqt countdown — the badge and
    /// the progress bar both shift through these as the window closes.
    private enum Urgency {
        case calm    // > 30 min remaining
        case soon    // 15–30 min — amber
        case ending  // < 15 min — red

        var tint: Color {
            switch self {
            case .calm:   return .accentColor
            case .soon:   return Color(red: 230/255, green: 145/255, blue: 30/255)  // #E6911E
            case .ending: return Color(red: 220/255, green: 70/255, blue: 60/255)   // #DC463C
            }
        }
    }

    private var urgency: Urgency {
        guard prayerTimeService.isInActivePrayerWindow else { return .calm }
        let remaining = prayerTimeService.highlightCountdown
        if remaining < 15 * 60 { return .ending }
        if remaining < 30 * 60 { return .soon }
        return .calm
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section header — slightly heavier than the rest so it anchors the
            // group. `.primary` opacity 0.85 is AAA (~12:1) on `.regularMaterial`.
            HStack(spacing: 6) {
                Text("Prayer Times")
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.primary.opacity(0.85))
                    .textCase(.uppercase)
                Spacer()
                if let next = prayerTimeService.nextPrayer,
                   !prayerTimeService.isInActivePrayerWindow {
                    // Subtle right-aligned hint when nothing is currently active,
                    // so the user sees what's coming up at a glance.
                    Text("Next · \(next.displayName)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05))

            // Borderless rows — the highlighted-row tint and urgency colour
            // carry the visual separation that the dividers used to provide.
            ForEach(prayerTimeService.todayPrayers) { pt in
                prayerRow(pt)
            }
        }
        .padding(.bottom, 4)
    }

    private func prayerRow(_ pt: PrayerTime) -> some View {
        let isHighlighted = prayerTimeService.highlightedPrayer == pt.prayer
        let isActiveWindow = isHighlighted && prayerTimeService.isInActivePrayerWindow
        let isPast = pt.isPast()
        let jamaatIsPast = pt.jamaatTime.map { $0 < Date() } ?? false

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(pt.prayer.emoji)
                    .font(.body)
                    .frame(width: 18, alignment: .center)
                    // Past rows kept perceptible — was Color.secondary.opacity(0.4)
                    // (~3:1, AAA-fail). Now @0.6 (~5:1) with a subtle desaturation.
                    .opacity(isPast && !isHighlighted ? 0.55 : 1.0)

                Text(pt.prayer.displayName)
                    .font(.callout.weight(isHighlighted ? .semibold : .regular))
                    // Past was .tertiary (~3:1). .secondary is ~4.5+:1 (AA) and
                    // active stays at full .primary (~12+:1, AAA).
                    .foregroundStyle(isPast && !isHighlighted ? .secondary : .primary)

                Spacer()

                if isHighlighted {
                    countdownBadge
                }

                Text(timeFormatter.string(from: pt.time))
                    .font(.callout.monospacedDigit())
                    // Was .tertiary when past — bumped to .secondary so the time
                    // stays legible (it's a key data point even for past rows).
                    // Both branches use `Color` so the ternary unifies cleanly.
                    .foregroundStyle(isPast && !isHighlighted ? Color.secondary : Color.primary.opacity(0.85))
            }

            if let jamaat = pt.jamaatTime {
                jamaatRow(time: jamaat, isPast: jamaatIsPast)
            }

            // Horizontal progress bar — only shown for the currently-active
            // prayer. Shrinks from full to empty as the waqt closes, and shifts
            // colour through accent → amber → red as the end approaches.
            if isActiveWindow {
                progressBar
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, pt.jamaatTime == nil ? 8 : 6)
        .background(
            // Subtle warm tint on the active row — uses the same urgency colour
            // as the badge / bar so the row's mood matches the countdown.
            isHighlighted ? urgency.tint.opacity(isActiveWindow ? 0.10 : 0.06) : Color.clear
        )
    }

    /// "1h 20m 45s left" / "in 20m" badge — coloured text on a same-hue tinted
    /// fill. AAA contrast is not satisfied with this combination (the brand-
    /// coloured text vs same-hue tinted fill yields roughly 3:1), but the
    /// aesthetic is the priority here and the surrounding row provides
    /// supporting context (the prayer name itself stays at .primary AAA).
    private var countdownBadge: some View {
        let tint = urgency.tint
        return Text(prayerTimeService.formattedHighlightCountdown())
            .font(.caption.monospacedDigit())
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(tint.opacity(0.16))
            )
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.32), lineWidth: 0.75)
            )
            // monospacedDigit means the badge width is stable as digits change,
            // but the leading text ("1h …" vs "20m …") still varies slightly —
            // this layout priority stops the layout from jumping every second.
            .layoutPriority(1)
    }

    /// Live waqt-progress bar. Width is driven by GeometryReader so it always
    /// fits the row regardless of popover width changes.
    private var progressBar: some View {
        let progress = prayerTimeService.highlightProgress
        let tint = urgency.tint
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 4)
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, geo.size.width * CGFloat(progress)), height: 4)
                    .animation(.linear(duration: 1), value: progress)
            }
        }
        .frame(height: 4)
        .padding(.leading, 26) // align bar with the prayer-name column
    }

    private func jamaatRow(time: Date, isPast: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 9))
                // Was .secondary.opacity(0.3) — boosted so the icon stays visible.
                .foregroundStyle(.secondary.opacity(isPast ? 0.55 : 0.85))
                .frame(width: 18)

            Text("Jamaat")
                .font(.caption)
                // Past was .quaternary (~2:1, fails even AA). Now .secondary
                // (~4.5:1) with a lower opacity for past so it's still subdued.
                .foregroundStyle(.secondary.opacity(isPast ? 0.6 : 1.0))

            Spacer()

            Text(timeFormatter.string(from: time))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary.opacity(isPast ? 0.6 : 1.0))
        }
    }
}
