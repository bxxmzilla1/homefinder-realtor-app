import Foundation

struct SearchFilters: Equatable {
    enum Transaction: String, CaseIterable, Identifiable {
        case sale, lease
        var id: String { rawValue }
        var label: String { self == .sale ? "For sale" : "For rent" }
    }

    enum PropertyClass: String, CaseIterable, Identifiable {
        case any = "", residential, condo, commercial
        var id: String { rawValue }
        var label: String {
            switch self {
            case .any: return "Any"
            case .residential: return "Residential"
            case .condo: return "Condo"
            case .commercial: return "Commercial"
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case newest = "createdOnDesc"
        case priceLow = "listPriceAsc"
        case priceHigh = "listPriceDesc"
        case updated = "updatedOnDesc"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .newest: return "Newest"
            case .priceLow: return "Lowest price"
            case .priceHigh: return "Highest price"
            case .updated: return "Recently updated"
            }
        }
    }

    static let salePrices: [Int] = [
        100_000, 200_000, 300_000, 400_000, 500_000, 600_000, 700_000, 800_000,
        900_000, 1_000_000, 1_250_000, 1_500_000, 2_000_000, 3_000_000, 5_000_000, 10_000_000,
    ]
    static let leasePrices: [Int] = [
        500, 1_000, 1_500, 2_000, 2_500, 3_000, 3_500, 4_000, 5_000, 7_500, 10_000,
    ]

    var transaction: Transaction = .sale
    var propertyClass: PropertyClass = .any
    var minPrice: Int?
    var maxPrice: Int?
    var minBeds = 0
    var minBaths = 0
    var keywords = ""
    var sort: Sort = .newest

    var priceOptions: [Int] {
        transaction == .sale ? Self.salePrices : Self.leasePrices
    }

    var activeCount: Int {
        var n = 0
        if propertyClass != .any { n += 1 }
        if minPrice != nil { n += 1 }
        if maxPrice != nil { n += 1 }
        if minBeds > 0 { n += 1 }
        if minBaths > 0 { n += 1 }
        if !keywords.trimmingCharacters(in: .whitespaces).isEmpty { n += 1 }
        return n
    }

    var queryItems: [String: String] {
        var q: [String: String] = [
            "status": "A",
            "type": transaction.rawValue,
            "sortBy": sort.rawValue,
        ]
        if propertyClass != .any { q["class"] = propertyClass.rawValue }
        if let minPrice { q["minPrice"] = String(minPrice) }
        if let maxPrice { q["maxPrice"] = String(maxPrice) }
        if minBeds > 0 { q["minBedrooms"] = String(minBeds) }
        if minBaths > 0 { q["minBaths"] = String(minBaths) }
        let trimmed = keywords.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { q["search"] = trimmed }
        return q
    }
}
