import XCTest
@testable import Crest

final class PrayerModelsTests: XCTestCase {

    // MARK: - Prayer

    func test_adjustable_excludesSunrise() {
        XCTAssertEqual(Prayer.adjustable, [.fajr, .dhuhr, .asr, .maghrib, .isha])
        XCTAssertFalse(Prayer.adjustable.contains(.sunrise))
    }

    func test_everyPrayer_hasNonEmptyDisplayMetadata() {
        for prayer in Prayer.allCases {
            XCTAssertFalse(prayer.displayName.isEmpty, "displayName missing for \(prayer)")
            XCTAssertFalse(prayer.arabicName.isEmpty, "arabicName missing for \(prayer)")
            XCTAssertFalse(prayer.systemImage.isEmpty, "systemImage missing for \(prayer)")
            XCTAssertEqual(prayer.transliteration, prayer.displayName)
        }
    }

    func test_prayerRawValues_matchAdjustableSettingsKeys() {
        // The per-prayer settings dictionaries in AppSettingsDefault are keyed
        // by the rawValue of each adjustable Prayer. If the rawValue ever drifts,
        // settings persistence silently breaks. Lock that contract here.
        let adjustableKeys = Set(Prayer.adjustable.map(\.rawValue))
        XCTAssertEqual(adjustableKeys, Set(AppSettingsDefault.defaultPrayerAdjustments.keys))
        XCTAssertEqual(adjustableKeys, Set(AppSettingsDefault.defaultJamaatTimes.keys))
    }

    // MARK: - CalculationMethodOption

    func test_calculationMethod_rawValueRoundTrip() {
        for option in CalculationMethodOption.allCases {
            XCTAssertEqual(CalculationMethodOption(rawValue: option.rawValue), option)
            XCTAssertFalse(option.displayName.isEmpty)
        }
    }

    func test_calculationMethod_paramsAreFinite() {
        for option in CalculationMethodOption.allCases {
            let params = option.adhanMethod.params
            XCTAssertTrue(params.fajrAngle.isFinite, "fajrAngle non-finite for \(option)")
            XCTAssertTrue(params.ishaAngle.isFinite, "ishaAngle non-finite for \(option)")
        }
    }

    // MARK: - MadhabOption

    func test_madhab_distinctMappings() {
        XCTAssertNotEqual(MadhabOption.shafi.adhanMadhab, MadhabOption.hanafi.adhanMadhab)
    }

    // MARK: - ShafaqOption

    func test_shafaq_distinctMappings() {
        let mapped = Set(ShafaqOption.allCases.map { String(describing: $0.adhanShafaq) })
        XCTAssertEqual(mapped.count, ShafaqOption.allCases.count, "Each ShafaqOption must map to a distinct adhanShafaq")
    }
}
