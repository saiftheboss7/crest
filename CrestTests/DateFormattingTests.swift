import XCTest
@testable import Crest

@MainActor
final class DateFormattingTests: XCTestCase {

    /// Fixed reference date: 2026-04-04 14:30:45 local time.
    private func referenceDate() -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 4
        comps.day = 4
        comps.hour = 14
        comps.minute = 30
        comps.second = 45
        return Calendar.current.date(from: comps)!
    }

    // MARK: - menuBarString seconds toggling

    func test_menuBarString_stripsLowercaseSecondsWhenDisabled() {
        let result = DateFormatting.menuBarString(date: referenceDate(), format: "HH:mm:ss", showSeconds: false)
        XCTAssertEqual(result, "14:30")
    }

    func test_menuBarString_stripsCapitalizedSecondsWhenDisabled() {
        let result = DateFormatting.menuBarString(date: referenceDate(), format: "HH:mm:SS", showSeconds: false)
        // Stripping ":SS" leaves "HH:mm" → "14:30"
        XCTAssertEqual(result, "14:30")
    }

    func test_menuBarString_injectsSecondsWhenEnabledAndAbsent() {
        let result = DateFormatting.menuBarString(date: referenceDate(), format: "HH:mm", showSeconds: true)
        XCTAssertEqual(result, "14:30:45")
    }

    func test_menuBarString_doesNotDoubleInjectWhenSecondsAlreadyPresent() {
        let result = DateFormatting.menuBarString(date: referenceDate(), format: "HH:mm:ss", showSeconds: true)
        XCTAssertEqual(result, "14:30:45")
    }

    func test_menuBarString_twelveHourFormatRoundTrips() {
        let off = DateFormatting.menuBarString(date: referenceDate(), format: "h:mm a", showSeconds: false)
        let on  = DateFormatting.menuBarString(date: referenceDate(), format: "h:mm a", showSeconds: true)
        XCTAssertEqual(off, "2:30 PM")
        XCTAssertEqual(on, "2:30:45 PM")
    }

    func test_menuBarString_strippingNoOpWhenFormatHasNoSeconds() {
        let result = DateFormatting.menuBarString(date: referenceDate(), format: "HH:mm", showSeconds: false)
        XCTAssertEqual(result, "14:30")
    }

    // MARK: - eventTimeRange

    func test_eventTimeRange_allDayReturnsLabel() {
        let now = Date()
        XCTAssertEqual(DateFormatting.eventTimeRange(start: now, end: now, isAllDay: true), "All Day")
    }

    func test_eventTimeRange_timedFormatsHMMA() {
        var startComps = DateComponents()
        startComps.year = 2026; startComps.month = 4; startComps.day = 4
        startComps.hour = 9; startComps.minute = 0
        var endComps = startComps
        endComps.hour = 10; endComps.minute = 30
        let start = Calendar.current.date(from: startComps)!
        let end = Calendar.current.date(from: endComps)!

        let result = DateFormatting.eventTimeRange(start: start, end: end, isAllDay: false)
        XCTAssertEqual(result, "9:00 AM – 10:30 AM")
    }

    // MARK: - relativeDayHeader

    func test_relativeDayHeader_today() {
        XCTAssertEqual(DateFormatting.relativeDayHeader(for: Date()), "Today")
    }

    func test_relativeDayHeader_tomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertEqual(DateFormatting.relativeDayHeader(for: tomorrow), "Tomorrow")
    }

    func test_relativeDayHeader_yesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertEqual(DateFormatting.relativeDayHeader(for: yesterday), "Yesterday")
    }

    func test_relativeDayHeader_arbitraryDateUsesWeekdayFormat() {
        // Pick a date 30 days out — guaranteed not to land on today/tomorrow/yesterday.
        let future = Calendar.current.date(byAdding: .day, value: 30, to: Date())!
        let header = DateFormatting.relativeDayHeader(for: future)
        XCTAssertNotEqual(header, "Today")
        XCTAssertNotEqual(header, "Tomorrow")
        XCTAssertNotEqual(header, "Yesterday")
        XCTAssertTrue(header.contains(","), "Expected EEEE, MMM d format with comma — got \(header)")
    }

    // MARK: - formatter cache

    func test_formatter_returnsSameInstanceForSameFormat() {
        let a = DateFormatting.formatter(for: "HH:mm")
        let b = DateFormatting.formatter(for: "HH:mm")
        XCTAssertTrue(a === b, "Formatter cache should return the same instance for identical patterns")
    }
}
