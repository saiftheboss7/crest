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
    @AppStorage(AppSettingsKey.selectedCityName) private var selectedCityName = AppSettingsDefault.selectedCityName

    // Global settings for late reminders
    @AppStorage("lateRemindersEnabled") private var lateRemindersEnabled = true
    @AppStorage("lateReminderOffsetGlobal") private var lateReminderOffsetGlobal = 15
    @AppStorage("lateReminderRespectDNDGlobal") private var lateReminderRespectDNDGlobal = true

    @State private var adjustments: [String: Int] = AppSettingsDefault.defaultPrayerAdjustments
    @State private var notifPerPrayer: [String: Bool] = AppSettingsDefault.defaultPrayerNotificationPerPrayer
    @State private var adhanPerPrayer: [String: Bool] = AppSettingsDefault.defaultPrayerAdhanPerPrayer
    @State private var overlay1PerPrayer: [String: Bool] = AppSettingsDefault.defaultOverlay1PerPrayer
    @State private var overlay2PerPrayer: [String: Bool] = AppSettingsDefault.defaultOverlay2PerPrayer
    @State private var jamaatTimes: [String: String] = AppSettingsDefault.defaultJamaatTimes
    @State private var jamaatOverridePerPrayer: [String: Bool] = [:]

    @State private var searchQuery = ""
    @State private var activePrayerSheet: Prayer? = nil
    @State private var timeAdjustmentsExpanded = false

    @AppStorage("locationUpdateFrequency") private var locationUpdateFrequency = "6h"

    var body: some View {
        Form {
            // Callout / Hero Card inside the Form
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    Text("🌙")
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 212/255, green: 168/255, blue: 77/255), Color(red: 184/255, green: 138/255, blue: 46/255)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                        .shadow(color: Color(red: 184/255, green: 138/255, blue: 46/255).opacity(0.3), radius: 3, x: 0, y: 1.5)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Islamic Mode")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("Full-screen prayer reminders, late-prayer alerts before waqt ends, and Hijri date in your menu bar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $islamicModeEnabled)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: islamicModeEnabled) { _, isOn in
                            if isOn {
                                // Bring late-reminder defaults onto the new "on for
                                // every prayer, 15 min" spec. One-time per install.
                                runLateReminderDefaultsMigrationIfNeeded()
                                if !staticLocationEnabled {
                                    locationService.requestLocation()
                                }
                                // Pick up the freshly-seeded state in the local view
                                // bindings before rescheduling.
                                loadPerPrayerSettings()
                            }
                            prayerTimeService.recompute()
                            notificationService.scheduleAll()
                            onOverlaySettingsChanged?()
                        }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
            )
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)

            if islamicModeEnabled {
                locationSection
                calculationSection
                prayerRemindersSection
                latePrayerReminderSection
                hijriSection
                advancedSection
                jamaatTimesSection
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // Run the late-reminder defaults migration here too — covers users
            // who already have Islamic Mode enabled (so the toggle handler
            // never re-fires) but haven't yet had the new "on for every prayer,
            // 15 min" defaults written. Idempotent via the migration key.
            runLateReminderDefaultsMigrationIfNeeded()
            loadPerPrayerSettings()
        }
        .sheet(item: $activePrayerSheet) { prayer in
            PrayerSettingsSheetView(
                prayer: prayer,
                prayerTimeService: prayerTimeService,
                notificationService: notificationService
            )
            .onDisappear {
                loadPerPrayerSettings()
            }
        }
    }
    
    // MARK: - Sections

    private var locationMissing: Bool {
        prayerTimeService.todayPrayers.isEmpty
    }

    /// Shown inside the Automatic-location card when Wi-Fi is off. Macs have no
    /// GPS — without Wi-Fi the system has nothing to triangulate against, so
    /// "Detecting location…" would just spin forever. Route the user to Manual.
    private var wifiOffBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color(red: 255/255, green: 149/255, blue: 0/255)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Wi-Fi is off — automatic location won't work")
                    .font(.body)
                    .fontWeight(.semibold)
                Text("Macs have no GPS. macOS determines location by scanning Wi-Fi networks. With Wi-Fi off, switch to Manual mode and pick your city — prayer times work identically off a static location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    staticLocationEnabled = true
                    recomputeAndReschedule()
                } label: {
                    Text("Switch to Manual")
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.10), Color.orange.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(10)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var locationSection: some View {
        Section(header: Text("LOCATION").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)) {
            Picker("Location Mode", selection: $staticLocationEnabled) {
                Text("Automatic").tag(false)
                Text("Manual").tag(true)
            }
            .pickerStyle(.segmented)
            .onChange(of: staticLocationEnabled) { _, _ in
                recomputeAndReschedule()
            }

            if !staticLocationEnabled {
                // AUTOMATIC LOCATION CARD
                if locationService.canRequestLiveLocation {
                    // WI-FI OFF BANNER — Macs have no GPS. With Wi-Fi off, CoreLocation
                    // simply cannot determine location. Surface this clearly and route
                    // the user to Manual mode rather than spinning on "Detecting…".
                    if !locationService.isWiFiOn {
                        wifiOffBanner
                    }

                    // Granted state
                    VStack(spacing: 0) {
                        // 1. Status row
                        HStack(spacing: 8) {
                            PulsatingDot()
                            Text("Using current location")
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            if let lat = locationService.latitude, let lon = locationService.longitude {
                                Text(String(format: "%.4f, %.4f%@", lat, lon, locationService.cityName.map { " · \($0)" } ?? ""))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            } else if locationService.isFetching {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Detecting location…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else if let err = locationService.lastError {
                                Text("Failed: \(err)")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                            } else {
                                Text("Idle — tap Refresh")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)

                        Divider()
                            .padding(.horizontal, 14)

                        // 2. Refresh row
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Refresh location")
                                    .font(.body)
                                Text(locationService.lastError ?? "Last checked recently")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button("Refresh") {
                                locationService.requestLocation()
                                recomputeAndReschedule()
                            }
                            .buttonStyle(.bordered)
                            .disabled(locationService.isFetching)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        
                        Divider()
                            .padding(.horizontal, 14)
                        
                        // 3. Update Frequency row
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Update frequency")
                                    .font(.body)
                                Text("How often Crest re-checks your location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Picker("", selection: $locationUpdateFrequency) {
                                Text("Every 6 hours").tag("6h")
                                Text("Every 12 hours").tag("12h")
                                Text("Daily").tag("24h")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 140)
                            .labelsHidden()
                            .onChange(of: locationUpdateFrequency) { _, _ in
                                locationService.setupFrequencyTimer()
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                } else {
                    // Denied/Restricted/Not Determined state
                    VStack(spacing: 0) {
                        // Top banner with gradient background
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    LinearGradient(
                                        colors: [Color.orange, Color(red: 255/255, green: 149/255, blue: 0/255)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(8)
                                .shadow(color: Color.orange.opacity(0.3), radius: 2, x: 0, y: 1)
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(locationService.authorizationStatus == .notDetermined ? "Location permission required" : "Location access required")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                Text(locationService.authorizationStatus == .notDetermined 
                                     ? "Crest needs Location Services to calculate accurate prayer times for your area. Please allow access when prompted, or switch to Manual."
                                     : "Crest needs Location Services to calculate accurate prayer times for your area. Grant access in System Settings, or switch to Manual to enter your city.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.08), Color.orange.opacity(0.03)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        if locationService.authorizationStatus != .notDetermined {
                            Divider()
                            
                            // Steps List
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 10) {
                                    Text("1")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                        .frame(width: 18, height: 18)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Circle())
                                    Text("Click **Open System Settings** below")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                HStack(alignment: .top, spacing: 10) {
                                    Text("2")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                        .frame(width: 18, height: 18)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Circle())
                                    HStack(spacing: 4) {
                                        Text("Go to")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Privacy & Security")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.white.opacity(0.8))
                                            .cornerRadius(4)
                                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0.5)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 8))
                                            .foregroundStyle(.tertiary)
                                        Text("Location Services")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.white.opacity(0.8))
                                            .cornerRadius(4)
                                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0.5)
                                    }
                                }
                                
                                HStack(alignment: .top, spacing: 10) {
                                    Text("3")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                        .frame(width: 18, height: 18)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(Circle())
                                    HStack(spacing: 4) {
                                        Text("Find")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("Crest")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.white.opacity(0.8))
                                            .cornerRadius(4)
                                            .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 0.5)
                                        Text("in the list and turn it on")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(14)
                        }
                        
                        Divider()
                        
                        // Actions Row
                        HStack(spacing: 10) {
                            if locationService.authorizationStatus == .notDetermined {
                                Button(action: {
                                    locationService.requestLocation()
                                }) {
                                    Text("Allow Access")
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: {
                                    locationService.openLocationPrivacySettings()
                                }) {
                                    Text("Open System Settings")
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button(action: {
                                staticLocationEnabled = true
                            }) {
                                Text("Switch to Manual")
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(NSColor.controlColor))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button(action: {
                                locationService.requestLocation()
                            }) {
                                Text("Re-check permission")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                    }
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                }
                
                // Help text for Automatic
                Text("Crest uses macOS Location Services to detect your city. Your location stays on this Mac and is never sent to any server.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 4, trailing: 4))
                    .listRowBackground(Color.clear)
            } else {
                // MANUAL LOCATION CARD
                VStack(spacing: 0) {
                    // Selected location bar
                    if !selectedCityName.isEmpty {
                        HStack(spacing: 8) {
                            Text("📍")
                                .font(.system(size: 13))
                            Text(selectedCityName)
                                .fontWeight(.medium)
                            Spacer()
                            if !staticLatitude.isEmpty && !staticLongitude.isEmpty {
                                Text("\(staticLatitude), \(staticLongitude)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Button(action: {
                                selectedCityName = ""
                                staticLatitude = ""
                                staticLongitude = ""
                                recomputeAndReschedule()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .background(Color.blue.opacity(0.06))
                    }
                    
                    // Search box (Visible if no city selected, OR always visible below to allow updating)
                    if selectedCityName.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search city or postal code", text: $searchQuery)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.leading)
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .popover(isPresented: Binding(
                            get: { !searchQuery.isEmpty },
                            set: { if !$0 { searchQuery = "" } }
                        ), arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 6) {
                                let filtered = CityPreset.database.filter {
                                    $0.name.localizedCaseInsensitiveContains(searchQuery)
                                }
                                if !filtered.isEmpty {
                                    ScrollView {
                                        VStack(alignment: .leading, spacing: 0) {
                                            ForEach(filtered) { preset in
                                                HStack {
                                                    Text(preset.flag)
                                                    Text(preset.name)
                                                        .foregroundStyle(.primary)
                                                    Spacer()
                                                    Text(String(format: "%.4f, %.4f", preset.latitude, preset.longitude))
                                                        .font(.caption.monospacedDigit())
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color(NSColor.controlBackgroundColor).opacity(0.001))
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    selectedCityName = preset.name
                                                    staticLatitude = String(preset.latitude)
                                                    staticLongitude = String(preset.longitude)
                                                    searchQuery = ""
                                                    recomputeAndReschedule()
                                                }
                                                
                                                if preset != filtered.last {
                                                    Divider()
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 200)
                                } else {
                                    Text("No matching cities found.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(10)
                                }
                            }
                            .frame(width: 320)
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                
                // Help text for Manual
                Text("Manual location overrides automatic detection. Useful if you're traveling or don't want to grant Location Services access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowInsets(EdgeInsets(top: 2, leading: 4, bottom: 4, trailing: 4))
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var calculationSection: some View {
        Section(header: Text("CALCULATION").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)) {
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

    private var prayerRemindersSection: some View {
        Section(header: Text("PRAYER REMINDERS").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)) {
            ForEach(Prayer.adjustable) { prayer in
                HStack(spacing: 12) {
                    Button(action: { activePrayerSheet = prayer }) {
                        HStack(spacing: 12) {
                            Text(prayer.emoji)
                                .font(.title3)
                                .foregroundColor(prayer == .fajr ? Color(red: 94/255, green: 124/255, blue: 226/255) : .primary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prayer.displayName)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                
                                let timeRange = getPrayerTimeString(prayer)
                                if !timeRange.isEmpty {
                                    Text(timeRange)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Text(getPrayerTag(prayer))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(10)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Toggle("", isOn: prayerNotifBinding(prayer))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .onTapGesture {
                            activePrayerSheet = prayer
                        }
                }
                .padding(.vertical, 2)
            }
            
            Text("Click any prayer row or its chevron to configure custom sounds, notifications, late reminders, volume, and Focus modes.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var latePrayerReminderSection: some View {
        Section(header: Text("LATE PRAYER REMINDER").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)) {
            HStack {
                Text("⏰")
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remind before waqt ends")
                        .fontWeight(.medium)
                    Text("A final full-screen alert before each prayer window closes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $lateRemindersEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: lateRemindersEnabled) { _, isOn in
                        // Global toggle = mass-set shortcut. Writes the same Bool
                        // to every per-prayer entry. Individual toggles can be
                        // tweaked afterwards and persist until the user flips
                        // the global toggle again.
                        let target: [String: Bool] = [
                            "fajr": isOn, "dhuhr": isOn, "asr": isOn, "maghrib": isOn, "isha": isOn
                        ]
                        UserDefaults.standard.set(target, forKey: AppSettingsKey.overlay2PerPrayer)
                        overlay2PerPrayer = target
                        recomputeAndReschedule()
                        onOverlaySettingsChanged?()
                    }
            }
            
            if lateRemindersEnabled {
                HStack {
                    Text("Reminder time")
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $lateReminderOffsetGlobal) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("1 hour").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 250)
                    .onChange(of: lateReminderOffsetGlobal) { _, _ in
                        recomputeAndReschedule()
                    }
                }
                .padding(.leading, 12)
                
                Toggle("Respect Do Not Disturb", isOn: $lateReminderRespectDNDGlobal)
                    .padding(.leading, 12)
                    .onChange(of: lateReminderRespectDNDGlobal) { _, _ in
                        recomputeAndReschedule()
                    }
            }
        }
    }

    private var hijriSection: some View {
        Section(header: Text("HIJRI DATE").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)) {
            Stepper(
                "Date offset: \(signedDays(hijriDateOffset))",
                value: $hijriDateOffset,
                in: -3...3
            )
            .onChange(of: hijriDateOffset) { _, _ in prayerTimeService.recompute() }

            Toggle("Show Hijri date in menu bar", isOn: $showHijriInMenuBar)
        }
    }

    private var advancedSection: some View {
        Section(header: Text("ADVANCED").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)) {
            DisclosureGroup(
                isExpanded: $timeAdjustmentsExpanded,
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fine-tune calculated prayer times by adding or subtracting minutes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                        
                        ForEach(Prayer.adjustable) { prayer in
                            let binding = Binding<Int>(
                                get: { adjustments[prayer.rawValue] ?? 0 },
                                set: { newValue in
                                    adjustments[prayer.rawValue] = newValue
                                    saveAdjustments()
                                }
                            )
                            HStack {
                                Text(prayer.displayName)
                                Spacer()
                                Stepper(
                                    "\(signedMinutes(adjustments[prayer.rawValue] ?? 0))",
                                    value: binding,
                                    in: -30...30
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                },
                label: {
                    Label("Time adjustments", systemImage: "slider.horizontal.3")
                        .fontWeight(.medium)
                }
            )
        }
    }

    private var jamaatTimesSection: some View {
        Section(header: Text("JAMAAT TIMES").font(.caption2).fontWeight(.semibold).foregroundStyle(.secondary)) {
            HStack {
                Text("🕌")
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Override prayer starting time with Jamaat times")
                        .fontWeight(.medium)
                    Text("When enabled, alerts fire at your masjid's congregation time instead of the calculated prayer start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $jamaatTimesEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: jamaatTimesEnabled) { _, _ in
                        ensureJamaatTimesPersisted()
                        prayerTimeService.recompute()
                        notificationService.scheduleAll()
                    }
            }
            
            if jamaatTimesEnabled {
                ForEach(Prayer.adjustable) { prayer in
                    jamaatTimeRow(prayer)
                }
            }
        }
    }

    private func jamaatTimeRow(_ prayer: Prayer) -> some View {
        let isOverridden = jamaatOverridePerPrayer[prayer.rawValue] ?? false
        
        let timeBinding = Binding<Date>(
            get: { jamaatDate(for: prayer) },
            set: { newValue in
                jamaatTimes[prayer.rawValue] = storedJamaatTime(from: newValue)
                saveJamaatTimes()
            }
        )

        let overrideBinding = Binding<Bool>(
            get: { isOverridden },
            set: { newValue in
                jamaatOverridePerPrayer[prayer.rawValue] = newValue
                UserDefaults.standard.set(jamaatOverridePerPrayer, forKey: "jamaatOverridePerPrayer")
                saveJamaatTimes()
            }
        )

        let originalTime = formatTime(prayerTimeService.timeForPrayer(prayer) ?? Date())
        let jamaatTimeStr = formatTime(jamaatDate(for: prayer))

        return HStack(spacing: 12) {
            Text(prayer.emoji)
                .font(.title3)
                .foregroundColor(prayer == .fajr ? Color(red: 94/255, green: 124/255, blue: 226/255) : .primary)

            VStack(alignment: .leading, spacing: 2) {
                Text(prayer.displayName)
                    .font(.body.weight(.medium))
                
                if isOverridden {
                    HStack(spacing: 4) {
                        Text("Starts \(originalTime)")
                            .strikethrough()
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(jamaatTimeStr)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                } else {
                    Text("Starts \(originalTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            DatePicker(
                "",
                selection: timeBinding,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .disabled(!isOverridden)
            
            Toggle("", isOn: overrideBinding)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func getPrayerSummary(_ prayer: Prayer) -> String {
        let defaults = UserDefaults.standard
        let pKey = prayer.rawValue
        
        let notifPerPrayer = (defaults.dictionary(forKey: AppSettingsKey.prayerNotificationPerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerNotificationPerPrayer
        let alertsEnabled = notifPerPrayer[pKey] ?? true
        
        if !alertsEnabled {
            return "Reminders disabled"
        }
        
        var options: [String] = []
        
        let o1PerPrayer = (defaults.dictionary(forKey: AppSettingsKey.overlay1PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay1PerPrayer
        if o1PerPrayer[pKey] ?? true {
            options.append("Start alert")
        }
        
        let o2PerPrayer = (defaults.dictionary(forKey: AppSettingsKey.overlay2PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay2PerPrayer
        if o2PerPrayer[pKey] ?? true {
            let offsets = (defaults.dictionary(forKey: AppSettingsKey.prayerLateReminderOffset) as? [String: Int])
                ?? AppSettingsDefault.defaultPrayerLateReminderOffset
            let offset = offsets[pKey] ?? 30
            options.append("Late alert (\(offset)m)")
        }
        
        let sounds = (defaults.dictionary(forKey: AppSettingsKey.prayerSoundName) as? [String: String])
            ?? AppSettingsDefault.defaultPrayerSoundName
        let soundName = sounds[pKey] ?? "Soft Chime"
        if soundName != "Silent" {
            options.append(soundName)
        } else {
            options.append("Silent")
        }
        
        return options.isEmpty ? "Visual only" : options.joined(separator: ", ")
    }

    private func getPrayerTimeString(_ prayer: Prayer) -> String {
        let list = prayerTimeService.todayPrayers
        guard !list.isEmpty else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        guard let pTime = list.first(where: { $0.prayer == prayer }) else { return "" }
        let startStr = formatter.string(from: pTime.time)
        
        var endStr = ""
        if prayer == .fajr {
            if let sunrise = list.first(where: { $0.prayer == .sunrise }) {
                endStr = "ends \(formatter.string(from: sunrise.time))"
            }
        } else {
            let adjustable = Prayer.adjustable
            if let currentIndex = adjustable.firstIndex(of: prayer) {
                if currentIndex < adjustable.count - 1 {
                    let nextPrayerType = adjustable[currentIndex + 1]
                    if let nextTime = list.first(where: { $0.prayer == nextPrayerType }) {
                        endStr = "ends \(formatter.string(from: nextTime.time))"
                    }
                } else {
                    if let firstFajr = list.first(where: { $0.prayer == .fajr }) {
                        let tomorrowFajr = firstFajr.time.addingTimeInterval(24 * 3600)
                        endStr = "ends \(formatter.string(from: tomorrowFajr))"
                    }
                }
            }
        }
        
        if endStr.isEmpty {
            return startStr
        } else {
            return "\(startStr) • \(endStr)"
        }
    }

    private func getPrayerTag(_ prayer: Prayer) -> String {
        let pKey = prayer.rawValue
        let hasStart = overlay1PerPrayer[pKey] ?? true
        let hasLate = overlay2PerPrayer[pKey] ?? true
        
        let alertsEnabled = notifPerPrayer[pKey] ?? true
        if !alertsEnabled {
            return "Disabled"
        }
        
        if hasStart && hasLate {
            return "Start & late"
        } else if hasStart {
            return "Start only"
        } else if hasLate {
            return "Late only"
        } else {
            return "Visual only"
        }
    }

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

    /// One-time migration that brings every install onto the new late-reminder
    /// defaults: every prayer's late reminder ON, 15-minute offset, respecting
    /// DND. Older builds shipped `defaultOverlay2PerPrayer` as all-false and
    /// `defaultPrayerLateReminderOffset` as 30 min, so users who already had
    /// Islamic Mode enabled were left on the stale state even after we updated
    /// the static defaults. Gated on a migration key so it runs at most once
    /// per install and never overwrites later user tweaks.
    private func runLateReminderDefaultsMigrationIfNeeded() {
        let defaults = UserDefaults.standard
        let migrationKey = "lateReminderDefaultsMigration_v2"
        guard !defaults.bool(forKey: migrationKey) else { return }

        defaults.set(true, forKey: "lateRemindersEnabled")
        defaults.set(15, forKey: "lateReminderOffsetGlobal")
        defaults.set(true, forKey: "lateReminderRespectDNDGlobal")
        defaults.set(AppSettingsDefault.defaultOverlay2PerPrayer,
                     forKey: AppSettingsKey.overlay2PerPrayer)
        defaults.set(AppSettingsDefault.defaultPrayerLateReminderOffset,
                     forKey: AppSettingsKey.prayerLateReminderOffset)
        defaults.set(true, forKey: migrationKey)
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

        jamaatOverridePerPrayer = (defaults.dictionary(forKey: "jamaatOverridePerPrayer") as? [String: Bool])
            ?? ["fajr": false, "dhuhr": false, "asr": false, "maghrib": false, "isha": false]

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

struct PulsatingDot: View {
    @State private var pulse = false
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
            .scaleEffect(pulse ? 1.4 : 1.0)
            .opacity(pulse ? 0.4 : 1.0)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .repeatForever(autoreverses: true)
                ) {
                    pulse = true
                }
            }
    }
}
