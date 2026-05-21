import Foundation

struct CityPreset: Identifiable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double
    let flag: String

    var id: String { name }

    static let database: [CityPreset] = [
        CityPreset(name: "Dhaka, Bangladesh", latitude: 23.8103, longitude: 90.4125, flag: "🇧🇩"),
        CityPreset(name: "Mecca, Saudi Arabia", latitude: 21.3891, longitude: 39.8579, flag: "🇸🇦"),
        CityPreset(name: "Medina, Saudi Arabia", latitude: 24.5247, longitude: 39.5692, flag: "🇸🇦"),
        CityPreset(name: "Istanbul, Turkey", latitude: 41.0082, longitude: 28.9784, flag: "🇹🇷"),
        CityPreset(name: "Cairo, Egypt", latitude: 30.0444, longitude: 31.2357, flag: "🇪🇬"),
        CityPreset(name: "Karachi, Pakistan", latitude: 24.8607, longitude: 67.0011, flag: "🇵🇰"),
        CityPreset(name: "Lahore, Pakistan", latitude: 31.5204, longitude: 74.3587, flag: "🇵🇰"),
        CityPreset(name: "Jakarta, Indonesia", latitude: -6.2088, longitude: 106.8456, flag: "🇮🇩"),
        CityPreset(name: "Kuala Lumpur, Malaysia", latitude: 3.1390, longitude: 101.6869, flag: "🇲🇾"),
        CityPreset(name: "Dubai, UAE", latitude: 25.2048, longitude: 55.2708, flag: "🇦🇪"),
        CityPreset(name: "Doha, Qatar", latitude: 25.2854, longitude: 51.5310, flag: "🇶🇦"),
        CityPreset(name: "London, United Kingdom", latitude: 51.5074, longitude: -0.1278, flag: "🇬🇧"),
        CityPreset(name: "New York, United States", latitude: 40.7128, longitude: -74.0060, flag: "🇺🇸"),
        CityPreset(name: "Toronto, Canada", latitude: 43.6532, longitude: -79.3832, flag: "🇨🇦"),
        CityPreset(name: "Sydney, Australia", latitude: -33.8688, longitude: 151.2093, flag: "🇦🇺")
    ]
}
