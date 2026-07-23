import XCTest
@testable import Crest

/// Simulated-clock tests for the start reminder (Overlay 1) decision logic.
///
/// Regression coverage for a client-reported bug: waqts are contiguous, so
/// Dhuhr ends at the exact instant Asr begins (4:44 PM in the report). The
/// old fire-time gate treated that adjacency as a collision with Dhuhr's
/// ending reminder and suppressed the Asr start reminder entirely; since the
/// adjacency always holds, Asr, Maghrib, Isha, and Fajr never got start
/// reminders.
///
/// The corrected sequencing around a transition: the ending reminder fires
/// 15 minutes before the waqt closes (4:29 PM), and the start reminder fires
/// when the new waqt begins (4:44 PM). Never simultaneous, never suppressed.
final class PrayerOverlaySchedulingTests: XCTestCase {

    // MARK: - Fixtures

    /// Builds a Date on a fixed day (22 July 2026) at the given wall-clock
    /// time, so scenarios read like the client's report ("Asr at 4:44 PM").
    private func at(_ hour: Int, _ minute: Int, second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 22
        components.hour = hour
        components.minute = minute
        components.second = second
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }

    /// The client's reported schedule: Dhuhr ends 4:44 PM, Asr starts 4:44 PM.
    private var asrStart: Date { at(16, 44) }

    private func asrAction(
        jamaatTime: Date? = nil,
        isEnabled: Bool = true,
        isDismissed: Bool = false,
        hasAlreadyFired: Bool = false,
        now: Date
    ) -> PrayerOverlayScheduling.ReminderAction {
        PrayerOverlayScheduling.startReminderAction(
            prayer: .asr,
            prayerStart: asrStart,
            jamaatTime: jamaatTime,
            isEnabled: isEnabled,
            isDismissed: isDismissed,
            hasAlreadyFired: hasAlreadyFired,
            now: now
        )
    }

    // MARK: - Client regression: Dhuhr ends 4:44 PM, Asr starts 4:44 PM

    func test_asrStartReminder_isScheduled_whenDhuhrEndsExactlyAtAsrStart() {
        // 4:20 PM, before the fire time. Dhuhr's end (4:44) equals Asr's
        // start (4:44) by definition; that adjacency must not affect the
        // schedule in any way.
        let action = asrAction(now: at(16, 20))
        XCTAssertEqual(
            action, .schedule(at: at(16, 44)),
            "Asr start reminder must arm for the 4:44 PM waqt start"
        )
    }

    func test_asrStartReminder_fires_atItsFireTime() {
        // Exactly 4:44 PM. A pass at the armed timer's instant must show the
        // reminder, never skip it.
        XCTAssertEqual(asrAction(now: at(16, 44)), .fireNow)
    }

    func test_endingAndStartReminders_neverFireSimultaneously_onContiguousWaqts() {
        // Dhuhr's ending reminder fires 15 minutes before the shared 4:44 PM
        // boundary; Asr's start reminder fires at the boundary itself.
        let dhuhrEnd = asrStart
        let endingFire = PrayerOverlayScheduling.endingReminderFireTime(prayerEnd: dhuhrEnd, warningMinutes: 15)
        let startFire = PrayerOverlayScheduling.fireTime(prayerStart: asrStart, jamaatTime: nil)

        XCTAssertEqual(endingFire, at(16, 29), "Dhuhr ending reminder must fire at 4:29 PM")
        XCTAssertEqual(startFire, at(16, 44), "Asr start reminder must fire at 4:44 PM")
        XCTAssertGreaterThan(startFire, endingFire, "Start reminder must come after the ending reminder")
    }

    func test_everyAdjustablePrayer_getsAStartReminder_acrossAContiguousDay() {
        // A realistic day; every waqt ends exactly when the next one begins,
        // which previously suppressed every start reminder except Dhuhr's.
        let starts: [Prayer: Date] = [
            .fajr: at(4, 15),
            .dhuhr: at(13, 15),
            .asr: at(16, 44),
            .maghrib: at(18, 55),
            .isha: at(20, 15),
        ]
        for (prayer, start) in starts {
            let action = PrayerOverlayScheduling.startReminderAction(
                prayer: prayer,
                prayerStart: start,
                jamaatTime: nil,
                isEnabled: true,
                isDismissed: false,
                hasAlreadyFired: false,
                now: at(0, 0)
            )
            XCTAssertEqual(
                action, .schedule(at: start),
                "\(prayer.displayName) start reminder is missing from the day's schedule"
            )
        }
    }

