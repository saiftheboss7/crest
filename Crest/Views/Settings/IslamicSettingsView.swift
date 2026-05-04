import SwiftUI

struct IslamicSettingsView: View {
    var locationService: LocationService
    var prayerTimeService: PrayerTimeService
    var notificationService: PrayerNotificationService
    var onOverlaySettingsChanged: (() -> Void)?

    @AppStorage(AppSettingsKey.islamicModeEnabled) private var islamicModeEnabled = AppSettingsDefault.islamicModeEnabled
    @AppStorage(AppSettingsKey.calculationMethod) private var calculationMethod = AppSettingsDefault.calculationMethod
    @AppStorage(AppSettingsKey.madhab) private var madhab = AppSettingsDefault.madhab
    @AppStorage(AppSettingsKey.shafaq) private var shafaq = AppSettingsDefault.shafaq
    @AppStorage(AppSettingsKey.hijriDateOffset) private var hijriDateOffset = AppSettingsDefault.hijriDateOffset
    @AppStorage(AppSettingsKey.showHijriInMenuBar) private var showHijriInMenuBar = AppSettingsDefault.showHijriInMenuBar
    @AppStorage(AppSettingsKey.prayerNotificationsEnabled) private var notificationsEnabled = AppSettingsDefault.prayerNotificationsEnabled
    @AppStorage(AppSettingsKey.overlayRespectDND) private var respectDND = AppSettingsDefault.overlayRespectDND
    @AppStorage(AppSettingsKey.jamaatTimesEnabled) private var jamaatTimesEnabled = AppSettingsDefault.jamaatTimesEnabled
    @AppStorage(AppSettingsKey.staticLocationEnabled) private var staticLocationEnabled = AppSettingsDefault.staticLocationEnabled
    @AppStorage(AppSettingsKey.staticLatitude) private var staticLatitude = AppSettingsDefault.staticLatitude
    @AppStorage(AppSettingsKey.staticLongitude) private var staticLongitude = AppSettingsDefault.staticLongitude
    @AppStorage(AppSettingsKey.prayerOverlaySoundEnabled) private var prayerOverlaySoundEnabled = AppSettingsDefault.prayerOverlaySoundEnabled

    @State private var adjustments: [String: Int] = AppSettingsDefault.defaultPrayerAdjustments
    @State private var notifPerPrayer: [String: Bool] = AppSettingsDefault.defaultPrayerNotificationPerPrayer
    @State private var adhanPerPrayer: [String: Bool] = AppSettingsDefault.defaultPrayerAdhanPerPrayer
    @State private var overlay1PerPrayer: [String: Bool] = AppSettingsDefault.defaultOverlay1PerPrayer
    @State private var overlay2PerPrayer: [String: Bool] = AppSettingsDefault.defaultOverlay2PerPrayer
    @State private var jamaatTimes: [String: String] = AppSettingsDefault.defaultJamaatTimes

    var body: some View {
        Form {
            Section {
                Toggle("Enable Islamic Mode", isOn: $islamicModeEnabled)
                    .onChange(of: islamicModeEnabled) { _, _ in
                        prayerTimeService.recompute()
                        notificationService.scheduleAll()
                    }
            }

            if islamicModeEnabled {
                locationSection
                calculationSection
                adjustmentsSection
                jamaatSection
                hijriSection
                notificationsSection
                overlaySection
            }
        }
        .formStyle(.grouped)
        .onAppear { loadPerPrayerSettings() }
    }

    // MARK: - Location

    private var locationMissing: Bool {
        prayerTimeService.todayPrayers.isEmpty
    }

