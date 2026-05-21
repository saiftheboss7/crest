import XCTest
import CoreLocation
@testable import Crest

/// Regression coverage for the location-fetch flow.
///
/// On macOS, the only authorized status is `.authorizedAlways` — `.authorizedWhenInUse`
/// is iOS-only at the enum level (even though `requestWhenInUseAuthorization()` is
/// callable on macOS 11+ and just maps to Always). These tests pin the authorization
/// mapping and the cached-coordinate behavior so future refactors can't silently break
/// the popover's prayer schedule for users on automatic location.
@MainActor
final class LocationServiceTests: XCTestCase {

    private var savedKeys: [(key: String, value: Any?)] = []

    override func setUp() async throws {
        savedKeys = []
        let defaults = UserDefaults.standard

        let mutating = [
            AppSettingsKey.cachedLatitude,
            AppSettingsKey.cachedLongitude,
            AppSettingsKey.islamicModeEnabled,
            AppSettingsKey.staticLocationEnabled,
            AppSettingsKey.staticLatitude,
            AppSettingsKey.staticLongitude,
            AppSettingsKey.calculationMethod,
            AppSettingsKey.madhab,
            AppSettingsKey.shafaq,
            AppSettingsKey.jamaatTimesEnabled,
            AppSettingsKey.hijriDateOffset,
            "cachedCityName",
        ]
        for key in mutating {
            savedKeys.append((key, defaults.object(forKey: key)))
        }
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

    // MARK: - canRequestLiveLocation

    /// On macOS, granted Location Services access resolves to `.authorizedAlways`.
    func test_canRequestLiveLocation_acceptsAuthorizedAlways() {
        XCTAssertTrue(LocationService.canRequestLiveLocation(for: .authorizedAlways))
    }

    func test_canRequestLiveLocation_rejectsUnauthorizedStates() {
        XCTAssertFalse(LocationService.canRequestLiveLocation(for: .notDetermined))
        XCTAssertFalse(LocationService.canRequestLiveLocation(for: .denied))
        XCTAssertFalse(LocationService.canRequestLiveLocation(for: .restricted))
    }

    // MARK: - statusDescription

    func test_statusDescription_authorizedStateReportsAuthorized() {
        XCTAssertEqual(LocationService.statusDescription(for: .authorizedAlways), "Authorized")
    }

    func test_statusDescription_unauthorizedStates() {
        XCTAssertEqual(LocationService.statusDescription(for: .denied), "Denied")
        XCTAssertEqual(LocationService.statusDescription(for: .restricted), "Restricted")
        XCTAssertEqual(LocationService.statusDescription(for: .notDetermined), "Not Determined")
    }

    // MARK: - Coordinate persistence

    func test_init_loadsCachedCoordinatesFromUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(23.8103, forKey: AppSettingsKey.cachedLatitude)
        defaults.set(90.4125, forKey: AppSettingsKey.cachedLongitude)
        defaults.set("Dhaka", forKey: "cachedCityName")

        let service = LocationService()

        XCTAssertEqual(service.latitude ?? 0, 23.8103, accuracy: 0.0001)
        XCTAssertEqual(service.longitude ?? 0, 90.4125, accuracy: 0.0001)
        XCTAssertEqual(service.cityName, "Dhaka")
        XCTAssertNotNil(service.coordinates, "Coordinates should be derivable from cached lat/lon")
    }

    func test_init_withoutCachedCoordinates_yieldsNilCoordinates() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AppSettingsKey.cachedLatitude)
        defaults.removeObject(forKey: AppSettingsKey.cachedLongitude)

        let service = LocationService()

        XCTAssertNil(service.coordinates)
    }

    // MARK: - End-to-end: PrayerTimeService uses live coordinates

    /// The whole point of the location service is that turning Islamic Mode on
    /// (without enabling static location) should yield a computable prayer schedule
    /// once coordinates are available. This test primes the cache so we can verify
    /// the automatic path without going through CoreLocation.
    func test_prayerTimeService_computesScheduleFromLiveLocationCoordinates() {
        let defaults = UserDefaults.standard
        defaults.set(23.8103, forKey: AppSettingsKey.cachedLatitude)
        defaults.set(90.4125, forKey: AppSettingsKey.cachedLongitude)
        defaults.set(true, forKey: AppSettingsKey.islamicModeEnabled)
        defaults.set(false, forKey: AppSettingsKey.staticLocationEnabled)
        defaults.set("moonsightingCommittee", forKey: AppSettingsKey.calculationMethod)
        defaults.set("shafi", forKey: AppSettingsKey.madhab)
        defaults.set("general", forKey: AppSettingsKey.shafaq)
        defaults.set(false, forKey: AppSettingsKey.jamaatTimesEnabled)
        defaults.set(0, forKey: AppSettingsKey.hijriDateOffset)

        let location = LocationService()
        let prayer = PrayerTimeService(locationService: location)
        prayer.recompute()

        XCTAssertEqual(
            prayer.todayPrayers.count, 6,
            "Automatic location path must produce a full 6-entry schedule when coordinates are available"
        )
    }
}
