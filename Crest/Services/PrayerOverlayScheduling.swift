import Foundation

/// Pure timing decisions for the prayer start reminder (Overlay 1), kept free
/// of timers, UserDefaults, and AppKit so waqt timing scenarios can be
/// simulated directly in unit tests (see `PrayerOverlaySchedulingTests`).
///
/// Waqts are contiguous: each prayer's window ends at the exact instant the
/// next one begins (Dhuhr ends when Asr starts, Asr ends when Maghrib starts,
/// and so on). The two overlays are sequenced around that shared instant:
/// the ending reminder (Overlay 2) fires shortly before the waqt closes, and
/// the start reminder fires at the moment the new waqt begins. They never
/// fire simultaneously, and neither may ever suppress the other.
enum PrayerOverlayScheduling {

    /// How long after its fire time a missed start reminder is still worth
    /// showing on catch-up (app launch mid-window, wake from sleep).
    static let graceMinutes: TimeInterval = 15

    /// What a scheduling pass should do for one prayer at a given moment.
    enum ReminderAction: Equatable {
        /// Arm a timer to fire at the given time.
        case schedule(at: Date)
        /// The fire time already passed but the reminder is still within its
        /// grace window (app launched mid-window, wake from sleep, or a timer
        /// lost to a reschedule race). Show it immediately.
        case fireNow
        /// Nothing to do for this prayer right now.
        case skip
    }

    /// The start reminder fires when the prayer actually begins: at the
    /// configured jamaat time when one applies, otherwise at the waqt start.
    static func fireTime(prayerStart: Date, jamaatTime: Date?) -> Date {
        jamaatTime ?? prayerStart
    }

    /// The moment a missed start reminder stops being worth showing: a short
    /// grace window after its fire time.
    static func validUntil(prayerStart: Date, jamaatTime: Date?) -> Date {
        fireTime(prayerStart: prayerStart, jamaatTime: jamaatTime)
            .addingTimeInterval(graceMinutes * 60)
    }

    /// When the ending reminder (Overlay 2) fires: `warningMinutes` before
    /// the waqt closes. Lives here so tests can pin the relative ordering of
    /// the two overlays around a waqt transition.
    static func endingReminderFireTime(prayerEnd: Date, warningMinutes: TimeInterval) -> Date {
        prayerEnd.addingTimeInterval(-warningMinutes * 60)
    }

    /// Full per-prayer decision for a scheduling pass at `now`.
    ///
    /// Note what is deliberately absent here: nothing about the predecessor
    /// prayer, its end time, or its ending reminder (Overlay 2). An earlier
    /// version suppressed the start reminder whenever the predecessor's waqt
    /// ended at this prayer's start; since that adjacency always holds, Asr,
    /// Maghrib, Isha, and Fajr never got start reminders (client-reported
    /// bug). Both overlays are independent features and must stay independent
    /// here.
    static func startReminderAction(
        prayer: Prayer,
        prayerStart: Date,
        jamaatTime: Date?,
        isEnabled: Bool,
        isDismissed: Bool,
        hasAlreadyFired: Bool,
        now: Date
    ) -> ReminderAction {
        guard prayer != .sunrise, isEnabled, !isDismissed else { return .skip }

        let fire = fireTime(prayerStart: prayerStart, jamaatTime: jamaatTime)
        if fire > now {
            return .schedule(at: fire)
        }

        let deadline = validUntil(prayerStart: prayerStart, jamaatTime: jamaatTime)
        if !hasAlreadyFired && now < deadline {
            return .fireNow
        }
        return .skip
    }
}
