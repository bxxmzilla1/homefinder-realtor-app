import CoreLocation

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var wantsLocation = false
    var onLocation: ((CLLocationCoordinate2D) -> Void)?
    @Published var deniedMessage: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        wantsLocation = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            deniedMessage = "Location access is off. Enable it in Settings > HomeFinder."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard wantsLocation else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            DispatchQueue.main.async { self.deniedMessage = "Location access is off. Enable it in Settings > HomeFinder." }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard wantsLocation, let coordinate = locations.last?.coordinate else { return }
        wantsLocation = false
        DispatchQueue.main.async { self.onLocation?(coordinate) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        wantsLocation = false
    }
}
