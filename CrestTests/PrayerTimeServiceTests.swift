import XCTest
@testable import Crest

/// Smoke / integration tests for `PrayerTimeService`.
///
/// We don't try to mock Adhan — the value here is detecting if recompute() ever
/// stops producing a valid 6-entry schedule (fajr / sunrise / dhuhr / asr / maghrib / isha)
/// for a known location.
///
/// Time-of-day–dependent logic (current vs next prayer, highlight countdown,
/// snooze, jamaat reschedule) is not unit-tested — see `.agents/plans/TESTING.md` § 3.
@MainActor
final class PrayerTimeServiceTests: XCTestCase {

    private var savedKeys: [(key: String, value: Any?)] = []

    override func setUp() async throws {
        savedKeys = []
        let defaults = UserDefaults.standard

        // Snapshot keys we're about to mutate so we can restore them in tearDown.
        let mutating = [
            AppSettingsKey.islamicModeEnabled,
            AppSettingsKey.staticLocationEnabled,
            AppSettingsKey.staticLatitude,
            AppSettingsKey.staticLongitude,
            AppSettingsKey.calculationMethod,
            AppSettingsKey.madhab,
            AppSettingsKey.shafaq,
            AppSettingsKey.jamaatTimesEnabled,
            AppSettingsKey.hijriDateOffset,
        ]
        for key in mutating {
            savedKeys.append((key, defaults.object(forKey: key)))
        }

        // Dhaka, Bangladesh — stable fixture coordinates.
        defaults.set(true, forKey: AppSettingsKey.islamicModeEnabled)
        defaults.set(true, forKey: AppSettingsKey.staticLocationEnabled)
        defaults.set("23.8103", forKey: AppSettingsKey.staticLatitude)
        defaults.set("90.4125", forKey: AppSettingsKey.staticLongitude)
        defaults.set("moonsightingCommittee", forKey: AppSettingsKey.calculationMethod)
        defaults.set("shafi", forKey: AppSettingsKey.madhab)
        defaults.set("general", forKey: AppSettingsKey.shafaq)
        defaults.set(false, forKey: AppSettingsKey.jamaatTimesEnabled)
        defaults.set(0, forKey: AppSettingsKey.hijriDateOffset)
    }

    override func tearDown() async throws {
        let defaults = UserDefaults.standard
        for (key, value) in savedKeys {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        savedKeys = []
    }

    func test_recompute_producesAllSixDailyPrayerEntries() {
        let service = PrayerTimeService(locationService: LocationService())
        service.recompute()

        XCTAssertEqual(service.todayPrayers.count, 6, "Expected fajr, sunrise, dhuhr, asr, maghrib, isha")

        let prayers = service.todayPrayers.map(\.prayer)
        XCTAssertEqual(prayers, [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha])
    }

    func test_recompute_timesAreInChronologicalOrder() {
        let service = PrayerTimeService(locationService: LocationService())
        service.recompute()

        let times = service.todayPrayers.map(\.time)
        for i in 1..<times.count {
            XCTAssertLessThan(
                times[i - 1], times[i],
                "Prayer at index \(i - 1) (\(service.todayPrayers[i - 1].prayer)) should come before index \(i)"
            )
        }
    }

    func test_recompute_allTimesFallOnToday() {
        let service = PrayerTimeService(locationService: LocationService())
        service.recompute()

        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            return XCTFail("Could not compute tomorrow")
        }

        for prayerTime in service.todayPrayers {
            XCTAssertGreaterThanOrEqual(prayerTime.time, today, "\(prayerTime.prayer) is before today's start")
            XCTAssertLessThan(prayerTime.time, tomorrow, "\(prayerTime.prayer) leaks into tomorrow")
        }
    }

    func test_recompute_populatesHijriDate() {
        let service = PrayerTimeService(locationService: LocationService())
        service.recompute()

        XCTAssertFalse(service.hijriDateString.isEmpty)
        XCTAssertTrue(service.hijriDateString.contains("AH"), "Hijri label should end with ‘AH’ — got \(service.hijriDateString)")
    }

    func test_recompute_populatesIslamicMidnight() {
        let service = PrayerTimeService(locationService: LocationService())
        service.recompute()

        XCTAssertNotNil(service.islamicMidnight, "SunnahTimes should yield a middleOfTheNight for valid coords")
    }

    func test_recompute_clearsStateWhenIslamicModeDisabled() {
        UserDefaults.standard.set(false, forKey: AppSettingsKey.islamicModeEnabled)

        let service = PrayerTimeService(locationService: LocationService())
        service.recompute()

        XCTAssertTrue(service.todayPrayers.isEmpty)
        XCTAssertNil(service.currentPrayer)
        XCTAssertNil(service.nextPrayer)
        XCTAssertEqual(service.hijriDateString, "")
    }

    func test_recompute_clearsStateWhenStaticCoordsInvalid() {
        UserDefaults.standard.set("999", forKey: AppSettingsKey.staticLatitude)

        let service = PrayerTimeService(locationService: LocationService())
        service.recompute()

        XCTAssertTrue(service.todayPrayers.isEmpty, "Out-of-range latitude must yield empty schedule")
    }

    func test_recompute_shafaqAbyadShiftsIshaLaterThanGeneral() {
        let defaults = UserDefaults.standard

        defaults.set("general", forKey: AppSettingsKey.shafaq)
        let generalService = PrayerTimeService(locationService: LocationService())
        generalService.recompute()
        guard let ishaGeneral = generalService.timeForPrayer(.isha) else {
            return XCTFail("Expected Isha time with Shafaq general")
        }

        defaults.set("abyad", forKey: AppSettingsKey.shafaq)
        let abyadService = PrayerTimeService(locationService: LocationService())
        abyadService.recompute()
        guard let ishaAbyad = abyadService.timeForPrayer(.isha) else {
            return XCTFail("Expected Isha time with Shafaq abyad")
        }

        XCTAssertGreaterThan(
            ishaAbyad, ishaGeneral,
            "Shafaq abyad should produce a later Isha than general"
        )
        let deltaMinutes = ishaAbyad.timeIntervalSince(ishaGeneral) / 60
        XCTAssertGreaterThanOrEqual(
            deltaMinutes, 5,
            "Expected at least 5 min gap between Shafaq abyad and general — got \(deltaMinutes) min"
        )
    }

    func test_prayerEndTime_followsCanonicalChain() {
        let service = PrayerTimeService(locationService: LocationService())
        service.recompute()

        // fajr → sunrise → dhuhr → asr → maghrib → isha (end = tomorrowFajrTime)
        XCTAssertEqual(service.prayerEndTime(.fajr), service.timeForPrayer(.sunrise))
        XCTAssertEqual(service.prayerEndTime(.sunrise), service.timeForPrayer(.dhuhr))
        XCTAssertEqual(service.prayerEndTime(.dhuhr), service.timeForPrayer(.asr))
        XCTAssertEqual(service.prayerEndTime(.asr), service.timeForPrayer(.maghrib))
        XCTAssertEqual(service.prayerEndTime(.maghrib), service.timeForPrayer(.isha))
        XCTAssertEqual(service.prayerEndTime(.isha), service.tomorrowFajrTime())
    }
}
