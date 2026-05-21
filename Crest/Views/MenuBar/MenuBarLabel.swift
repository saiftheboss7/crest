import SwiftUI
import EventKit

struct MenuBarLabel: View {
    @AppStorage(AppSettingsKey.dateFormat) private var dateFormat = AppSettingsDefault.dateFormat
    @AppStorage(AppSettingsKey.showSeconds) private var showSeconds = AppSettingsDefault.showSeconds
    @AppStorage(AppSettingsKey.showUpcomingEventInMenuBar) private var showEvent = AppSettingsDefault.showUpcomingEventInMenuBar
    @AppStorage(AppSettingsKey.menuBarEventMaxLength) private var maxEventLength = AppSettingsDefault.menuBarEventMaxLength
    @AppStorage(AppSettingsKey.showHijriInMenuBar) private var showHijri = AppSettingsDefault.showHijriInMenuBar
    @AppStorage(AppSettingsKey.islamicModeEnabled) private var islamicModeEnabled = AppSettingsDefault.islamicModeEnabled

    var clock: ClockService
    var calendarService: CalendarService
    var prayerTimeService: PrayerTimeService?

    private var upcomingTarget: (title: String, date: Date, isPrayer: Bool)? {
        let now = clock.currentTime
        
        var targetPrayer: (String, Date)? = nil
        if islamicModeEnabled, let prayerService = prayerTimeService {
            if let current = prayerService.highlightedPrayer, let endTime = prayerService.prayerEndTime(current) {
                targetPrayer = ("\(current.displayName)", endTime)
            } else if let next = prayerService.nextPrayer, let nextTime = prayerService.timeForPrayer(next) {
                targetPrayer = (next.displayName, nextTime)
            }
        }
        
        var targetEvent: (String, Date)? = nil
        if let event = calendarService.nextEvent {
            if event.startDate > now {
                targetEvent = (event.title ?? "Meeting", event.startDate)
            }
        }
        
        switch (targetPrayer, targetEvent) {
        case (.some(let p), .some(let e)):
            if p.1 < e.1 {
                return (p.0, p.1, true)
            } else {
                return (e.0, e.1, false)
            }
        case (.some(let p), .none):
            return (p.0, p.1, true)
        case (.none, .some(let e)):
            return (e.0, e.1, false)
        case (.none, .none):
            return nil
        }
    }

    private func getRemainingStr(for date: Date, now: Date) -> String {
        let diff = date.timeIntervalSince(now)
        let totalMins = Int(max(0, diff / 60))
        if totalMins < 60 {
            return "in \(totalMins)m"
        } else {
            let hours = totalMins / 60
            let mins = totalMins % 60
            return "in \(hours)h \(mins)m"
        }
    }

    private func getProgress(for target: (title: String, date: Date, isPrayer: Bool), diff: TimeInterval) -> Double {
        if target.isPrayer {
            if let prayerService = prayerTimeService,
               let current = prayerService.highlightedPrayer,
               let start = prayerService.timeForPrayer(current) {
                let end = prayerService.prayerEndTime(current) ?? Date().addingTimeInterval(3600)
                let total = end.timeIntervalSince(start)
                return total > 0 ? max(0, min(1.0, diff / total)) : 1.0
            } else if let prayerService = prayerTimeService,
                      let next = prayerService.nextPrayer {
                return max(0, min(1.0, diff / (120 * 60))) // count down from 2 hours
            } else {
                return 1.0
            }
        } else {
            return max(0, min(1.0, diff / (30 * 60))) // count down from 30 minutes
        }
    }

    var body: some View {
        let timeText = clock.formattedTime(format: dateFormat, showSeconds: showSeconds)
        let now = clock.currentTime

        HStack(spacing: 6) {
            // Time
            Text(timeText)
            
            // Hijri
            if showHijri, islamicModeEnabled, let prayerService = prayerTimeService {
                let hijri = prayerService.hijriDateString
                if !hijri.isEmpty {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(hijri)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Countdown Ring and Remaining Time
            if showEvent, let target = upcomingTarget {
                let diff = target.date.timeIntervalSince(now)
                if diff > 0 {
                    let remainingStr = getRemainingStr(for: target.date, now: now)
                    let progress = getProgress(for: target, diff: diff)
                    
                    Text("·")
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                                .frame(width: 11, height: 11)
                            Circle()
                                .trim(from: 0.0, to: CGFloat(progress))
                                .stroke(target.isPrayer ? Color(red: 0.85, green: 0.65, blue: 0.15) : Color.blue, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                .frame(width: 11, height: 11)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        Text(remainingStr)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
