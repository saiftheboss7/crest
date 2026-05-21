import XCTest
@testable import Crest

/// `formatCountdown` is the canonical string used in the popover countdown badge
/// and the menu bar label. It's three-tier — "Xh Ym Zs" / "Ym Zs" / "Zs" — so
/// the popover can show a live tick rather than coarse minute snaps.
@MainActor
final class PrayerCountdownFormatterTests: XCTestCase {

    // MARK: - formatCountdown

    func test_formatCountdown_zero() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(0), "0s")
    }

    func test_formatCountdown_subMinuteShowsSeconds() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(59), "59s")
    }

    func test_formatCountdown_oneMinuteExact() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(60), "1m 0s")
    }

    func test_formatCountdown_oneMinuteFiveSeconds() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(65), "1m 5s")
    }

    func test_formatCountdown_just_under_one_hour() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(3599), "59m 59s")
    }

    func test_formatCountdown_exactlyOneHour() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(3600), "1h 0m 0s")
    }

    func test_formatCountdown_oneHourOneMinute() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(3661), "1h 1m 1s")
    }

    func test_formatCountdown_multiHour() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(2 * 3600 + 15 * 60 + 30), "2h 15m 30s")
    }

    func test_formatCountdown_negativeClampsToZero() {
        XCTAssertEqual(PrayerTimeService.formatCountdown(-30), "0s")
    }

    // MARK: - formatHighlightCountdown

    func test_formatHighlightCountdown_activeAppendsLeft() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(60, isActive: true),
            "1m 0s left"
        )
    }

    func test_formatHighlightCountdown_inactivePrefixesStartsIn() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(3661, isActive: false),
            "Starts in 1h 1m 1s"
        )
    }

    func test_formatHighlightCountdown_subMinute() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(45, isActive: true),
            "45s left"
        )
    }

    func test_formatHighlightCountdown_zero_active() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(0, isActive: true),
            "0s left"
        )
    }

    func test_formatHighlightCountdown_zero_inactive() {
        XCTAssertEqual(
            PrayerTimeService.formatHighlightCountdown(0, isActive: false),
            "Starts in 0s"
        )
    }
}
