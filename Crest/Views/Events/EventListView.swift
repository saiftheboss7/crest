import SwiftUI
import EventKit

struct EventListView: View {
    var calendarService: CalendarService
    var selectedDate: Date?

    var body: some View {
        Group {
            switch calendarService.authorizationStatus {
            case .notDetermined:
                accessPrompt
            case .denied, .restricted:
                deniedView
            default:
                eventsList
            }
        }
        .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 320)
    }

    private var accessPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Calendar Access Required")
                .font(.headline)
            Text("Crest needs access to your calendars to show upcoming events.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Grant Access") {
                calendarService.requestAccess()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("Calendar Access Denied")
                .font(.headline)
            Text("Enable calendar access in System Settings > Privacy & Security > Calendars.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }

    private var eventsList: some View {
        let grouped = groupedEvents
        return ScrollView {
            if grouped.isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 24)
                    Image(systemName: "calendar")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text(selectedDate != nil ? "No events on this day" : "No upcoming events")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(grouped, id: \.date) { group in
                        Section {
                            ForEach(group.events, id: \.eventIdentifier) { event in
                                EventRowView(event: event)
                                if event.eventIdentifier != group.events.last?.eventIdentifier {
                                    Divider()
                                        .padding(.leading, 28)
                                }
                            }
                        } header: {
                            Text(DateFormatting.relativeDayHeader(for: group.date))
                                .font(.caption.weight(.semibold))
                                .tracking(0.5)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.04))
                        }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var groupedEvents: [EventGroup] {
        let calendar = Calendar.current
        let filteredEvents: [EKEvent]

        if let selected = selectedDate {
            filteredEvents = calendarService.eventsForDate(selected)
        } else {
            filteredEvents = calendarService.events
        }

        let dict = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }

        return dict.map { EventGroup(date: $0.key, events: $0.value) }
            .sorted { $0.date < $1.date }
    }
}

private struct EventGroup {
    let date: Date
    let events: [EKEvent]
}