    // MARK: - Catch-up (app launch mid-window, reschedule races)

    func test_startReminder_catchesUp_whenFireTimeWasMissed() {
        // App launched at 4:50 PM, past the 4:44 fire time but within the
        // grace window. The reminder must still show.
        XCTAssertEqual(asrAction(now: at(16, 50)), .fireNow)
    }

    func test_startReminder_catchesUp_untilTheFinalSecondOfGrace() {
        XCTAssertEqual(asrAction(now: at(16, 58, second: 59)), .fireNow)
    }

    func test_startReminder_skips_onceGraceWindowHasPassed() {
        XCTAssertEqual(asrAction(now: at(16, 59)), .skip)
        XCTAssertEqual(asrAction(now: at(17, 30)), .skip)
    }

    func test_startReminder_doesNotRefire_afterItAlreadyShowed() {
        // Refresh pass at 4:46 PM after the reminder showed at 4:44. The
        // catch-up path must not re-fire it every minute.
        XCTAssertEqual(asrAction(hasAlreadyFired: true, now: at(16, 46)), .skip)
    }

    // MARK: - Wake from sleep

    func test_wake_firesReminderMissedDuringSleep_whileGraceStillOpen() {
        // Slept from 4:40 to 4:52 PM; the 4:44 fire time passed during sleep
        // and the grace window is still open.
        XCTAssertEqual(asrAction(now: at(16, 52)), .fireNow)
    }

    func test_wake_skipsReminder_whenGracePassedDuringSleep() {
        XCTAssertEqual(asrAction(now: at(17, 10)), .skip)
    }

    // MARK: - Per-prayer gates

    func test_startReminder_skips_whenDisabledForThatPrayer() {
        XCTAssertEqual(asrAction(isEnabled: false, now: at(16, 20)), .skip)
    }

    func test_startReminder_skips_whenAlreadyDismissed() {
        XCTAssertEqual(asrAction(isDismissed: true, now: at(16, 20)), .skip)
    }

    func test_startReminder_neverTargetsSunrise() {
        let action = PrayerOverlayScheduling.startReminderAction(
            prayer: .sunrise,
            prayerStart: at(5, 35),
            jamaatTime: nil,
            isEnabled: true,
            isDismissed: false,
            hasAlreadyFired: false,
            now: at(4, 0)
        )
        XCTAssertEqual(action, .skip)
    }

    // MARK: - Jamaat mode

    func test_jamaatReminder_firesAtJamaatTime_notAtWaqtStart() {
        // Asr jamaat at 5:00 PM (after the 4:44 waqt start).
        XCTAssertEqual(asrAction(jamaatTime: at(17, 0), now: at(16, 20)), .schedule(at: at(17, 0)))
    }

    func test_jamaatReminder_catchesUp_withinGraceWindow() {
        XCTAssertEqual(asrAction(jamaatTime: at(17, 0), now: at(17, 10)), .fireNow)
        XCTAssertEqual(asrAction(jamaatTime: at(17, 0), now: at(17, 14, second: 59)), .fireNow)
    }

    func test_jamaatReminder_skips_afterGraceWindow() {
        XCTAssertEqual(asrAction(jamaatTime: at(17, 0), now: at(17, 15)), .skip)
        XCTAssertEqual(asrAction(jamaatTime: at(17, 0), now: at(17, 16)), .skip)
    }

    // MARK: - Fire time / valid-until primitives

    func test_fireTime_isTheWaqtStart() {
        XCTAssertEqual(PrayerOverlayScheduling.fireTime(prayerStart: asrStart, jamaatTime: nil), asrStart)
    }

    func test_validUntil_isGraceAfterWaqtStart_forRegularReminders() {
        XCTAssertEqual(
            PrayerOverlayScheduling.validUntil(prayerStart: asrStart, jamaatTime: nil),
            at(16, 59)
        )
    }

    func test_validUntil_isGraceAfterJamaatTime_forJamaatReminders() {
        XCTAssertEqual(
            PrayerOverlayScheduling.validUntil(prayerStart: asrStart, jamaatTime: at(17, 0)),
            at(17, 15)
        )
    }
}
