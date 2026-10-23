//
//  LocationService.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import CoreLocation
import Combine
import UIKit

/// Wraps CLLocationManager for location updates and geofence monitoring.
/// iOS limits monitored regions to 20 -- Android allows up to 100.
/// Geofence enter/exit events are forwarded via onEnterRegion/onExitRegion callbacks.
@MainActor
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    // MARK: - Public State

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isMonitoring = false
    @Published var errorMessage: String?
    /// False when the user turned off Precise Location; fixes are then off by
    /// a mile or more and can never match a group's boundary
    @Published var hasPreciseLocation = true

    private let locationManager = CLLocationManager()
    private var monitoredGroups: [String: LocationGroup] = [:]

    var onEnterRegion: ((String) -> Void)?
    var onExitRegion: ((String) -> Void)?
    /// iOS woke the app in the background with new location info
    /// (significant move or a visit). The argument names the trigger.
    var onBackgroundWake: ((String) -> Void)?
    /// New location from the continuous stream while the app is open
    var onForegroundLocation: (() -> Void)?
    /// iOS reported whether we're inside a group's geofence (identifier, inside?)
    var onRegionState: ((String, Bool) -> Void)?

    /// Identifier of the extra geofence around the user's position: leaving it
    /// means they've moved far enough that the nearest groups need re-picking
    static let refreshRingIdentifier = "__refresh_ring__"
    /// Groups last passed to `startMonitoringGroups`, kept so the regions can be
    /// re-picked when the user moves or a first location arrives
    private var groupsToMonitor: [LocationGroup] = []

    /// Callers waiting on `requestFreshLocation`
    private var pendingLocationRequests: [UUID: CheckedContinuation<CLLocation?, Never>] = [:]

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
        hasPreciseLocation = locationManager.accuracyAuthorization == .fullAccuracy
    }

    // MARK: - Permission Handling

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

    // MARK: - Location Updates

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    /// Returns a recent, usable location fix: the current one if it's fresh
    /// enough, otherwise asks iOS for a new one and waits up to `timeout`.
    /// Works from background wakes when the user granted "Always".
    func requestFreshLocation(maxAge: TimeInterval = 60, timeout: TimeInterval = 15) async -> CLLocation? {
        if let currentLocation,
           -currentLocation.timestamp.timeIntervalSinceNow <= maxAge,
           currentLocation.horizontalAccuracy >= 0,
           currentLocation.horizontalAccuracy <= PresencePolicy.maxUsableAccuracy {
            return currentLocation
        }

        let requestId = UUID()
        return await withCheckedContinuation { continuation in
            pendingLocationRequests[requestId] = continuation
            locationManager.requestLocation()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                // Timed out: hand back whatever we have
                self?.resolveLocationRequest(requestId, with: self?.currentLocation)
            }
        }
    }

    private func resolveLocationRequest(_ requestId: UUID, with location: CLLocation?) {
        guard let continuation = pendingLocationRequests.removeValue(forKey: requestId) else { return }
        continuation.resume(returning: location)
    }

    private func resolveAllLocationRequests(with location: CLLocation?) {
        for requestId in Array(pendingLocationRequests.keys) {
            resolveLocationRequest(requestId, with: location)
        }
    }

    // MARK: - Background Wake-ups

    /// Low-power triggers that let iOS wake (or relaunch) the app so it can
    /// re-confirm check-ins: moves of ~500m and arrivals/departures at places.
    /// Requires "Always" permission.
    func startBackgroundWakeups() {
        guard authorizationStatus == .authorizedAlways else { return }
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }

    func stopBackgroundWakeups() {
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
    }

    // MARK: - Geofence Registration (max 20 regions on iOS)

    /// Registers geofences for the nearest groups (iOS allows 20 regions: 19
    /// groups plus a refresh ring around the user). Then asks iOS whether
    /// we're already inside each one, since iOS only reports *crossings* and
    /// would otherwise never tell us about a zone we started in.
    func startMonitoringGroups(_ groups: [LocationGroup]) {
        groupsToMonitor = groups

        // Geofence monitoring requires "Always" authorization
        // Without it, we skip region monitoring (detection only runs while the app is open)
        guard authorizationStatus == .authorizedAlways else {
            AppLogger.debug("Skipping geofence monitoring - requires 'Always' location permission")
            isMonitoring = false
            return
        }

        // Without a location yet, register in list order; re-picked by distance
        // once the first location arrives
        var nearestGroups = groups
        if let currentLoc = currentLocation {
            nearestGroups.sort { group1, group2 in
                currentLoc.distance(from: CLLocation(latitude: group1.centerLatitude, longitude: group1.centerLongitude))
                    < currentLoc.distance(from: CLLocation(latitude: group2.centerLatitude, longitude: group2.centerLongitude))
            }
        } else {
            startUpdatingLocation()
        }

        for region in locationManager.monitoredRegions {
            locationManager.stopMonitoring(for: region)
        }
        monitoredGroups.removeAll()

        for group in nearestGroups.prefix(19) {
            guard let groupId = group.id else { continue }
            let region = CLCircularRegion(
                center: group.center,
                radius: geofenceRadius(for: group),
                identifier: groupId
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            locationManager.startMonitoring(for: region)
            monitoredGroups[groupId] = group
        }

        if let currentLoc = currentLocation {
            let ring = CLCircularRegion(
                center: currentLoc.coordinate,
                radius: PresencePolicy.refreshRingRadius,
                identifier: Self.refreshRingIdentifier
            )
            ring.notifyOnEntry = false
            ring.notifyOnExit = true
            locationManager.startMonitoring(for: ring)
        }

        isMonitoring = true
    }

    /// Re-picks the nearest groups around the current location
    func refreshMonitoredRegions() {
        guard !groupsToMonitor.isEmpty else { return }
        startMonitoringGroups(groupsToMonitor)
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
        guard !coordinates.isEmpty,
              let minLat = coordinates.map({ $0.latitude }).min(),
              let maxLat = coordinates.map({ $0.latitude }).max(),
              let minLon = coordinates.map({ $0.longitude }).min(),
              let maxLon = coordinates.map({ $0.longitude }).max() else { return }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
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
        let radius = min(max(maxDistance * 1.1, PresencePolicy.minRegionRadius), locationManager.maximumRegionMonitoringDistance)

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

        AppLogger.debug("Updated geofence for group \(groupId) - center: \(center), radius: \(radius)m")
    }

    // MARK: - Point-in-Polygon Detection

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

    /// Circle around the group's boundary used as a wake-up trigger: the
    /// farthest corner plus 10%, never below the ~150m iOS handles reliably.
    /// The real in/out decision is made against the boundary afterwards.
    private func geofenceRadius(for group: LocationGroup) -> CLLocationDistance {
        let center = CLLocation(latitude: group.center.latitude, longitude: group.center.longitude)
        let farthestCorner = group.boundaryCoordinates
            .map { center.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) }
            .max() ?? 0
        return min(
            max(farthestCorner * 1.1, PresencePolicy.minRegionRadius),
            locationManager.maximumRegionMonitoringDistance
        )
    }

    func distanceToGroup(_ group: LocationGroup) -> CLLocationDistance? {
        guard let currentLoc = currentLocation else { return nil }
        let groupLocation = CLLocation(latitude: group.centerLatitude, longitude: group.centerLongitude)
        return currentLoc.distance(from: groupLocation)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let isFirstLocation = self.currentLocation == nil
            self.currentLocation = location
            self.resolveAllLocationRequests(with: location)

            // Regions registered before we had a location: re-pick by distance
            if isFirstLocation {
                self.refreshMonitoredRegions()
            }

            if UIApplication.shared.applicationState == .background {
                self.onBackgroundWake?("location")
            } else {
                self.onForegroundLocation?()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // An open-ended visit is an arrival; one with a departure date means they left
        let trigger = visit.departureDate == .distantFuture ? "visit_arrival" : "visit_departure"
        Task { @MainActor in
            self.onBackgroundWake?(trigger)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        // Ask whether we're already inside: iOS only reports crossings
        manager.requestState(for: region)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard state != .unknown else { return }
        Task { @MainActor in
            self.onRegionState?(region.identifier, state == .inside)
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
            self.hasPreciseLocation = manager.accuracyAuthorization == .fullAccuracy

            switch manager.authorizationStatus {
            case .authorizedAlways:
                self.startUpdatingLocation()
                self.startBackgroundWakeups()
                // Permission just upgraded: register the geofences we skipped
                if !self.isMonitoring {
                    self.refreshMonitoredRegions()
                }
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
            AppLogger.debug("Location error: \(error.localizedDescription)")
            self.resolveAllLocationRequests(with: nil)
            self.errorMessage = "Unable to determine your location. Please check your settings."
        }
    }
}
