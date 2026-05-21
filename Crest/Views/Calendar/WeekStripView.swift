import SwiftUI

/// Horizontal week-strip date picker replacing the previous monthly mini calendar.
/// Seven day cells with weekday letter + day number + event dot; chevrons on the
/// header navigate by week. Designed to feel native against the popover's glass
/// material — uses `.primary` / `.secondary` styles so it adapts to material
/// vibrancy automatically.
struct WeekStripView: View {
    var calendarService: CalendarService
    @Binding var selectedDate: Date?
    var hijriDateString: String?

    /// Some date inside the currently-visible week. Driven by the chevrons.
    @State private var anchorDate: Date = Date()

    private let calendar = Calendar.current

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEEE" // S / M / T / W / T / F / S
        return f
    }()

    private static let headerSameMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let headerSpanShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private var weekDays: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: anchorDate) else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: interval.start)
        }
    }

    private var weekRangeString: String {
        let days = weekDays
        guard let first = days.first, let last = days.last else { return "" }
        let firstMonth = calendar.component(.month, from: first)
        let lastMonth = calendar.component(.month, from: last)
        if firstMonth == lastMonth {
            return Self.headerSameMonth.string(from: first)
        } else {
            return "\(Self.headerSpanShort.string(from: first)) – \(Self.headerSpanShort.string(from: last))"
        }
    }

    private var isCurrentWeek: Bool {
        calendar.isDate(anchorDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            if let hijri = hijriDateString, !hijri.isEmpty {
                Text(hijri)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            dayStrip
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(weekRangeString)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .onTapGesture(count: 2) { jumpToToday() }
                .help("Double-click to jump to today")

            Spacer()

            if !isCurrentWeek {
                Button {
                    jumpToToday()
                } label: {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.14))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.accentColor.opacity(0.32), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
            }

            chevronPair
        }
    }

    /// The two chevrons are paired so we wrap them in a `GlassEffectContainer`
    /// on macOS 26+. Per the skill, this gives both glass elements a shared
    /// sampling region — preventing the "glass cannot sample other glass"
    /// inconsistency when they sit on top of the popover's outer glass surface.
    @ViewBuilder
    private var chevronPair: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    chevronButton(systemName: "chevron.left", action: previousWeek, label: "Previous week")
                    chevronButton(systemName: "chevron.right", action: nextWeek, label: "Next week")
                }
            }
        } else {
            HStack(spacing: 4) {
                chevronButton(systemName: "chevron.left", action: previousWeek, label: "Previous week")
                chevronButton(systemName: "chevron.right", action: nextWeek, label: "Next week")
            }
        }
    }

    @ViewBuilder
    private func chevronButton(systemName: String, action: @escaping () -> Void, label: String) -> some View {
        if #available(macOS 26.0, *) {
            // Manually-applied `.glassEffect` instead of `.buttonStyle(.glass)`.
            // The built-in glass button style runs the label through a system
            // vibrancy filter that overrides `.foregroundStyle` and blends the
            // chevron into the material — fine in dark mode (white-on-glass)
            // but near-invisible in light mode (washed pale grey instead of
            // black). Using a plain button + manual glassEffect lets our
            // `.primary` foreground win, giving solid black/white per mode.
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 24)
                    .glassEffect(.regular, in: .capsule)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .help(label)
        } else {
            // Pre-macOS-26 fallback: subtle circular fill control.
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .help(label)
        }
    }

    private var dayStrip: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { day in
                weekDayCell(day)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let sel = selectedDate, calendar.isDate(sel, inSameDayAs: day) {
                            selectedDate = nil
                        } else {
                            selectedDate = day
                        }
                    }
            }
        }
    }

    private func weekDayCell(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let startOfToday = calendar.startOfDay(for: Date())
        let isPast = date < startOfToday && !isToday
        let hasEvents = calendarService.hasEvents(on: date)
        let dayNumber = calendar.component(.day, from: date)

        return VStack(spacing: 5) {
            // Weekday letter — uppercase, kerned. Primary @0.65 stays AAA on
            // material in both modes.
            Text(Self.weekdayFormatter.string(from: date))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isPast ? .secondary : Color.primary.opacity(0.65))
                .tracking(0.6)
                .textCase(.uppercase)

            // Day number with today/selected affordance.
            ZStack {
                if isToday {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 28, height: 28)
                } else if isSelected {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                }
                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isToday ? .bold : .regular))
                    .foregroundStyle(dayNumberForeground(isToday: isToday, isPast: isPast))
                    .monospacedDigit()
            }
            .frame(width: 30, height: 30)

            // Event dot — kept invisible-but-present so the row never reflows.
            Circle()
                .fill(eventDotColor(isToday: isToday, hasEvents: hasEvents))
                .frame(width: 4, height: 4)
        }
        .padding(.vertical, 2)
    }

    private func dayNumberForeground(isToday: Bool, isPast: Bool) -> Color {
        if isToday { return .white }
        if isPast { return Color.primary.opacity(0.55) }
        return .primary
    }

    private func eventDotColor(isToday: Bool, hasEvents: Bool) -> Color {
        guard hasEvents else { return .clear }
        return isToday ? Color.white.opacity(0.85) : .accentColor
    }

    private func jumpToToday() {
        withAnimation(.easeInOut(duration: 0.2)) {
            anchorDate = Date()
            selectedDate = nil
        }
    }

    private func previousWeek() {
        withAnimation(.easeInOut(duration: 0.2)) {
            anchorDate = calendar.date(byAdding: .weekOfYear, value: -1, to: anchorDate) ?? anchorDate
        }
    }

    private func nextWeek() {
        withAnimation(.easeInOut(duration: 0.2)) {
            anchorDate = calendar.date(byAdding: .weekOfYear, value: 1, to: anchorDate) ?? anchorDate
        }
    }
}
