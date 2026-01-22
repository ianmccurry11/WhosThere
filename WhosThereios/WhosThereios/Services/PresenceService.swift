//
//  PresenceService.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import Combine
import CoreLocation

@MainActor
class PresenceService: ObservableObject {
    static let shared = PresenceService()

    @Published var presenceByGroup: [String: GroupPresenceSummary] = [:]
    @Published var manualOverrides: [String: Bool] = [:]
    @Published var autoCheckOutTimers: [String: Date] = [:]  // groupId -> expiration time

    private var locationService: LocationService { LocationService.shared }
    private var firestoreService: FirestoreService { FirestoreService.shared }
    private var achievementService: AchievementService { AchievementService.shared }

    private var cancellables = Set<AnyCancellable>()
    private var presenceListeners: [String: Any] = [:]
    private var lastAutoUpdate: [String: Date] = [:]
    private let updateThrottle: TimeInterval = 30 // Minimum seconds between auto-updates
    private var checkOutTimerTasks: [String: Task<Void, Never>] = [:]

    /// Maximum time a user can be marked as present before auto check-out (10 hours)
    private let maxPresenceDuration: TimeInterval = 10 * 60 * 60

    init() {
        setupLocationCallbacks()
    }

    /// Returns true if location permission is "Always", false otherwise
    var hasAlwaysLocationPermission: Bool {
        locationService.authorizationStatus == .authorizedAlways
    }

    /// Gets the auto check-out duration in minutes from user settings
    private var autoCheckOutMinutes: Int {
        firestoreService.currentUser?.autoCheckOutMinutes ?? 60
    }

    private func setupLocationCallbacks() {
        // Handle entering a region
        locationService.onEnterRegion = { [weak self] groupId in
            Task { @MainActor in
                await self?.handleRegionEnter(groupId: groupId)
            }
        }

        // Handle exiting a region
        locationService.onExitRegion = { [weak self] groupId in
            Task { @MainActor in
                await self?.handleRegionExit(groupId: groupId)
            }
        }
    }

    func startMonitoring(groups: [LocationGroup]) {
        locationService.startMonitoringGroups(groups)

        // Set up presence listeners for each group
        for group in groups {
            guard let groupId = group.id else { continue }
            startListeningToPresence(groupId: groupId)
        }

        // Do initial presence check
        Task {
            await checkAndUpdateAllPresence(groups: groups)
        }
    }

    func stopMonitoring() {
        locationService.stopMonitoringAllGroups()

        // Remove all presence listeners
        presenceListeners.removeAll()
    }

    // MARK: - Manual Check-in/out

    func manualCheckIn(groupId: String) async {
        manualOverrides[groupId] = true
        await firestoreService.updatePresence(groupId: groupId, isPresent: true, isManual: true)
        await refreshPresence(groupId: groupId)

        // Track achievement - get current presence for this group
        if let summary = presenceByGroup[groupId] {
            await achievementService.recordCheckIn(groupId: groupId, presentMembers: summary.presentMembers)
        }

        // Always start auto check-out timer for manual check-ins
        // Timer will be cancelled if user enters the geofence zone (geofencing takes over)
        print("[PresenceService] manualCheckIn - Starting timer for \(autoCheckOutMinutes) minutes")
        startAutoCheckOutTimer(groupId: groupId)
    }

    func manualCheckOut(groupId: String) async {
        manualOverrides[groupId] = false
        await firestoreService.updatePresence(groupId: groupId, isPresent: false, isManual: true)
        await refreshPresence(groupId: groupId)

        // Cancel any pending auto check-out timer
        cancelAutoCheckOutTimer(groupId: groupId)
    }

    func clearManualOverride(groupId: String) {
        manualOverrides.removeValue(forKey: groupId)
    }

    // MARK: - Auto Check-out Timer

