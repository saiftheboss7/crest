import SwiftUI

struct PrayerSettingsSheetView: View {
    let prayer: Prayer
    var prayerTimeService: PrayerTimeService
    var notificationService: PrayerNotificationService
    @Environment(\.dismiss) private var dismiss

    // Per-prayer alert settings loaded into state
    @State private var alertsEnabled = true
    @State private var startAlertEnabled = true
    @State private var lateAlertEnabled = true
    @State private var lateOffset = 30
    @State private var selectedSoundName = "Soft Chime"
    @State private var soundVolume = 0.7
    @State private var fullscreenEnabled = true
    @State private var showOnAllSpaces = true
    @State private var autoDismissMinutes = 0
    @State private var overrideDND = true
    @State private var lateReminderOverridden = false
    @State private var prayerOverrideDNDOverridden = false
    @State private var showDuringMeetings = false
    @State private var showDuringScreenSharing = false
    @State private var customMessage = ""
    @State private var snoozeMinutes: Set<Int> = [5, 10, 15]

    // Playing state for previews
    @State private var playingSound: String? = nil

    private let soundOptions = [
        "Adhan — Makkah",
        "Adhan — Madinah",
        "Adhan — Egypt",
        "Soft Chime",
        "Tasbih Bell",
        "Silent"
    ]

