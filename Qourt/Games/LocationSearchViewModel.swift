//
//  LocationSearchViewModel.swift
//  Qourt
//

import CoreLocation
import MapKit

/// Backs the Location field's autocomplete when creating a game. Uses
/// MapKit's on-device completer against real Apple Maps data, biased
/// toward the admin's current location — not Foundation Models, which has
/// no access to live place data and would risk inventing venues.
@Observable
final class LocationSearchViewModel: NSObject {
    var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        completer.resultTypes = [.pointOfInterest, .address]
        completer.delegate = self
        locationManager.delegate = self
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        if let location = locationManager.location {
            completer.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
    }

    func updateQuery(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = []
            return
        }
        completer.queryFragment = text
    }

    func clearSuggestions() {
        suggestions = []
    }
}

extension LocationSearchViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in self.suggestions = completer.results }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in self.suggestions = [] }
    }
}

extension LocationSearchViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.completer.region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No location access — completer just falls back to non-proximity-biased results.
    }
}