    private func startAutoCheckOutTimer(groupId: String) {
        // Cancel any existing timer for this group
        cancelAutoCheckOutTimer(groupId: groupId)

        let minutes = autoCheckOutMinutes
        let expirationDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        autoCheckOutTimers[groupId] = expirationDate
        print("[PresenceService] startAutoCheckOutTimer - Set timer for \(minutes) minutes, expires at \(expirationDate)")

        // Create a background task that will auto check-out
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self else { return }
                // Only auto check-out if timer is still active (user hasn't manually checked out)
                if self.autoCheckOutTimers[groupId] != nil {
                    Task {
                        await self.performAutoCheckOut(groupId: groupId)
                    }
                }
            }
        }

        checkOutTimerTasks[groupId] = task
    }

    private func cancelAutoCheckOutTimer(groupId: String) {
        checkOutTimerTasks[groupId]?.cancel()
        checkOutTimerTasks.removeValue(forKey: groupId)
        autoCheckOutTimers.removeValue(forKey: groupId)
    }

    private func performAutoCheckOut(groupId: String) async {
        print("Auto check-out triggered for group: \(groupId)")
        manualOverrides.removeValue(forKey: groupId)
        autoCheckOutTimers.removeValue(forKey: groupId)
        await firestoreService.updatePresence(groupId: groupId, isPresent: false, isManual: false)
        await refreshPresence(groupId: groupId)
    }

    /// Returns the remaining time until auto check-out for a group, or nil if no timer is active
    func remainingAutoCheckOutTime(groupId: String) -> TimeInterval? {
        guard let expirationDate = autoCheckOutTimers[groupId] else { return nil }
        let remaining = expirationDate.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// Resets the auto check-out timer for a group (e.g., when user refreshes presence)
    func resetAutoCheckOutTimer(groupId: String) {
        if autoCheckOutTimers[groupId] != nil && !hasAlwaysLocationPermission {
            startAutoCheckOutTimer(groupId: groupId)
        }
    }

    // MARK: - Automatic Presence

    private func handleRegionEnter(groupId: String) async {
        // Don't update if manually checked out
        if manualOverrides[groupId] == false {
            return
        }

        // Throttle auto updates
        if let lastUpdate = lastAutoUpdate[groupId],
           Date().timeIntervalSince(lastUpdate) < updateThrottle {
            return
        }

        // Cancel any manual check-in timer - geofencing takes over now
        if autoCheckOutTimers[groupId] != nil {
            print("[PresenceService] handleRegionEnter - Cancelling timer, geofencing takes over for group \(groupId)")
            cancelAutoCheckOutTimer(groupId: groupId)
            // Clear manual override since geofencing is now in control
            manualOverrides.removeValue(forKey: groupId)
        }

        lastAutoUpdate[groupId] = Date()
        await firestoreService.updatePresence(groupId: groupId, isPresent: true, isManual: false)
        await refreshPresence(groupId: groupId)

        // Track achievement for automatic check-in
        if let summary = presenceByGroup[groupId] {
            await achievementService.recordCheckIn(groupId: groupId, presentMembers: summary.presentMembers)
        }
    }

    private func handleRegionExit(groupId: String) async {
        // Don't update if manually checked in
        if manualOverrides[groupId] == true {
            return
        }

        lastAutoUpdate[groupId] = Date()
        await firestoreService.updatePresence(groupId: groupId, isPresent: false, isManual: false)
        await refreshPresence(groupId: groupId)
    }

    func checkAndUpdateAllPresence(groups: [LocationGroup]) async {
        let presenceMap = locationService.checkPresenceInGroups(groups)

        for (groupId, isPresent) in presenceMap {
            // Skip if there's a manual override
            if manualOverrides[groupId] != nil {
                continue
            }

            // Throttle updates
            if let lastUpdate = lastAutoUpdate[groupId],
               Date().timeIntervalSince(lastUpdate) < updateThrottle {
                continue
            }

            lastAutoUpdate[groupId] = Date()
            await firestoreService.updatePresence(groupId: groupId, isPresent: isPresent, isManual: false)
        }

        // Refresh all presence data
        for group in groups {
            if let groupId = group.id {
                await refreshPresence(groupId: groupId)
            }
        }
    }

    // MARK: - Stale Presence Detection

    /// Checks if a presence record is stale (older than maxPresenceDuration)
    private func isPresenceStale(_ presence: Presence) -> Bool {
        let age = Date().timeIntervalSince(presence.lastUpdated)
        return age > maxPresenceDuration
    }

    /// Filters out stale presences from a list
    private func filterStalePresences(_ presences: [Presence]) -> [Presence] {
        presences.filter { !isPresenceStale($0) }
    }

    /// Checks if the current user has any stale presences and auto checks them out
    func checkAndClearStalePresences() async {
        guard let userId = firestoreService.currentUser?.id else { return }

        for (groupId, summary) in presenceByGroup {
            // Find current user's presence in this group
            if let userPresence = summary.presentMembers.first(where: { $0.userId == userId }) {
                if isPresenceStale(userPresence) {
                    print("Stale presence detected for user in group: \(groupId)")
                    await performAutoCheckOut(groupId: groupId)
                }
            }
        }
    }

    // MARK: - Presence Data

    private func startListeningToPresence(groupId: String) {
        let listener = firestoreService.listenToPresence(groupId: groupId) { [weak self] presences in
            Task { @MainActor in
                guard let self = self else { return }
                // Filter out stale presences (older than 10 hours)
                let activePresences = self.filterStalePresences(presences)

                self.presenceByGroup[groupId] = GroupPresenceSummary(
                    groupId: groupId,
                    presentCount: activePresences.count,
                    presentMembers: activePresences
                )

                // Check if current user's presence is stale and auto check-out
                await self.checkCurrentUserStalePresence(groupId: groupId, presences: presences)
            }
        }
        presenceListeners[groupId] = listener
    }

    /// Checks if the current user's presence in a specific group is stale and auto checks out
    private func checkCurrentUserStalePresence(groupId: String, presences: [Presence]) async {
        guard let userId = firestoreService.currentUser?.id else { return }

        if let userPresence = presences.first(where: { $0.userId == userId && $0.isPresent }) {
            if isPresenceStale(userPresence) {
                print("Auto check-out: User presence stale in group \(groupId) (> 10 hours)")
                await performAutoCheckOut(groupId: groupId)
            }
        }
    }

    func refreshPresence(groupId: String) async {
        let presences = await firestoreService.fetchPresenceForGroup(groupId: groupId)

        // Filter out stale presences
        let activePresences = filterStalePresences(presences)

        presenceByGroup[groupId] = GroupPresenceSummary(
            groupId: groupId,
            presentCount: activePresences.count,
            presentMembers: activePresences
        )

        // Check if current user's presence is stale
        await checkCurrentUserStalePresence(groupId: groupId, presences: presences)
    }

    func getPresenceSummary(for groupId: String) -> GroupPresenceSummary? {
        return presenceByGroup[groupId]
    }

    func isUserPresent(groupId: String, userId: String) -> Bool {
        guard let summary = presenceByGroup[groupId] else { return false }
        return summary.presentMembers.contains { $0.userId == userId }
    }

    // MARK: - Helpers

    func formatPresenceDisplay(for group: LocationGroup) -> String {
        guard let groupId = group.id,
              let summary = presenceByGroup[groupId] else {
            return "No one here"
        }

        if summary.presentCount == 0 {
            return "No one here"
        }

        switch group.presenceDisplayMode {
        case .count:
            return summary.presentCount == 1 ? "1 person here" : "\(summary.presentCount) people here"
        case .names:
            let names = summary.presentMembers.compactMap { $0.displayName }
            if names.isEmpty {
                return "\(summary.presentCount) people here"
            } else if names.count <= 3 {
                return names.joined(separator: ", ")
            } else {
                let firstThree = names.prefix(3).joined(separator: ", ")
                return "\(firstThree) +\(names.count - 3) more"
            }
        }
    }
}
