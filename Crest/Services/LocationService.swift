import Foundation
import CoreLocation
import CoreWLAN
import Observation
import Adhan
import AppKit

extension Notification.Name {
    static let locationDidUpdate = Notification.Name("locationDidUpdate")
    static let prayerTimesDidRecompute = Notification.Name("prayerTimesDidRecompute")
}

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var cityName: String?
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Last user-facing failure surfaced by the delegate. Drives the inline
    /// error message in `IslamicSettingsView` when an automatic fetch fails.
    private(set) var lastError: String?
    /// True while a `startUpdatingLocation()` is outstanding. Drives the spinner
    /// in the settings UI and stops us from stacking concurrent requests.
    private(set) var isFetching: Bool = false
    private var updateTimer: Timer?
    /// Backstop that flips the UI out of the "fetching" state if CoreLocation
    /// never delivers a fix. Reset whenever a transient `kCLErrorLocationUnknown`
    /// fires so a slow but progressing fetch isn't cut short.
    private var watchdogTask: Task<Void, Never>?
    private let watchdogSeconds: Double = 45

    var coordinates: Coordinates? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return Coordinates(latitude: lat, longitude: lon)
    }

    var statusDescription: String {
        Self.statusDescription(for: authorizationStatus)
    }

    var canRequestLiveLocation: Bool {
        Self.canRequestLiveLocation(for: authorizationStatus)
    }

    var needsSettingsAction: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Macs have no GPS. CoreLocation relies on Wi-Fi BSSID scanning to determine
    /// position — without Wi-Fi powered on, `startUpdatingLocation` returns
    /// `kCLErrorLocationUnknown` indefinitely. CoreWLAN gives us a definitive
    /// answer about Wi-Fi state without any entitlement.
    var isWiFiOn: Bool {
        guard let interface = CWWiFiClient.shared().interface() else {
            return false // No Wi-Fi hardware at all — also a deal-breaker
        }
        return interface.powerOn()
    }

    /// On macOS, granted Location Services access resolves to `.authorizedAlways` (the
    /// `.authorizedWhenInUse` case is iOS-only). Exposed as a static helper so the
    /// authorization mapping can be unit-tested without spinning up CoreLocation.
    /// `nonisolated` because `CLLocationManagerDelegate` callbacks are nonisolated
    /// and need to call these from outside the main actor.
    nonisolated static func canRequestLiveLocation(for status: CLAuthorizationStatus) -> Bool {
        status == .authorizedAlways
    }

    nonisolated static func statusDescription(for status: CLAuthorizationStatus) -> String {
        switch status {
        case .authorizedAlways: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    var permissionHelpText: String {
        switch authorizationStatus {
        case .denied:
            return "Location access is off. Enable Location Services for Crest in System Settings, then try again."
        case .restricted:
            return "Location access is restricted on this Mac. Update your privacy restrictions, then try again."
        case .notDetermined:
            return "Allow location access to calculate accurate prayer times, or use a static location below."
        default:
            return ""
        }
    }

    override init() {
        super.init()
        manager.delegate = self
        // macOS Wi-Fi positioning sometimes silently ignores the kilometer
        // accuracy ceiling — `hundredMeters` is the next step up and is widely
        // supported. Prayer-time calculation doesn't need anything tighter.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus

        loadCachedCoordinates()
        setupFrequencyTimer()

        // If the user has previously granted access, kick off an immediate fetch
        // so we don't wait up to 6h for the frequency timer to refresh coords.
        // Deferred to the next run-loop tick — calling location methods from
        // inside CLLocationManager's own init frame can drop requests on macOS.
        if Self.canRequestLiveLocation(for: authorizationStatus) {
            DispatchQueue.main.async { [weak self] in
                self?.performLocationRequest()
            }
        }
    }

    /// Public entry point. Either prompts for permission, or kicks off a fetch.
    /// Safe to call repeatedly — the underlying request is idempotent.
    func requestLocation() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            // `LSUIElement = true` apps don't get a Dock icon, so the system
            // permission prompt can fail to surface unless we explicitly
            // activate the app first.
            NSApp.activate(ignoringOtherApps: true)
            manager.requestWhenInUseAuthorization()
        } else if Self.canRequestLiveLocation(for: status) {
            performLocationRequest()
        }
    }

    /// Manual one-shot via `startUpdatingLocation()` — we stop the manager from
    /// inside `didUpdateLocations` after the first fix.
    private func performLocationRequest() {
        guard !isFetching else { return }

        // Macs have no GPS. If Wi-Fi is off there's no possible signal source —
        // CoreLocation will spin on `kCLErrorLocationUnknown` for 45s and then
        // give up. Short-circuit with a clear, actionable message instead.
        guard isWiFiOn else {
            lastError = "Wi-Fi is off. Macs determine location via Wi-Fi — there is no GPS. Switch to Manual mode below to pick your city, or turn Wi-Fi on."
            isFetching = false
            return
        }

        lastError = nil
        isFetching = true

        // If CoreLocation already has a cached fix from this session, use it.
        if let cached = manager.location {
            // Drive the same delegate path as a fresh fix so all our state
            // (caching, geocoding, notifications, UI) updates uniformly.
            self.locationManager(manager, didUpdateLocations: [cached])
            return
        }

        manager.startUpdatingLocation()
        scheduleWatchdog()
    }

    /// Flips the UI out of "fetching" if CoreLocation never delivers a fix.
    /// Reset whenever a transient `kCLErrorLocationUnknown` fires.
    private func scheduleWatchdog() {
        watchdogTask?.cancel()
        let timeout = watchdogSeconds
        watchdogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            if self.isFetching {
                self.isFetching = false
                self.lastError = "Couldn't determine location after \(Int(timeout))s. Make sure Wi-Fi is on — macOS uses Wi-Fi to determine location."
                self.manager.stopUpdatingLocation()
            }
        }
    }

    func openLocationPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func setupFrequencyTimer() {
        updateTimer?.invalidate()
        updateTimer = nil

        let frequencyStr = UserDefaults.standard.string(forKey: "locationUpdateFrequency") ?? "6h"
        let interval: TimeInterval
        switch frequencyStr {
        case "6h":
            interval = 6 * 3600
        case "12h":
            interval = 12 * 3600
        case "24h":
            interval = 24 * 3600
        default:
            interval = 6 * 3600
        }

        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                let defaults = UserDefaults.standard
                let staticEnabled = defaults.bool(forKey: AppSettingsKey.staticLocationEnabled)
                let islamicEnabled = defaults.bool(forKey: AppSettingsKey.islamicModeEnabled)
                if islamicEnabled && !staticEnabled && Self.canRequestLiveLocation(for: self.authorizationStatus) {
                    self.performLocationRequest()
                }
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        Task { @MainActor in
            self.latitude = lat
            self.longitude = lon
            self.lastError = nil
            self.isFetching = false
            self.watchdogTask?.cancel()
            self.watchdogTask = nil
            self.cacheCoordinates()
            // Manual one-shot: stop the continuous update stream now that we
            // have a fix. Saves battery and ends the locationd subscription.
            self.manager.stopUpdatingLocation()

            NotificationCenter.default.post(name: .locationDidUpdate, object: nil)

            CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
                if let city = placemarks?.first?.locality {
                    Task { @MainActor in
                        self.cityName = city
                        UserDefaults.standard.set(city, forKey: "cachedCityName")
                        // Post again to make sure city name is picked up in views
                        NotificationCenter.default.post(name: .locationDidUpdate, object: nil)
                    }
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        let code = nsError.code
        let message = error.localizedDescription

        Task { @MainActor in
            if code == CLError.Code.locationUnknown.rawValue {
                // Per Apple docs: with `startUpdatingLocation()`, this error is
                // **transient** — the manager keeps running internally and will
                // fire `didUpdateLocations` once it finds a fix. Do NOT restart
                // the manager (that resets its progress) — just reset the
                // watchdog so it has time to settle.
                self.lastError = "Searching…"
                self.scheduleWatchdog()
            } else if code == CLError.Code.denied.rawValue {
                // Authorization revoked at the OS level mid-flight.
                self.lastError = "Access denied. Re-grant in System Settings → Privacy & Security → Location Services."
                self.isFetching = false
                self.watchdogTask?.cancel()
                self.watchdogTask = nil
                self.manager.stopUpdatingLocation()
            } else {
                self.lastError = message
                self.isFetching = false
                self.watchdogTask?.cancel()
                self.watchdogTask = nil
                self.manager.stopUpdatingLocation()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if Self.canRequestLiveLocation(for: status) {
                self.performLocationRequest()
            }
        }
    }

    // MARK: - Cache

    private func cacheCoordinates() {
        guard let lat = latitude, let lon = longitude else { return }
        UserDefaults.standard.set(lat, forKey: AppSettingsKey.cachedLatitude)
        UserDefaults.standard.set(lon, forKey: AppSettingsKey.cachedLongitude)
    }

    private func loadCachedCoordinates() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: AppSettingsKey.cachedLatitude) != nil {
            latitude = defaults.double(forKey: AppSettingsKey.cachedLatitude)
            longitude = defaults.double(forKey: AppSettingsKey.cachedLongitude)
        }
        cityName = defaults.string(forKey: "cachedCityName")
    }
}
