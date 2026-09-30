import Foundation
import CoreLocation

/// Decodes a JSON string, number or bool into a string (the API mixes types for some fields).
struct FlexibleString: Codable, Hashable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            value = s
        } else if let i = try? container.decode(Int.self) {
            value = String(i)
        } else if let d = try? container.decode(Double.self) {
            value = String(d)
        } else if let b = try? container.decode(Bool.self) {
            value = String(b)
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct Listing: Codable, Identifiable, Hashable {
    var id: String { mlsNumber }

    let mlsNumber: String
    let boardId: FlexibleString?
    let status: String?
    let transactionType: String?
    let price: Double?
    let originalPrice: Double?
    let listDate: String?
    let addressStreet: String?
    let addressFull: String?
    let city: String?
    let area: String?
    let neighborhood: String?
    let postalCode: String?
    let province: String?
    let lat: Double?
    let lon: Double?
    let propertyType: String?
    let style: String?
    let beds: Double?
    let bedsPlus: Double?
    let baths: Double?
    let sqft: FlexibleString?
    let description: String?
    let photoUrl: String?
    let photoUrls: [String]?
    let agentName: String?
    let agentBrokerage: String?

    var coordinate: CLLocationCoordinate2D? {
        guard let lat, let lon, lat != 0 || lon != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var isLease: Bool {
        transactionType?.lowercased() == "lease"
    }

    var photos: [URL] {
        (photoUrls ?? [photoUrl].compactMap { $0 }).compactMap(URL.init(string:))
    }

    var bedsText: String? {
        guard let beds else { return nil }
        let base = Format.number(beds)
        if let plus = bedsPlus, plus > 0 { return "\(base) + \(Format.number(plus))" }
        return base
    }

    var sqftText: String? {
        guard let value = sqft?.value, !value.isEmpty else { return nil }
        return value
    }
}

struct Paging: Codable, Hashable {
    let page: Int?
    let pageSize: Int?
    let totalPages: Int?
    let totalRecords: Int?
}

struct SearchResponse: Codable {
    let paging: Paging
    let results: [Listing]
}

struct LocationSuggestion: Codable, Identifiable, Hashable {
    struct Point: Codable, Hashable {
        let latitude: FlexibleString?
        let longitude: FlexibleString?
    }

    struct Address: Codable, Hashable {
        let city: String?
        let state: String?
        let area: String?
        let neighborhood: String?
    }

    let locationId: String?
    let name: String
    let type: String?
    let map: Point?
    let address: Address?

    var id: String { locationId ?? "\(name)-\(type ?? "")" }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = map?.latitude.flatMap({ Double($0.value) }),
              let lon = map?.longitude.flatMap({ Double($0.value) }) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var subtitle: String {
        var parts: [String] = []
        if let type { parts.append(type.capitalized) }
        if let city = address?.city, !city.isEmpty, city != name { parts.append(city) }
        if let state = address?.state, !state.isEmpty { parts.append(state) }
        return parts.joined(separator: " · ")
    }

    /// Map span (in degrees) that fits this kind of place.
    var span: Double {
        switch type?.lowercased() {
        case "neighborhood": return 0.05
        case "area": return 0.6
        default: return 0.25
        }
    }
}

struct LocationsResponse: Codable {
    let locations: [LocationSuggestion]?
}

enum Format {
    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 0
        return f
    }()

    static func price(_ value: Double?, lease: Bool = false) -> String {
        guard let value, value > 0 else { return "Price on request" }
        let text = currency.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
        return lease ? "\(text)/mo" : text
    }

    static func shortPrice(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        if value >= 1_000_000 {
            let m = value / 1_000_000
            return m >= 10 ? "$\(Int(m.rounded()))M" : String(format: "$%.1fM", m)
        }
        if value >= 1_000 { return "$\(Int((value / 1_000).rounded()))K" }
        return "$\(Int(value))"
    }

    static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    static func count(_ value: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
    }
}