    private var locationSection: some View {
        Section {
            if locationMissing {
                Label("Prayer times need a location", systemImage: "location.slash.fill")
                    .foregroundStyle(.orange)
            }

            Toggle("Use static location", isOn: $staticLocationEnabled)
                .onChange(of: staticLocationEnabled) { _, _ in
                    recomputeAndReschedule()
                }

            if staticLocationEnabled {
                HStack {
                    Text("Latitude")
                    Spacer()
                    TextField("e.g. 40.7128", text: $staticLatitude)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .onChange(of: staticLatitude) { _, newValue in
                            staticLatitude = cleanedCoordinateInput(newValue)
                            recomputeAndReschedule()
                        }
                }

                HStack {
                    Text("Longitude")
                    Spacer()
                    TextField("e.g. -74.0060", text: $staticLongitude)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 160)
                        .onChange(of: staticLongitude) { _, newValue in
                            staticLongitude = cleanedCoordinateInput(newValue)
                            recomputeAndReschedule()
                        }
                }

                if !isValidStaticCoordinates {
                    Text("Enter a valid latitude (-90 to 90) and longitude (-180 to 180).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !staticLocationEnabled,
               let lat = locationService.latitude,
               let lon = locationService.longitude {
                HStack {
                    Text("Coordinates")
                    Spacer()
                    Text(String(format: "%.4f, %.4f", lat, lon))
                        .foregroundStyle(.secondary)
                        .font(.callout.monospacedDigit())
                }
            }

            if !staticLocationEnabled, locationService.needsSettingsAction {
                VStack(alignment: .leading, spacing: 8) {
                    Text(locationService.permissionHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button("Open System Settings") {
                            locationService.openLocationPrivacySettings()
                        }

                        Button("Try Again") {
                            locationService.requestLocation()
                        }
                    }
                }
            }

            if !staticLocationEnabled,
               !locationService.needsSettingsAction,
               locationService.coordinates == nil,
               !locationService.permissionHelpText.isEmpty {
                Text(locationService.permissionHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Refresh Location") {
                locationService.requestLocation()
            }
            .disabled(staticLocationEnabled)
        } header: {
            HStack(spacing: 4) {
                Text("Location")
                if locationMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }
            }
        }
    }

    // MARK: - Calculation

    private var calculationSection: some View {
        Section("Calculation") {
            Picker("Method", selection: $calculationMethod) {
                ForEach(CalculationMethodOption.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .onChange(of: calculationMethod) { _, _ in recomputeAndReschedule() }

            Picker("Madhab (Asr)", selection: $madhab) {
                ForEach(MadhabOption.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .onChange(of: madhab) { _, _ in recomputeAndReschedule() }

            Picker("Shafaq (Isha)", selection: $shafaq) {
                ForEach(ShafaqOption.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .onChange(of: shafaq) { _, _ in recomputeAndReschedule() }
        }
    }

    // MARK: - Time Adjustments

    private var adjustmentsSection: some View {
        Section("Time Adjustments") {
            ForEach(Prayer.adjustable) { prayer in
                let binding = Binding<Int>(
                    get: { adjustments[prayer.rawValue] ?? 0 },
                    set: { newValue in
                        adjustments[prayer.rawValue] = newValue
                        saveAdjustments()
                    }
                )
                Stepper(
                    "\(prayer.displayName): \(signedMinutes(adjustments[prayer.rawValue] ?? 0))",
                    value: binding,
                    in: -30...30
                )
            }
        }
    }

    // MARK: - Jamaat Times

    private var jamaatSection: some View {
        Group {
            Section {
                Toggle("Enable Jamaat Times", isOn: $jamaatTimesEnabled)
                    .onChange(of: jamaatTimesEnabled) { _, _ in
                        ensureJamaatTimesPersisted()
                        prayerTimeService.recompute()
                        notificationService.scheduleAll()
                    }

                if jamaatTimesEnabled {
                    ForEach(Prayer.adjustable) { prayer in
                        jamaatTimeRow(prayer)
                    }
                }
            } header: {
                Text("Jamaat Times")
            } footer: {
                Text("Set jamaat times for your mosque. Enable Alert to receive a fullscreen reminder when each jamaat begins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        }
    }

    private func jamaatTimeRow(_ prayer: Prayer) -> some View {
        let timeBinding = Binding<Date>(
            get: { jamaatDate(for: prayer) },
            set: { newValue in
                jamaatTimes[prayer.rawValue] = storedJamaatTime(from: newValue)
                saveJamaatTimes()
            }
        )

        let alertBinding = Binding<Bool>(
            get: { overlay1PerPrayer[prayer.rawValue] ?? false },
            set: { newValue in
                overlay1PerPrayer[prayer.rawValue] = newValue
                UserDefaults.standard.set(overlay1PerPrayer, forKey: AppSettingsKey.overlay1PerPrayer)
                onOverlaySettingsChanged?()
            }
        )

        return HStack {
            Image(systemName: prayer.systemImage)
                .frame(width: 20)
                .foregroundStyle(prayer.themeColor)
            Text(prayer.displayName)
            Spacer()
            DatePicker(
                "",
                selection: timeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            Toggle("", isOn: alertBinding)
                .toggleStyle(.checkbox)
                .labelsHidden()
            Text("Alert")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Hijri Date

    private var hijriSection: some View {
        Section("Hijri Date") {
            Stepper(
                "Date offset: \(signedDays(hijriDateOffset))",
                value: $hijriDateOffset,
                in: -3...3
            )
            .onChange(of: hijriDateOffset) { _, _ in prayerTimeService.recompute() }

            Toggle("Show Hijri date in menu bar", isOn: $showHijriInMenuBar)
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Prayer notifications", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, newValue in
                    if newValue && !notificationService.isAuthorized {
                        notificationService.requestAuthorization()
                    }
                    notificationService.scheduleAll()
                }

            if notificationsEnabled {
                ForEach(Prayer.adjustable) { prayer in
                    HStack {
                        Toggle(prayer.displayName, isOn: prayerNotifBinding(prayer))

                        Spacer()

                        if Bundle.main.url(forResource: "adhan", withExtension: "caf") != nil {
                            Toggle("Adhan", isOn: adhanBinding(prayer))
                                .toggleStyle(.switch)
                                .labelsHidden()
                            Text("Adhan")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Overlay

    private var overlaySection: some View {
        Section("End-of-Prayer Reminders") {
            Toggle("Respect Do Not Disturb", isOn: $respectDND)
            Toggle("Play sound on start reminder", isOn: $prayerOverlaySoundEnabled)

            ForEach(Prayer.adjustable) { prayer in
                HStack {
                    Image(systemName: prayer.systemImage)
                        .frame(width: 20)
                        .foregroundStyle(prayer.themeColor)
                    Text(prayer.displayName)
                    Spacer()
                    Toggle("", isOn: overlay2Binding(prayer))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
            }

            Text("Receive a reminder before each prayer window ends.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func signedMinutes(_ value: Int) -> String {
        value == 0 ? "0 min" : (value > 0 ? "+\(value) min" : "\(value) min")
    }

    private func signedDays(_ value: Int) -> String {
        value == 0 ? "0 days" : (value > 0 ? "+\(value) day\(value == 1 ? "" : "s")" : "\(value) day\(abs(value) == 1 ? "" : "s")")
    }

    private func recomputeAndReschedule() {
        prayerTimeService.recompute()
        notificationService.scheduleAll()
    }

    // MARK: - Per-prayer bindings

    private func prayerNotifBinding(_ prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { notifPerPrayer[prayer.rawValue] ?? true },
            set: { newValue in
                notifPerPrayer[prayer.rawValue] = newValue
                UserDefaults.standard.set(notifPerPrayer, forKey: AppSettingsKey.prayerNotificationPerPrayer)
                notificationService.scheduleAll()
            }
        )
    }

    private func adhanBinding(_ prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { adhanPerPrayer[prayer.rawValue] ?? false },
            set: { newValue in
                adhanPerPrayer[prayer.rawValue] = newValue
                UserDefaults.standard.set(adhanPerPrayer, forKey: AppSettingsKey.prayerAdhanPerPrayer)
                notificationService.scheduleAll()
            }
        )
    }

    private func overlay1Binding(_ prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { overlay1PerPrayer[prayer.rawValue] ?? true },
            set: { newValue in
                overlay1PerPrayer[prayer.rawValue] = newValue
                UserDefaults.standard.set(overlay1PerPrayer, forKey: AppSettingsKey.overlay1PerPrayer)
            }
        )
    }

    private func overlay2Binding(_ prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { overlay2PerPrayer[prayer.rawValue] ?? true },
            set: { newValue in
                overlay2PerPrayer[prayer.rawValue] = newValue
                UserDefaults.standard.set(overlay2PerPrayer, forKey: AppSettingsKey.overlay2PerPrayer)
            }
        )
    }

    private func saveJamaatTimes() {
        UserDefaults.standard.set(jamaatTimes, forKey: AppSettingsKey.jamaatTimes)
        prayerTimeService.recompute()
        notificationService.scheduleAll()
        onOverlaySettingsChanged?()
    }

    private func ensureJamaatTimesPersisted() {
        let defaults = UserDefaults.standard
        guard defaults.dictionary(forKey: AppSettingsKey.jamaatTimes) as? [String: String] == nil else { return }
        defaults.set(jamaatTimes, forKey: AppSettingsKey.jamaatTimes)
    }

    // MARK: - Persistence

    private func loadPerPrayerSettings() {
        let defaults = UserDefaults.standard

        let isFirstRun = defaults.dictionary(forKey: AppSettingsKey.overlay1PerPrayer) == nil

        adjustments = (defaults.dictionary(forKey: AppSettingsKey.prayerAdjustments) as? [String: Int])
            ?? AppSettingsDefault.defaultPrayerAdjustments
        notifPerPrayer = (defaults.dictionary(forKey: AppSettingsKey.prayerNotificationPerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerNotificationPerPrayer
        adhanPerPrayer = (defaults.dictionary(forKey: AppSettingsKey.prayerAdhanPerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerAdhanPerPrayer
        overlay1PerPrayer = (defaults.dictionary(forKey: AppSettingsKey.overlay1PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay1PerPrayer
        overlay2PerPrayer = (defaults.dictionary(forKey: AppSettingsKey.overlay2PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay2PerPrayer
        jamaatTimes = loadStoredJamaatTimes(defaults: defaults)

        if isFirstRun && jamaatTimesEnabled {
            overlay1PerPrayer = ["fajr": true, "dhuhr": true, "asr": true, "maghrib": true, "isha": true]
            defaults.set(overlay1PerPrayer, forKey: AppSettingsKey.overlay1PerPrayer)
        }
    }

    private func loadStoredJamaatTimes(defaults: UserDefaults) -> [String: String] {
        if let storedTimes = defaults.dictionary(forKey: AppSettingsKey.jamaatTimes) as? [String: String] {
            return storedTimes
        }

        defaults.set(AppSettingsDefault.defaultJamaatTimes, forKey: AppSettingsKey.jamaatTimes)
        return AppSettingsDefault.defaultJamaatTimes
    }

    private func jamaatDate(for prayer: Prayer) -> Date {
        let stored = jamaatTimes[prayer.rawValue] ?? AppSettingsDefault.defaultJamaatTimes[prayer.rawValue]
        return jamaatDate(from: stored) ?? defaultJamaatDate()
    }

    private func jamaatDate(from storedValue: String?) -> Date? {
        guard let storedValue else { return nil }

        let parts = storedValue.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0 ... 23).contains(hour),
              (0 ... 59).contains(minute)
        else {
            return nil
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: today)
    }

    private func storedJamaatTime(from date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%02d:%02d", hour, minute)
    }

    private func defaultJamaatDate() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func saveAdjustments() {
        UserDefaults.standard.set(adjustments, forKey: AppSettingsKey.prayerAdjustments)
        recomputeAndReschedule()
    }

    private var isValidStaticCoordinates: Bool {
        guard let lat = Double(staticLatitude), let lon = Double(staticLongitude) else { return false }
        return (-90.0 ... 90.0).contains(lat) && (-180.0 ... 180.0).contains(lon)
    }

    private func cleanedCoordinateInput(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

}
