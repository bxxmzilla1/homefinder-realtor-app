import Foundation
import MapKit

struct MapFocus: Equatable {
    let id = UUID()
    let region: MKCoordinateRegion

    static func == (lhs: MapFocus, rhs: MapFocus) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class ListingsViewModel: ObservableObject {
    static let maxPins = 200

    @Published private(set) var listings: [Listing] = []
    @Published private(set) var totalInArea = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var suggestions: [LocationSuggestion] = []
    @Published var focus: MapFocus
    @Published var filters = SearchFilters() {
        didSet { if filters != oldValue { scheduleLoad(delay: 0) } }
    }

    private var region: MKCoordinateRegion?
    private var loadTask: Task<Void, Never>?
    private var suggestTask: Task<Void, Never>?

    init() {
        focus = MapFocus(region: Self.savedRegion() ?? Self.defaultRegion)
    }

    // MARK: Map area

    func regionChanged(_ newRegion: MKCoordinateRegion) {
        region = newRegion
        Self.save(newRegion)
        scheduleLoad(delay: 0.35)
    }

    func reload() {
        scheduleLoad(delay: 0)
    }

    func move(to coordinate: CLLocationCoordinate2D, span: Double) {
        focus = MapFocus(region: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        ))
    }

    private func scheduleLoad(delay: Double) {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await self?.load()
        }
    }

    private func load() async {
        guard let region else { return }
        guard AppSettings.shared.isConfigured else {
            errorMessage = "Add your server address and API key in Settings."
            return
        }

        var query = filters.queryItems
        query["map"] = Self.polygon(for: region)
        query["resultsPerPage"] = String(Self.maxPins)
        query["fields"] = "mlsNumber,boardId,listPrice,type,class,map,address,details,images[1]"

        isLoading = true
        do {
            let response = try await APIClient.shared.search(query)
            guard !Task.isCancelled else { return }
            listings = response.results.filter { $0.coordinate != nil }
            totalInArea = response.paging.totalRecords ?? listings.count
            errorMessage = nil
            isLoading = false
        } catch is CancellationError {
            // A newer request replaced this one.
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// GeoJSON polygon ([[[lng, lat], ...]]) covering the visible map region.
    static func polygon(for region: MKCoordinateRegion) -> String {
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        let minLat = max(-85, region.center.latitude - halfLat)
        let maxLat = min(85, region.center.latitude + halfLat)
        let minLon = max(-180, region.center.longitude - halfLon)
        let maxLon = min(180, region.center.longitude + halfLon)
        func p(_ lon: Double, _ lat: Double) -> String {
            String(format: "[%.6f,%.6f]", lon, lat)
        }
        let ring = [
            p(minLon, minLat), p(maxLon, minLat), p(maxLon, maxLat), p(minLon, maxLat), p(minLon, minLat),
        ]
        return "[[\(ring.joined(separator: ","))]]"
    }

    // MARK: Location search

    func updateSuggestions(for text: String) {
        suggestTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        suggestTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            do {
                let results = try await APIClient.shared.autocomplete(trimmed)
                guard !Task.isCancelled else { return }
                self?.suggestions = results.filter { $0.coordinate != nil }
            } catch {
                guard !Task.isCancelled else { return }
                self?.suggestions = []
            }
        }
    }

    func select(_ suggestion: LocationSuggestion) {
        suggestions = []
        suggestTask?.cancel()
        if let coordinate = suggestion.coordinate {
            move(to: coordinate, span: suggestion.span)
        }
    }

    // MARK: Persistence

    // Most of the Repliers sample data is around Charlotte, NC.
    static let defaultRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.2271, longitude: -80.8431),
        span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
    )

    private static func save(_ region: MKCoordinateRegion) {
        UserDefaults.standard.set(
            [region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta],
            forKey: "lastRegion"
        )
    }

    private static func savedRegion() -> MKCoordinateRegion? {
        guard let v = UserDefaults.standard.array(forKey: "lastRegion") as? [Double], v.count == 4 else {
            return nil
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: v[0], longitude: v[1]),
            span: MKCoordinateSpan(latitudeDelta: v[2], longitudeDelta: v[3])
        )
    }
}
