import XCTest
@testable import Crest

final class DateFormatOptionTests: XCTestCase {

    func test_allCases_haveDistinctRawValues() {
        let raws = DateFormatOption.allCases.map(\.rawValue)
        XCTAssertEqual(Set(raws).count, raws.count, "DateFormatOption rawValues must be unique")
    }

    func test_allCases_haveNonEmptyDisplayName() {
        for option in DateFormatOption.allCases {
            XCTAssertFalse(option.displayName.isEmpty, "displayName missing for \(option)")
        }
    }

    func test_eachRawValue_isUsableDateFormatterPattern() {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 4; comps.day = 4
        comps.hour = 12; comps.minute = 30; comps.second = 45
        let date = Calendar.current.date(from: comps)!

        for option in DateFormatOption.allCases {
            let formatter = DateFormatter()
            formatter.dateFormat = option.rawValue
            let output = formatter.string(from: date)
            XCTAssertFalse(output.isEmpty, "\(option) produced empty string from valid pattern \(option.rawValue)")
        }
    }

    func test_defaultDateFormat_isValidOption() {
        XCTAssertNotNil(DateFormatOption(rawValue: AppSettingsDefault.dateFormat))
    }
}
