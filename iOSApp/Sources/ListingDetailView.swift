import MapKit
import SwiftUI

struct ListingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var listing: Listing
    @State private var loadError: String?
    @State private var isLoading = true

    init(listing: Listing) {
        _listing = State(initialValue: listing)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PhotoCarousel(photos: listing.photos)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Format.price(listing.price, lease: listing.isLease))
                                .font(.system(size: 28, weight: .bold))
                            Spacer()
                            Text(listing.isLease ? "For rent" : "For sale")
                                .font(.caption.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(listing.isLease ? Brand.lease : Brand.red), in: Capsule())
                                .foregroundColor(.white)
                        }
                        if let original = listing.originalPrice, let price = listing.price,
                           original > 0, original != price {
                            Text("Originally \(Format.price(original, lease: listing.isLease))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text(listing.addressFull ?? "Address unavailable")
                            .font(.headline)
                        if let neighborhood = listing.neighborhood, !neighborhood.isEmpty {
                            Text(neighborhood).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    facts
                        .padding(.horizontal)

                    if let coordinate = listing.coordinate {
                        VStack(alignment: .leading, spacing: 10) {
                            MiniMap(coordinate: coordinate)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            HStack(spacing: 10) {
                                actionButton("Directions", icon: "car.fill") { openDirections(to: coordinate) }
                                actionButton("Open in Maps", icon: "map.fill") { openInMaps(coordinate) }
                            }
                        }
                        .padding(.horizontal)
                    }

                    if let text = listing.description, !text.isEmpty {
                        section("Description") {
                            Text(text).font(.body)
                        }
                    }

                    if listing.agentName != nil || listing.agentBrokerage != nil {
                        section("Listed by") {
                            VStack(alignment: .leading, spacing: 2) {
                                if let name = listing.agentName { Text(name).font(.body.bold()) }
                                if let brokerage = listing.agentBrokerage {
                                    Text(brokerage).foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    if isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if let loadError {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }

                    Text("MLS® \(listing.mlsNumber)")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle(Format.shortPrice(listing.price))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadDetails() }
        }
        .navigationViewStyle(.stack)
    }

    private struct Fact: Identifiable {
        let icon: String
        let label: String
        let value: String?
        var id: String { label }
    }

    private var facts: some View {
        let all: [Fact] = [
            Fact(icon: "bed.double.fill", label: "Beds", value: listing.bedsText),
            Fact(icon: "shower.fill", label: "Baths", value: listing.baths.map { Format.number($0) }),
            Fact(icon: "ruler.fill", label: "Sq ft", value: listing.sqftText),
            Fact(icon: "house.fill", label: "Type", value: listing.propertyType),
            Fact(icon: "building.2.fill", label: "Style", value: listing.style),
        ]
        let items = all.filter { !($0.value ?? "").isEmpty }

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
            ForEach(items) { fact in
                VStack(spacing: 4) {
                    Image(systemName: fact.icon).foregroundColor(Color(Brand.red))
                    Text(fact.value ?? "").font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
                    Text(fact.label).font(.caption).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold())
            content()
        }
        .padding(.horizontal)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color(Brand.red), in: RoundedRectangle(cornerRadius: 10))
                .foregroundColor(.white)
        }
    }

    private func mapItem(_ coordinate: CLLocationCoordinate2D) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = listing.addressStreet ?? listing.addressFull
        return item
    }

    private func openDirections(to coordinate: CLLocationCoordinate2D) {
        mapItem(coordinate).openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
        ])
    }

    private func openInMaps(_ coordinate: CLLocationCoordinate2D) {
        mapItem(coordinate).openInMaps(launchOptions: [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: coordinate),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)),
        ])
    }

    private func loadDetails() async {
        defer { isLoading = false }
        do {
            listing = try await APIClient.shared.listing(
                mlsNumber: listing.mlsNumber,
                boardId: listing.boardId?.value
            )
            loadError = nil
        } catch is CancellationError {
        } catch {
            loadError = "Couldn't load full details: \(error.localizedDescription)"
        }
    }
}

private struct PhotoCarousel: View {
    let photos: [URL]
    @State private var index = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if photos.isEmpty {
                RemoteImage(url: nil)
            } else {
                TabView(selection: $index) {
                    ForEach(Array(photos.enumerated()), id: \.offset) { offset, url in
                        RemoteImage(url: url).tag(offset)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Text("\(index + 1) / \(photos.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.55), in: Capsule())
                    .foregroundColor(.white)
                    .padding(10)
            }
        }
        .frame(height: 280)
        .clipped()
    }
}

private struct MiniMap: View {
    struct Pin: Identifiable {
        let id = 0
        let coordinate: CLLocationCoordinate2D
    }

    let coordinate: CLLocationCoordinate2D
    @State private var region: MKCoordinateRegion

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        _region = State(initialValue: MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [Pin(coordinate: coordinate)]) { pin in
            MapMarker(coordinate: pin.coordinate, tint: Color(Brand.red))
        }
        .disabled(true)
    }
}
