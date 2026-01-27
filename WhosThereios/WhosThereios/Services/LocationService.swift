//
//  LocationService.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isMonitoring = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private var monitoredGroups: [String: LocationGroup] = [:]

    var onEnterRegion: ((String) -> Void)?
    var onExitRegion: ((String) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestAuthorization() {
        // iOS requires requesting "When In Use" first, then "Always" after user grants it
        switch authorizationStatus {
        case .notDetermined:
            // First, request When In Use
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // If we have When In Use, we can request Always
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .denied, .restricted:
            // Already have a definitive status
            break
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    /// Request upgrade from "When In Use" to "Always" permission
    func requestAlwaysAuthorization() {
        if authorizationStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func startMonitoringGroups(_ groups: [LocationGroup]) {
        // Geofence monitoring requires "Always" authorization
        // Without it, we skip region monitoring (users will need to check in manually)
        guard authorizationStatus == .authorizedAlways else {
            print("Skipping geofence monitoring - requires 'Always' location permission")
            isMonitoring = false
            return
        }

        // iOS limits monitoring to 20 regions
        // Sort by distance and monitor the nearest ones
        guard let currentLoc = currentLocation else {
            // Start location updates first if we don't have location
            startUpdatingLocation()
            return
        }

        // Stop monitoring all current regions
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredGroups.removeAll()

        // Sort groups by distance from current location
        let sortedGroups = groups.sorted { group1, group2 in
            let loc1 = CLLocation(latitude: group1.centerLatitude, longitude: group1.centerLongitude)
            let loc2 = CLLocation(latitude: group2.centerLatitude, longitude: group2.centerLongitude)
            return currentLoc.distance(from: loc1) < currentLoc.distance(from: loc2)
        }

        // Monitor up to 20 nearest groups
        let groupsToMonitor = Array(sortedGroups.prefix(20))

        for group in groupsToMonitor {
            guard let groupId = group.id else { continue }

            // Use circular region centered on group with radius based on boundary
            let radius = calculateRadius(for: group)
            let region = CLCircularRegion(
                center: group.center,
                radius: radius,
                identifier: groupId
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true

            locationManager.startMonitoring(for: region)
            monitoredGroups[groupId] = group
        }

        isMonitoring = true
    }

    func stopMonitoringAllGroups() {
        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredGroups.removeAll()
        isMonitoring = false
    }

    func updateGeofenceForGroup(groupId: String, coordinates: [CLLocationCoordinate2D]) async {
        // Only update if we're actively monitoring
        guard isMonitoring, authorizationStatus == .authorizedAlways else { return }

        // Stop monitoring the old region for this group
        for region in locationManager.monitoredRegions where region.identifier == groupId {
            locationManager.stopMonitoring(for: region)
        }

        // Calculate new center and radius from coordinates
        guard !coordinates.isEmpty else { return }

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        let centerLat = (latitudes.min()! + latitudes.max()!) / 2
        let centerLon = (longitudes.min()! + longitudes.max()!) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        // Calculate radius as max distance from center to any boundary point
        let centerLocation = CLLocation(latitude: centerLat, longitude: centerLon)
        var maxDistance: CLLocationDistance = 0
        for coord in coordinates {
            let pointLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let distance = centerLocation.distance(from: pointLocation)
            maxDistance = max(maxDistance, distance)
        }

        // Add padding and enforce limits
        let radius = min(max(maxDistance * 1.1, 50), locationManager.maximumRegionMonitoringDistance)

        // Create and monitor new region
        let region = CLCircularRegion(
            center: center,
            radius: radius,
            identifier: groupId
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true

        locationManager.startMonitoring(for: region)

        // Update the cached group if we have it
        if var cachedGroup = monitoredGroups[groupId] {
            cachedGroup.boundary = coordinates.map { Coordinate(from: $0) }
            monitoredGroups[groupId] = cachedGroup
        }

        print("Updated geofence for group \(groupId) - center: \(center), radius: \(radius)m")
    }

    func checkPresenceInGroups(_ groups: [LocationGroup]) -> [String: Bool] {
        guard let currentLoc = currentLocation else { return [:] }

        var presenceMap: [String: Bool] = [:]
        let coordinate = currentLoc.coordinate

        for group in groups {
            guard let groupId = group.id else { continue }
            presenceMap[groupId] = group.contains(coordinate: coordinate)
        }

        return presenceMap
    }

    func isInGroup(_ group: LocationGroup) -> Bool {
        guard let currentLoc = currentLocation else { return false }
        return group.contains(coordinate: currentLoc.coordinate)
    }

    private func calculateRadius(for group: LocationGroup) -> CLLocationDistance {
        guard !group.boundary.isEmpty else { return 100 }

        let center = group.center
        var maxDistance: CLLocationDistance = 0

        for coord in group.boundaryCoordinates {
            let pointLocation = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let distance = pointLocation.distance(from: centerLocation)
            maxDistance = max(maxDistance, distance)
        }

        // Add 10% buffer
        return maxDistance * 1.1
    }

    func distanceToGroup(_ group: LocationGroup) -> CLLocationDistance? {
        guard let currentLoc = currentLocation else { return nil }
        let groupLocation = CLLocation(latitude: group.centerLatitude, longitude: group.centerLongitude)
        return currentLoc.distance(from: groupLocation)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            if let groupId = region.identifier as String? {
                self.onEnterRegion?(groupId)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            if let groupId = region.identifier as String? {
                self.onExitRegion?(groupId)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus

            switch manager.authorizationStatus {
            case .authorizedAlways:
                self.startUpdatingLocation()
            case .authorizedWhenInUse:
                self.startUpdatingLocation()
                // Optionally request upgrade to Always (user can decline)
                // Uncomment the line below if you want to prompt for Always after When In Use
                // self.requestAlwaysAuthorization()
            case .denied, .restricted:
                self.errorMessage = "Location access denied. Please enable in Settings."
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
}
