import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    @AppStorage(AppSettingsKey.calendarLookaheadDays) private var lookaheadDays = AppSettingsDefault.calendarLookaheadDays
    @AppStorage(AppSettingsKey.showDeclinedEvents) private var showDeclined = AppSettingsDefault.showDeclinedEvents

    @State private var calendars: [EKCalendar] = []
    @State private var enabledIDs: Set<String> = []

    private let store = EKEventStore()

    var body: some View {
        Form {
            Section("Event Window") {
                Stepper(
                    "Show next \(lookaheadDays) days",
                    value: $lookaheadDays,
                    in: 1...30
                )
                Toggle("Show declined events", isOn: $showDeclined)
            }

            Section("Calendars") {
                if calendars.isEmpty {
                    Text("No calendars available. Grant calendar access in System Settings.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(calendars, id: \.calendarIdentifier) { calendar in
                        Toggle(isOn: binding(for: calendar.calendarIdentifier)) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear(perform: loadCalendars)
        .onChange(of: enabledIDs) { _, newValue in
            let array = Array(newValue)
            UserDefaults.standard.set(array, forKey: AppSettingsKey.enabledCalendarIDs)
        }
    }

    private func loadCalendars() {
        calendars = store.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        if let saved = UserDefaults.standard.stringArray(forKey: AppSettingsKey.enabledCalendarIDs) {
            enabledIDs = Set(saved)
        } else {
            enabledIDs = Set(calendars.map(\.calendarIdentifier))
        }
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { enabledIDs.contains(id) },
            set: { enabled in
                if enabled {
                    enabledIDs.insert(id)
                } else {
                    enabledIDs.remove(id)
                }
            }
        )
    }
}
