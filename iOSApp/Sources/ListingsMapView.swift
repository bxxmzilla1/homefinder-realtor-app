import MapKit
import SwiftUI

enum Brand {
    static let red = UIColor(red: 0.80, green: 0.10, blue: 0.16, alpha: 1)
    static let lease = UIColor(red: 0.18, green: 0.38, blue: 0.80, alpha: 1)
}

final class ListingAnnotation: NSObject, MKAnnotation {
    let listing: Listing
    let coordinate: CLLocationCoordinate2D

    init?(listing: Listing) {
        guard let coordinate = listing.coordinate else { return nil }
        self.listing = listing
        self.coordinate = coordinate
    }

    var title: String? { Format.shortPrice(listing.price) }
}

struct ListingsMapView: UIViewRepresentable {
    let listings: [Listing]
    let focus: MapFocus
    let onRegionChange: (MKCoordinateRegion) -> Void
    let onSelect: (Listing) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.showsCompass = true
        map.pointOfInterestFilter = .excludingAll
        map.register(PriceAnnotationView.self, forAnnotationViewWithReuseIdentifier: PriceAnnotationView.reuseID)
        map.register(ClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: ClusterAnnotationView.reuseID)
        map.setRegion(focus.region, animated: false)
        context.coordinator.lastFocusID = focus.id
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self

        if focus.id != context.coordinator.lastFocusID {
            context.coordinator.lastFocusID = focus.id
            map.setRegion(focus.region, animated: true)
        }

        let current = map.annotations.compactMap { $0 as? ListingAnnotation }
        let newIDs = Set(listings.map(\.id))
        let currentIDs = Set(current.map(\.listing.id))

        let stale = current.filter { !newIDs.contains($0.listing.id) }
        if !stale.isEmpty { map.removeAnnotations(stale) }

        let added = listings
            .filter { !currentIDs.contains($0.id) }
            .compactMap(ListingAnnotation.init(listing:))
        if !added.isEmpty { map.addAnnotations(added) }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ListingsMapView
        var lastFocusID: UUID?

        init(parent: ListingsMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            DispatchQueue.main.async { self.parent.onRegionChange(region) }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let listing = annotation as? ListingAnnotation {
                return mapView.dequeueReusableAnnotationView(withIdentifier: PriceAnnotationView.reuseID, for: listing)
            }
            if let cluster = annotation as? MKClusterAnnotation {
                return mapView.dequeueReusableAnnotationView(withIdentifier: ClusterAnnotationView.reuseID, for: cluster)
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let annotation = view.annotation as? ListingAnnotation {
                mapView.deselectAnnotation(annotation, animated: false)
                let listing = annotation.listing
                DispatchQueue.main.async { self.parent.onSelect(listing) }
            } else if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                mapView.showAnnotations(cluster.memberAnnotations, animated: true)
            }
        }
    }
}

final class PriceAnnotationView: MKAnnotationView {
    static let reuseID = "PriceAnnotationView"
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "listing"
        collisionMode = .rectangle
        displayPriority = .defaultHigh
        canShowCallout = false

        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.cornerRadius = 11
        label.layer.masksToBounds = true
        label.layer.borderColor = UIColor.white.cgColor
        label.layer.borderWidth = 1.5
        addSubview(label)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        clusteringIdentifier = "listing"
        configure()
    }

    private func configure() {
        guard let annotation = annotation as? ListingAnnotation else { return }
        label.text = Format.shortPrice(annotation.listing.price)
        label.backgroundColor = annotation.listing.isLease ? Brand.lease : Brand.red
        let width = ceil(label.intrinsicContentSize.width) + 16
        let height: CGFloat = 22
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
        label.frame = bounds
        centerOffset = CGPoint(x: 0, y: -height / 2)
    }
}

final class ClusterAnnotationView: MKAnnotationView {
    static let reuseID = "ClusterAnnotationView"
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        displayPriority = .defaultHigh
        canShowCallout = false

        label.font = .systemFont(ofSize: 13, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        label.layer.masksToBounds = true
        label.layer.borderColor = UIColor.white.cgColor
        label.layer.borderWidth = 2
        label.backgroundColor = Brand.red
        addSubview(label)

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 3
        layer.shadowOffset = CGSize(width: 0, height: 1)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        configure()
    }

    private func configure() {
        guard let cluster = annotation as? MKClusterAnnotation else { return }
        let count = cluster.memberAnnotations.count
        label.text = count > 999 ? "999+" : "\(count)"
        let size: CGFloat = count < 10 ? 32 : (count < 100 ? 38 : 46)
        bounds = CGRect(x: 0, y: 0, width: size, height: size)
        label.frame = bounds
        label.layer.cornerRadius = size / 2
    }
}