    private let snoozePresets = [5, 10, 15, 20, 30, 60]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: prayer.systemImage)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(prayer.themeColor.gradient)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer.displayName)
                        .font(.headline)
                    if let start = prayerTimeService.timeForPrayer(prayer) {
                        let endText = prayerTimeService.prayerEndTime(prayer).map { " · ends \(formatTime($0))" } ?? ""
                        Text("\(formatTime(start))\(endText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()

            // Scrollable Content
            ScrollView {
                VStack(spacing: 20) {
                    // Reminders Master Toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reminders Enabled")
                                    .fontWeight(.medium)
                                Text("Receive alerts and notifications for this prayer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: $alertsEnabled)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }

                    if alertsEnabled {
                        // Alert Types
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ALERT TYPES")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)

                            VStack(spacing: 0) {
                                // Start reminder
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("When prayer starts")
                                        if let start = prayerTimeService.timeForPrayer(prayer) {
                                            Text("Alert at \(formatTime(start))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Toggle("", isOn: $startAlertEnabled)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(12)

                                Divider()

                                // Late reminder
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Late reminder")
                                        Text("Alert before waqt ends")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $lateAlertEnabled)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(12)

                                if lateAlertEnabled {
                                    Divider()

                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Customize late reminder time")
                                            Text("Override the global late reminder offset")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Toggle("", isOn: $lateReminderOverridden)
                                            .toggleStyle(.switch)
                                            .labelsHidden()
                                    }
                                    .padding(12)

                                    if lateReminderOverridden {
                                        Divider()

                                        HStack {
                                            Text("Remind me")
                                                .font(.subheadline)
                                            Spacer()
                                            Picker("", selection: $lateOffset) {
                                                Text("15 min").tag(15)
                                                Text("30 min").tag(30)
                                                Text("45 min").tag(45)
                                                Text("1 hour").tag(60)
                                            }
                                            .pickerStyle(.segmented)
                                            .frame(width: 250)
                                        }
                                        .padding(12)
                                    } else {
                                        Divider()

                                        HStack {
                                            Text("Global late reminder time")
                                                .font(.subheadline)
                                            Spacer()
                                            let globalOffset = UserDefaults.standard.integer(forKey: "lateReminderOffsetGlobal")
                                            let offsetVal = globalOffset == 0 ? 15 : globalOffset
                                            Text("\(offsetVal) min")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(12)
                                    }
                                }
                            }
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        // Sound Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SOUND")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)

                            VStack(spacing: 0) {
                                ForEach(soundOptions, id: \.self) { sound in
                                    HStack {
                                        Circle()
                                            .stroke(selectedSoundName == sound ? Color.blue : Color.secondary.opacity(0.5), lineWidth: 1.5)
                                            .fill(selectedSoundName == sound ? Color.blue : Color.clear)
                                            .frame(width: 14, height: 14)
                                            .overlay(
                                                Circle()
                                                    .fill(.white)
                                                    .frame(width: 4, height: 4)
                                                    .opacity(selectedSoundName == sound ? 1 : 0)
                                            )
                                            .onTapGesture {
                                                selectedSoundName = sound
                                            }

                                        Text(sound)
                                            .font(.subheadline)
                                            .padding(.leading, 6)

                                        Spacer()

                                        if sound != "Silent" {
                                            Button(action: {
                                                toggleSoundPreview(sound)
                                            }) {
                                                Image(systemName: playingSound == sound ? "square.fill" : "play.fill")
                                                    .font(.caption)
                                                    .foregroundStyle(playingSound == sound ? .white : .blue)
                                                    .frame(width: 24, height: 24)
                                                    .background(playingSound == sound ? Color.blue : Color(NSColor.controlBackgroundColor))
                                                    .clipShape(Circle())
                                                    .shadow(radius: 0.5)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedSoundName = sound
                                    }

                                    Divider()
                                }

                                // Volume Slider
                                HStack(spacing: 10) {
                                    Image(systemName: soundVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20)
                                    Slider(value: $soundVolume, in: 0...1)
                                    Text("\(Int(soundVolume * 100))%")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 35, alignment: .trailing)
                                }
                                .padding(12)
                            }
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        // Display Settings
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DISPLAY")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)

                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Full-screen alert")
                                        Text("Takes over the screen until dismissed")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $fullscreenEnabled)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(12)

                                Divider()

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Show on all spaces")
                                        Text("Appear over Mission Control desktops")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $showOnAllSpaces)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(12)

                                Divider()

                                HStack {
                                    Text("Auto-dismiss after")
                                    Spacer()
                                    Picker("", selection: $autoDismissMinutes) {
                                        Text("Never").tag(0)
                                        Text("1 min").tag(1)
                                        Text("2 min").tag(2)
                                        Text("5 min").tag(5)
                                        Text("10 min").tag(10)
                                    }
                                    .frame(width: 150)
                                }
                                .padding(12)
                            }
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        // Snooze Options
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SNOOZE OPTIONS")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Select the options shown on the overlay alerts:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 8) {
                                    ForEach(snoozePresets, id: \.self) { minutes in
                                        let isSelected = snoozeMinutes.contains(minutes)
                                        Button(action: {
                                            if isSelected {
                                                snoozeMinutes.remove(minutes)
                                            } else {
                                                snoozeMinutes.insert(minutes)
                                            }
                                        }) {
                                            HStack(spacing: 4) {
                                                Text("\(minutes)m")
                                                    .font(.caption)
                                                if isSelected {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 8, weight: .bold))
                                                }
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(isSelected ? Color.blue : Color.secondary.opacity(0.15))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .cornerRadius(12)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        // Do Not Disturb
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DO NOT DISTURB / FOCUS")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)

                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Customize Focus settings")
                                        Text("Override the global Respect Do Not Disturb setting")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $prayerOverrideDNDOverridden)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(12)

                                if prayerOverrideDNDOverridden {
                                    Divider()
                                    
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Override Do Not Disturb")
                                            Text("Show alert even when Focus is active")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Toggle("", isOn: $overrideDND)
                                            .toggleStyle(.switch)
                                            .labelsHidden()
                                    }
                                    .padding(12)
                                } else {
                                    Divider()
                                    
                                    HStack {
                                        Text("Global Focus setting")
                                            .font(.subheadline)
                                        Spacer()
                                        let respectDNDGlobal = UserDefaults.standard.bool(forKey: "lateReminderRespectDNDGlobal")
                                        Text(respectDNDGlobal ? "Respect DND (Muted)" : "Override DND (Alert)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                }

                                Divider()

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Show during meetings")
                                        Text("Interrupt active calls (Meet, Zoom, Teams)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $showDuringMeetings)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(12)

                                Divider()

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Show during screen sharing")
                                        Text("Alert may be visible to other participants")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $showDuringScreenSharing)
                                        .toggleStyle(.switch)
                                        .labelsHidden()
                                }
                                .padding(12)
                            }
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }

                        // Custom Message
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CUSTOM MESSAGE")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)

                            VStack(alignment: .leading, spacing: 6) {
                                TextField("e.g. Congregation (Jamaat) begins in 10 minutes", text: $customMessage)
                                    .textFieldStyle(.roundedBorder)
                                Text("Displayed on the full-screen overlay reminder.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer / Actions
            HStack {
                Button("Reset to Defaults") {
                    resetDefaults()
                }
                .buttonStyle(.link)
                .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    stopSoundPreview()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Done") {
                    saveSettings()
                    stopSoundPreview()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 600)
        .onAppear {
            loadSettings()
        }
        .onDisappear {
            stopSoundPreview()
        }
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func toggleSoundPreview(_ sound: String) {
        if playingSound == sound {
            stopSoundPreview()
        } else {
            playingSound = sound
            let sysSoundName: String
            switch sound {
            case "Adhan — Makkah": sysSoundName = "Hero"
            case "Adhan — Madinah": sysSoundName = "Ping"
            case "Adhan — Egypt": sysSoundName = "Sosumi"
            case "Soft Chime": sysSoundName = "Glass"
            case "Tasbih Bell": sysSoundName = "Tink"
            default: sysSoundName = "Glass"
            }
            // Trigger sound preview on main actor
            Task { @MainActor in
                AlertSoundService.shared.playPreview(soundName: sysSoundName, volume: soundVolume)
            }
            // Auto stop preview after 5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if playingSound == sound {
                    stopSoundPreview()
                }
            }
        }
    }

    private func stopSoundPreview() {
        playingSound = nil
        Task { @MainActor in
            AlertSoundService.shared.stopPreview()
        }
    }

    // MARK: - Persistence

    private func loadSettings() {
        let defaults = UserDefaults.standard
        let pKey = prayer.rawValue

        // Reminders enabled
        let notifPerPrayer = (defaults.dictionary(forKey: AppSettingsKey.prayerNotificationPerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerNotificationPerPrayer
        alertsEnabled = notifPerPrayer[pKey] ?? true

        // Start alert enabled
        let o1PerPrayer = (defaults.dictionary(forKey: AppSettingsKey.overlay1PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay1PerPrayer
        startAlertEnabled = o1PerPrayer[pKey] ?? true

        // Late alert enabled
        let o2PerPrayer = (defaults.dictionary(forKey: AppSettingsKey.overlay2PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay2PerPrayer
        lateAlertEnabled = o2PerPrayer[pKey] ?? true

        // Late offset
        let overridden = (defaults.dictionary(forKey: "prayerLateReminderOverridden") as? [String: Bool]) ?? [:]
        lateReminderOverridden = overridden[pKey] ?? false
        
        let offsets = (defaults.dictionary(forKey: AppSettingsKey.prayerLateReminderOffset) as? [String: Int])
            ?? AppSettingsDefault.defaultPrayerLateReminderOffset
        lateOffset = offsets[pKey] ?? 30

        // Sound Name
        let sounds = (defaults.dictionary(forKey: AppSettingsKey.prayerSoundName) as? [String: String])
            ?? AppSettingsDefault.defaultPrayerSoundName
        selectedSoundName = sounds[pKey] ?? "Soft Chime"

        // Sound Volume
        let volumes = (defaults.dictionary(forKey: AppSettingsKey.prayerSoundVolume) as? [String: Double])
            ?? AppSettingsDefault.defaultPrayerSoundVolume
        soundVolume = volumes[pKey] ?? 0.7

        // Display
        let fullscreen = (defaults.dictionary(forKey: AppSettingsKey.prayerFullScreenEnabled) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerFullScreenEnabled
        fullscreenEnabled = fullscreen[pKey] ?? true

        let allSpaces = (defaults.dictionary(forKey: AppSettingsKey.prayerShowOnAllSpaces) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerShowOnAllSpaces
        showOnAllSpaces = allSpaces[pKey] ?? true

        let autoDismiss = (defaults.dictionary(forKey: AppSettingsKey.prayerAutoDismissMinutes) as? [String: Int])
            ?? AppSettingsDefault.defaultPrayerAutoDismissMinutes
        autoDismissMinutes = autoDismiss[pKey] ?? 0

        // DND Focus
        let overriddenDND = (defaults.dictionary(forKey: "prayerOverrideDNDOverridden") as? [String: Bool]) ?? [:]
        prayerOverrideDNDOverridden = overriddenDND[pKey] ?? false

        let dnds = (defaults.dictionary(forKey: AppSettingsKey.prayerOverrideDND) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerOverrideDND
        overrideDND = dnds[pKey] ?? true

        let meetings = (defaults.dictionary(forKey: AppSettingsKey.prayerShowDuringMeetings) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerShowDuringMeetings
        showDuringMeetings = meetings[pKey] ?? false

        let sharing = (defaults.dictionary(forKey: AppSettingsKey.prayerShowDuringScreenSharing) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerShowDuringScreenSharing
        showDuringScreenSharing = sharing[pKey] ?? false

        // Custom Message
        let msgs = (defaults.dictionary(forKey: AppSettingsKey.prayerCustomMessage) as? [String: String])
            ?? AppSettingsDefault.defaultPrayerCustomMessage
        customMessage = msgs[pKey] ?? ""

        // Snooze Options
        let snoozeOpts = (defaults.dictionary(forKey: AppSettingsKey.prayerSnoozeOptions) as? [String: String])
            ?? [:]
        let snoozeStr = snoozeOpts[pKey] ?? "5,10,15"
        let minutesList = snoozeStr.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        snoozeMinutes = Set(minutesList)
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        let pKey = prayer.rawValue

        // Reminders enabled
        var notifPerPrayer = (defaults.dictionary(forKey: AppSettingsKey.prayerNotificationPerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerNotificationPerPrayer
        notifPerPrayer[pKey] = alertsEnabled
        defaults.set(notifPerPrayer, forKey: AppSettingsKey.prayerNotificationPerPrayer)

        // Start alert enabled
        var o1PerPrayer = (defaults.dictionary(forKey: AppSettingsKey.overlay1PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay1PerPrayer
        o1PerPrayer[pKey] = startAlertEnabled
        defaults.set(o1PerPrayer, forKey: AppSettingsKey.overlay1PerPrayer)

        // Late alert enabled
        var o2PerPrayer = (defaults.dictionary(forKey: AppSettingsKey.overlay2PerPrayer) as? [String: Bool])
            ?? AppSettingsDefault.defaultOverlay2PerPrayer
        o2PerPrayer[pKey] = lateAlertEnabled
        defaults.set(o2PerPrayer, forKey: AppSettingsKey.overlay2PerPrayer)

        // Late offset
        var overridden = (defaults.dictionary(forKey: "prayerLateReminderOverridden") as? [String: Bool]) ?? [:]
        overridden[pKey] = lateReminderOverridden
        defaults.set(overridden, forKey: "prayerLateReminderOverridden")

        var offsets = (defaults.dictionary(forKey: AppSettingsKey.prayerLateReminderOffset) as? [String: Int])
            ?? AppSettingsDefault.defaultPrayerLateReminderOffset
        offsets[pKey] = lateOffset
        defaults.set(offsets, forKey: AppSettingsKey.prayerLateReminderOffset)

        // Sound Name
        var sounds = (defaults.dictionary(forKey: AppSettingsKey.prayerSoundName) as? [String: String])
            ?? AppSettingsDefault.defaultPrayerSoundName
        sounds[pKey] = selectedSoundName
        defaults.set(sounds, forKey: AppSettingsKey.prayerSoundName)

        // Sound Volume
        var volumes = (defaults.dictionary(forKey: AppSettingsKey.prayerSoundVolume) as? [String: Double])
            ?? AppSettingsDefault.defaultPrayerSoundVolume
        volumes[pKey] = soundVolume
        defaults.set(volumes, forKey: AppSettingsKey.prayerSoundVolume)

        // Display
        var fullscreen = (defaults.dictionary(forKey: AppSettingsKey.prayerFullScreenEnabled) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerFullScreenEnabled
        fullscreen[pKey] = fullscreenEnabled
        defaults.set(fullscreen, forKey: AppSettingsKey.prayerFullScreenEnabled)

        var allSpaces = (defaults.dictionary(forKey: AppSettingsKey.prayerShowOnAllSpaces) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerShowOnAllSpaces
        allSpaces[pKey] = showOnAllSpaces
        defaults.set(allSpaces, forKey: AppSettingsKey.prayerShowOnAllSpaces)

        var autoDismiss = (defaults.dictionary(forKey: AppSettingsKey.prayerAutoDismissMinutes) as? [String: Int])
            ?? AppSettingsDefault.defaultPrayerAutoDismissMinutes
        autoDismiss[pKey] = autoDismissMinutes
        defaults.set(autoDismiss, forKey: AppSettingsKey.prayerAutoDismissMinutes)

        // DND Focus
        var overriddenDND = (defaults.dictionary(forKey: "prayerOverrideDNDOverridden") as? [String: Bool]) ?? [:]
        overriddenDND[pKey] = prayerOverrideDNDOverridden
        defaults.set(overriddenDND, forKey: "prayerOverrideDNDOverridden")

        var dnds = (defaults.dictionary(forKey: AppSettingsKey.prayerOverrideDND) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerOverrideDND
        dnds[pKey] = overrideDND
        defaults.set(dnds, forKey: AppSettingsKey.prayerOverrideDND)

        var meetings = (defaults.dictionary(forKey: AppSettingsKey.prayerShowDuringMeetings) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerShowDuringMeetings
        meetings[pKey] = showDuringMeetings
        defaults.set(meetings, forKey: AppSettingsKey.prayerShowDuringMeetings)

        var sharing = (defaults.dictionary(forKey: AppSettingsKey.prayerShowDuringScreenSharing) as? [String: Bool])
            ?? AppSettingsDefault.defaultPrayerShowDuringScreenSharing
        sharing[pKey] = showDuringScreenSharing
        defaults.set(sharing, forKey: AppSettingsKey.prayerShowDuringScreenSharing)

        // Custom Message
        var msgs = (defaults.dictionary(forKey: AppSettingsKey.prayerCustomMessage) as? [String: String])
            ?? AppSettingsDefault.defaultPrayerCustomMessage
        msgs[pKey] = customMessage
        defaults.set(msgs, forKey: AppSettingsKey.prayerCustomMessage)

        // Snooze Options
        var snoozeOpts = (defaults.dictionary(forKey: AppSettingsKey.prayerSnoozeOptions) as? [String: String])
            ?? [:]
        let sortedMinutes = snoozeMinutes.sorted()
        snoozeOpts[pKey] = sortedMinutes.map { String($0) }.joined(separator: ",")
        defaults.set(snoozeOpts, forKey: AppSettingsKey.prayerSnoozeOptions)

        // Recompute prayer configurations and notification timers
        prayerTimeService.recompute()
        notificationService.scheduleAll()
    }

    private func resetDefaults() {
        alertsEnabled = true
        startAlertEnabled = true
        lateAlertEnabled = true
        lateReminderOverridden = false
        lateOffset = 30
        selectedSoundName = "Soft Chime"
        soundVolume = 0.7
        fullscreenEnabled = true
        showOnAllSpaces = true
        autoDismissMinutes = 0
        prayerOverrideDNDOverridden = false
        overrideDND = true
        showDuringMeetings = false
        showDuringScreenSharing = false
        customMessage = ""
        snoozeMinutes = [5, 10, 15]
    }
}
