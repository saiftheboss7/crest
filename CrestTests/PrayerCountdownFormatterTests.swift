import XCTest
@testable import Crest

@MainActor
final class PrayerCountdownFormatterTests: XCTestCase {

    // MARK: - formatCountdown

    func test_formatCountdown_zero() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(0), "0m")
    }

    func test_formatCountdown_subMinuteTruncatesToZero() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(59), "0m")
    }

    func test_formatCountdown_oneMinute() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(60), "1m")
    }

    func test_formatCountdown_just_under_one_hour() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(3599), "59m")
    }

    func test_formatCountdown_exactlyOneHour() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(3600), "1h 0m")
    }

    func test_formatCountdown_oneHourOneMinute() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(3661), "1h 1m")
    }

    func test_formatCountdown_multiHour() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(2 * 3600 + 15 * 60), "2h 15m")
    }

    func test_formatCountdown_negativeClampsToZero() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(-30), "0m")
    }

    // MARK: - formatHighlightCountdown

    func test_formatHighlightCountdown_activeAppendsLeft() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(60, isActive: true),
            "1m left"
        )
    }

    func test_formatHighlightCountdown_inactivePrefixesIn() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(3661, isActive: false),
            "in 1h 1m"
        )
    }

    func test_formatHighlightCountdown_zero_active() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(0, isActive: true),
            "0m left"
        )
    }

    func test_formatHighlightCountdown_zero_inactive() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(0, isActive: false),
            "in 0m"
        )
    }
}
