//
//  WatchViewModel.swift
//  WhosThereWatch
//
//  Created by Claude on 1/18/26.
//

import Foundation
import Combine
import WatchConnectivity
import CoreLocation

// MARK: - Watch Group Model

struct WatchGroup: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let centerLatitude: Double
    let centerLongitude: Double
    var presentCount: Int
    var isUserPresent: Bool

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
}

// MARK: - Watch ViewModel

@MainActor
class WatchViewModel: NSObject, ObservableObject {
    @Published var groups: [WatchGroup] = []
    @Published var isLoading = true
    @Published var nearestGroup: WatchGroup?
    @Published var currentLocation: CLLocation?

    private var session: WCSession?
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        setupWatchConnectivity()
        setupLocationManager()
    }

    // MARK: - Watch Connectivity

    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Location Manager

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Public Methods

    func loadGroups() {
        isLoading = true

        // Request data from iPhone
        sendMessage(["action": "requestGroups"])

        // Request location
        locationManager.requestLocation()

        // Simulate loading timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.isLoading = false
        }
    }

    func toggleCheckIn(for group: WatchGroup) {
        let newState = !group.isUserPresent

        // Optimistic update
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index].isUserPresent = newState
            if newState {
                groups[index].presentCount += 1
            } else {
                groups[index].presentCount = max(0, groups[index].presentCount - 1)
            }
        }

        // Update nearest if same group
        if nearestGroup?.id == group.id {
            nearestGroup?.isUserPresent = newState
        }

        // Send to iPhone
        sendMessage([
            "action": "toggleCheckIn",
            "groupId": group.id,
            "checkIn": newState
        ])

        // Haptic feedback
        WKInterfaceDevice.current().play(newState ? .success : .click)
    }

    func isCheckedIn(_ group: WatchGroup) -> Bool {
        groups.first(where: { $0.id == group.id })?.isUserPresent ?? false
    }

    func presenceCount(for group: WatchGroup) -> Int {
        groups.first(where: { $0.id == group.id })?.presentCount ?? 0
    }

    // MARK: - Private Methods

    private func sendMessage(_ message: [String: Any]) {
        guard let session = session, session.isReachable else {
            print("iPhone not reachable")
            return
        }

        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending message: \(error)")
        }
    }

    private func updateNearestGroup() {
        guard let location = currentLocation else {
            nearestGroup = nil
            return
        }

        var closest: WatchGroup?
        var closestDistance: CLLocationDistance = .greatestFiniteMagnitude

        for group in groups {
            let groupLocation = CLLocation(latitude: group.centerLatitude, longitude: group.centerLongitude)
            let distance = location.distance(from: groupLocation)

            // Only consider groups within 500 meters as "nearby"
            if distance < 500 && distance < closestDistance {
                closest = group
                closestDistance = distance
            }
        }

        nearestGroup = closest

        // Auto check-in if within 100 meters and not already checked in
        if let nearest = closest, closestDistance < 100, !nearest.isUserPresent {
            toggleCheckIn(for: nearest)
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchViewModel: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            Task { @MainActor in
                self.loadGroups()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            handleMessage(applicationContext)
        }
    }

    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        if let groupsData = message["groups"] as? Data {
            do {
                let decodedGroups = try JSONDecoder().decode([WatchGroup].self, from: groupsData)
                self.groups = decodedGroups
                self.isLoading = false
                updateNearestGroup()
            } catch {
                print("Error decoding groups: \(error)")
            }
        }

        // Handle presence update
        if let groupId = message["groupId"] as? String,
           let presentCount = message["presentCount"] as? Int,
           let isUserPresent = message["isUserPresent"] as? Bool {
            if let index = groups.firstIndex(where: { $0.id == groupId }) {
                groups[index].presentCount = presentCount
                groups[index].isUserPresent = isUserPresent
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension WatchViewModel: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location
            self.updateNearestGroup()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error)")
    }
}

// MARK: - WKInterfaceDevice Extension

import WatchKit

extension WKInterfaceDevice {
    func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}
