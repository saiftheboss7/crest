@preconcurrency import EventKit
import Observation
import AppKit

@MainActor @Observable
final class CalendarService {
    private(set) var events: [EKEvent] = []
    private(set) var calendars: [EKCalendar] = []
    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined
    private(set) var isLoading = false

    private let store = EKEventStore()

    var nextEvent: EKEvent? {
        let now = Date()
        return events.first { $0.endDate > now && !$0.isAllDay }
    }

    var enabledCalendarIDs: Set<String> {
        if let saved = UserDefaults.standard.stringArray(forKey: AppSettingsKey.enabledCalendarIDs) {
            return Set(saved)
        }
        return Set(calendars.map(\.calendarIdentifier))
    }

    var lookaheadDays: Int {
        UserDefaults.standard.object(forKey: AppSettingsKey.calendarLookaheadDays) as? Int
            ?? AppSettingsDefault.calendarLookaheadDays
    }

    var showDeclinedEvents: Bool {
        UserDefaults.standard.bool(forKey: AppSettingsKey.showDeclinedEvents)
    }

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        setupNotifications()
        if authorizationStatus == .fullAccess || authorizationStatus == .authorized {
            refresh()
        }
    }

    func requestAccess() {
        Task {
            if #available(macOS 14.0, *) {
                let granted = (try? await store.requestFullAccessToEvents()) ?? false
                self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted { self.refresh() }
            } else {
                let granted = (try? await store.requestAccess(to: .event)) ?? false
                self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                if granted { self.refresh() }
            }
        }
    }

    func refresh() {
        isLoading = true
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: lookaheadDays, to: start) else {
            isLoading = false
            return
        }

        calendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        let enabledCals = calendars.filter { enabledCalendarIDs.contains($0.calendarIdentifier) }
        guard !enabledCals.isEmpty else {
            events = []
            isLoading = false
            return
        }

        let predicate = store.predicateForEvents(
            withStart: start,
            end: end,
            calendars: enabledCals
        )

        var fetched = store.events(matching: predicate)

        if !showDeclinedEvents {
            fetched = fetched.filter { event in
                guard let attendees = event.attendees else { return true }
                let selfAttendee = attendees.first { $0.isCurrentUser }
                return selfAttendee?.participantStatus != .declined
            }
        }

        fetched.sort { $0.startDate < $1.startDate }
        events = fetched
        isLoading = false
    }

    func eventsForDate(_ date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            if event.isAllDay {
                return calendar.isDate(event.startDate, inSameDayAs: date)
            }
            let dayStart = calendar.startOfDay(for: date)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
            return event.startDate < dayEnd && event.endDate > dayStart
        }
    }

    func hasEvents(on date: Date) -> Bool {
        !eventsForDate(date).isEmpty
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: store,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }
}
