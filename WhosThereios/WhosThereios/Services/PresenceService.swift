//
//  PresenceService.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore
import UIKit

/// Manages user presence (check-in/out) across all joined groups.
/// Handles manual check-ins, geofence-triggered transitions, auto-checkout timers,
/// and periodic heartbeat refresh. Timer state is persisted to UserDefaults
/// to survive app termination.
@MainActor
class PresenceService: ObservableObject {
    static let shared = PresenceService()

    // MARK: - Public State

    @Published var presenceByGroup: [String: GroupPresenceSummary] = [:]
    @Published var manualOverrides: [String: Bool] = [:]
    @Published var autoCheckOutTimers: [String: Date] = [:]  // groupId -> expiration time

    private var locationService: LocationService { LocationService.shared }
    private var firestoreService: FirestoreService { FirestoreService.shared }
    private var achievementService: AchievementService { AchievementService.shared }
    private var analyticsService: AnalyticsService { AnalyticsService.shared }
    private var levelService: LevelService { LevelService.shared }

    /// Tracks check-in timestamps for duration calculation
    private var checkInTimes: [String: Date] = [:]

    private var cancellables = Set<AnyCancellable>()
    private var presenceListeners: [String: ListenerRegistration] = [:]

    /// Raw presence docs per group exactly as Firestore last sent them (unfiltered).
    /// `presenceByGroup` is always derived from this with `Presence.isActive`.
    private var rawPresenceByGroup: [String: [Presence]] = [:]
    /// Joined groups handed to `startMonitoring` (geofenced)
    private var monitoredGroupIds: Set<String> = []
    /// Every group the map or list can show (joined + nearby public)
    private var displayedGroupIds: Set<String> = []
    /// A group open in the detail sheet that may not be in either set above
    private var focusedGroupId: String?
    /// Groups where we're already writing a checkout for our own lapsed presence
    private var pendingStaleCheckouts: Set<String> = []
    /// "groupId/userId" of other members' lapsed check-ins we've already cleared
    private var clearedLapsedPresences: Set<String> = []
    /// Re-applies the freshness rule so lapsed check-ins drop off without a new snapshot
    private var expiryTickTask: Task<Void, Never>?
    private let expiryTickInterval: TimeInterval = 30
    /// Last time `confirmPresence` ran, to throttle background wakes
    private var lastConfirmAt: Date?
    /// Last time this device asked the server to re-check each group
    private var lastRecheckRequestAt: [String: Date] = [:]
    /// Matches ON_DEMAND_RECHECK_AFTER_MS in the Cloud Function
    private let onDemandRecheckAfter: TimeInterval = 10 * 60
    private var lastAutoUpdate: [String: Date] = [:]
    private let updateThrottle: TimeInterval = 30 // Minimum seconds between auto-updates
    private var checkOutTimerTasks: [String: Task<Void, Never>] = [:]

    /// UserDefaults key for persisted auto-checkout expiration times
    private let persistedTimersKey = "autoCheckOutExpirations"

    /// Heartbeat timer: refreshes presence every 15 minutes while the app is in the foreground
    /// This keeps `lastUpdated` and `expiresAt` fresh so the presence doesn't expire while the user has the app open
    private var heartbeatTask: Task<Void, Never>?
    private let heartbeatInterval: TimeInterval = 15 * 60  // 15 minutes

    init() {
        setupLocationCallbacks()
        restorePersistedTimers()
        observeDisplayedGroups()
    }

    /// Returns true if location permission is "Always", false otherwise
    var hasAlwaysLocationPermission: Bool {
        locationService.authorizationStatus == .authorizedAlways
    }

    /// Gets the auto check-out duration in minutes from user settings
    private var autoCheckOutMinutes: Int {
        firestoreService.currentUser?.autoCheckOutMinutes ?? 60
    }

    /// When a new or re-confirmed automatic check-in should expire.
    /// "Always" users get re-confirmed by background wakes, so it lasts
    /// `PresencePolicy.autoExpiry`; "When In Use" users can't be confirmed in
    /// the background, so it falls back to their auto check-out setting.
    private var autoPresenceExpiry: Date {
        let duration = hasAlwaysLocationPermission
            ? PresencePolicy.autoExpiry
            : TimeInterval(autoCheckOutMinutes * 60)
        return Date().addingTimeInterval(duration)
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

        // Significant moves and visits: re-confirm we're still where we said
        locationService.onBackgroundWake = { [weak self] trigger in
            Task { @MainActor in
                await self?.confirmPresence(reason: trigger)
            }
        }
    }

    func startMonitoring(groups: [LocationGroup]) {
        locationService.startMonitoringGroups(groups)

        monitoredGroupIds = Set(groups.compactMap(\.id))
        syncPresenceListeners()

        // Do initial presence check
        Task {
            await checkAndUpdateAllPresence(groups: groups)
        }
    }

    func stopMonitoring() {
        locationService.stopMonitoringAllGroups()

        // Drop listeners that only existed for geofenced groups; groups still
        // shown on the map/list keep theirs
        monitoredGroupIds.removeAll()
        syncPresenceListeners()
    }

    // MARK: - Manual Check-in/out

    func manualCheckIn(groupId: String) async {
        manualOverrides[groupId] = true
        checkInTimes[groupId] = Date()

        let expiresAt = Date().addingTimeInterval(TimeInterval(autoCheckOutMinutes * 60))
        await firestoreService.updatePresence(groupId: groupId, isPresent: true, isManual: true, expiresAt: expiresAt)
        await refreshPresence(groupId: groupId)

        // Update leaderboard entry and check top visitor achievement
        await firestoreService.updateLeaderboardEntry(groupId: groupId)
        await achievementService.checkTopVisitor(groupId: groupId)

        // Track achievement - get current presence for this group
        if let summary = presenceByGroup[groupId] {
            await achievementService.recordCheckIn(groupId: groupId, presentMembers: summary.presentMembers)
        }

        // Award check-in XP (disabled for manual check-ins to prevent abuse)
        // await levelService.awardCheckInXP()

        // Track analytics
        analyticsService.trackCheckIn(groupId: groupId, isManual: true)

        // Always start auto check-out timer for manual check-ins
        // Timer will be cancelled if user enters the geofence zone (geofencing takes over)
        AppLogger.debug("[PresenceService] manualCheckIn - Starting timer for \(autoCheckOutMinutes) minutes")
        startAutoCheckOutTimer(groupId: groupId)
    }

    func manualCheckOut(groupId: String) async {
        // Calculate duration
        let durationMinutes: Int
        if let checkInTime = checkInTimes[groupId] {
            durationMinutes = Int(Date().timeIntervalSince(checkInTime) / 60)
            checkInTimes.removeValue(forKey: groupId)
        } else {
            durationMinutes = 0
        }

        // Count remaining members before checking out
        let remainingMembers = countRemainingMembers(groupId: groupId)

        manualOverrides[groupId] = false
        await firestoreService.updatePresence(groupId: groupId, isPresent: false, isManual: true)
        await refreshPresence(groupId: groupId)

        // Track achievements for check-out
        await achievementService.recordCheckOut(groupId: groupId, remainingMembers: remainingMembers, sessionDurationMinutes: durationMinutes)

        // Track analytics
        analyticsService.trackCheckOut(groupId: groupId, isManual: true, durationMinutes: durationMinutes)

        // Cancel any pending auto check-out timer
        cancelAutoCheckOutTimer(groupId: groupId)
    }

    func clearManualOverride(groupId: String) {
        manualOverrides.removeValue(forKey: groupId)
    }

    // MARK: - Auto-checkout Timer Logic

    private func startAutoCheckOutTimer(groupId: String) {
        // Cancel any existing timer for this group
        cancelAutoCheckOutTimer(groupId: groupId)

        let minutes = autoCheckOutMinutes
        let expirationDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        autoCheckOutTimers[groupId] = expirationDate
        persistTimers()
        AppLogger.debug("[PresenceService] startAutoCheckOutTimer - Set timer for \(minutes) minutes, expires at \(expirationDate)")

        // Create a background task that will auto check-out
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(minutes) * 60 * 1_000_000_000)

            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self = self else { return }
                // Only auto check-out if timer is still active (user hasn't manually checked out)
                if self.autoCheckOutTimers[groupId] != nil {
                    Task {
                        await self.performAutoCheckOut(groupId: groupId, reason: "timer")
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
        persistTimers()
    }

    private func performAutoCheckOut(groupId: String, reason: String = "timer") async {
        AppLogger.debug("Auto check-out triggered for group: \(groupId) (reason: \(reason))")

        // Calculate duration
        let durationMinutes: Int
        if let checkInTime = checkInTimes[groupId] {
            durationMinutes = Int(Date().timeIntervalSince(checkInTime) / 60)
            checkInTimes.removeValue(forKey: groupId)
        } else {
            durationMinutes = 0
        }

        manualOverrides.removeValue(forKey: groupId)
        autoCheckOutTimers.removeValue(forKey: groupId)
        checkOutTimerTasks[groupId]?.cancel()
        checkOutTimerTasks.removeValue(forKey: groupId)
        persistTimers()
        await firestoreService.updatePresence(groupId: groupId, isPresent: false, isManual: false, source: "auto_checkout_\(reason)")
        await refreshPresence(groupId: groupId)

        // Track analytics
        analyticsService.trackAutoCheckOut(groupId: groupId, reason: reason)
        analyticsService.trackCheckOut(groupId: groupId, isManual: false, durationMinutes: durationMinutes)
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

    // MARK: - Persisted Timer Management

    /// Saves current auto-checkout expiration times to UserDefaults so they survive app background/kill
    private func persistTimers() {
        let expirations = autoCheckOutTimers.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(expirations, forKey: persistedTimersKey)
    }

    /// Restores persisted timers on app launch and immediately checks for any that expired while app was inactive
    private func restorePersistedTimers() {
        guard let stored = UserDefaults.standard.dictionary(forKey: persistedTimersKey) as? [String: TimeInterval] else { return }

        let now = Date()
        for (groupId, timestamp) in stored {
            let expiration = Date(timeIntervalSince1970: timestamp)
            if expiration <= now {
                // Timer expired while app was inactive — schedule checkout
                AppLogger.debug("[PresenceService] Persisted timer expired for group \(groupId) while app was inactive")
                autoCheckOutTimers[groupId] = expiration
                Task {
                    await performAutoCheckOut(groupId: groupId, reason: "expired_while_inactive")
                }
            } else {
                // Timer still active — restore in-memory and restart Task.sleep for remaining time
                autoCheckOutTimers[groupId] = expiration
                manualOverrides[groupId] = true
                let remaining = expiration.timeIntervalSince(now)
                let task = Task { [weak self] in
                    try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        guard let self = self else { return }
                        if self.autoCheckOutTimers[groupId] != nil {
                            Task { await self.performAutoCheckOut(groupId: groupId, reason: "timer") }
                        }
                    }
                }
                checkOutTimerTasks[groupId] = task
            }
        }
    }

    /// Called when app returns to foreground — checks all active timers against wall-clock time
    /// This catches the case where Task.sleep was suspended during background
    func checkExpiredTimersOnForeground() async {
        let now = Date()
        var expiredGroupIds: [String] = []

        for (groupId, expiration) in autoCheckOutTimers {
            if expiration <= now {
                expiredGroupIds.append(groupId)
            }
        }

        for groupId in expiredGroupIds {
            AppLogger.debug("[PresenceService] Timer expired during background for group \(groupId)")
            await performAutoCheckOut(groupId: groupId, reason: "expired_in_background")
        }

        // Also check stale presences on foreground return
        await checkAndClearStalePresences()

        // Opening the app is a good moment to re-confirm automatic check-ins
        await confirmPresence(reason: "foreground")
    }

    // MARK: - Heartbeat / Periodic Refresh

    /// Start the heartbeat timer — call when the app enters foreground
    func startHeartbeat() {
        stopHeartbeat()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.heartbeatInterval ?? 900) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.refreshActivePresences()
            }
        }
        AppLogger.debug("[PresenceService] Heartbeat started (interval: \(Int(heartbeatInterval / 60)) min)")
    }

    /// Stop the heartbeat timer — call when the app enters background
    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    /// Keeps the user's check-ins alive while the app is open.
    /// Manual check-ins just refresh `lastUpdated` and keep their original
    /// expiry so the auto-checkout timer fires on schedule. Automatic ones are
    /// only extended if a location fix says the user is still there.
    private func refreshActivePresences() async {
        guard let userId = firestoreService.currentUser?.id else { return }

        for (groupId, summary) in presenceByGroup where manualOverrides[groupId] == true {
            guard summary.presentMembers.contains(where: { $0.userId == userId }) else { continue }
            let existingExpiresAt = autoCheckOutTimers[groupId]
            await firestoreService.updatePresence(groupId: groupId, isPresent: true, isManual: true, expiresAt: existingExpiresAt)
            AppLogger.debug("[PresenceService] Heartbeat refreshed manual presence for group \(groupId)")
        }

        await confirmPresence(reason: "heartbeat", force: true)
    }

    // MARK: - Re-confirming Automatic Check-ins

    /// Re-checks the user's location against every group they're automatically
    /// checked in to, and pushes each check-in's expiry forward if they're still
    /// there. Runs on every wake: silent re-check pushes from the server,
    /// significant moves, visits, opening the app, and the foreground heartbeat.
    ///
    /// This never checks anyone out. A check-in that can't be confirmed shows as
    /// "confirmed 1h ago", then expires on its own.
    func confirmPresence(reason: String, force: Bool = false) async {
        if !force, let lastConfirmAt,
           Date().timeIntervalSince(lastConfirmAt) < PresencePolicy.minConfirmInterval {
            return
        }
        lastConfirmAt = Date()

        // Ask iOS for extra time: in the background we may only get a few seconds
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "ConfirmPresence")
        defer {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }

        // Relaunched in the background: nothing has been loaded yet
        if firestoreService.joinedGroups.isEmpty {
            await firestoreService.fetchJoinedGroups()
        }

        var checkedInGroups: [LocationGroup] = []
        for group in firestoreService.joinedGroups {
            guard let groupId = group.id, manualOverrides[groupId] != true else { continue }
            if let own = await ownPresence(in: groupId), own.isActive(), !own.isManual {
                checkedInGroups.append(group)
            }
        }
        guard !checkedInGroups.isEmpty else { return }

        guard let location = await locationService.requestFreshLocation(timeout: 10) else {
            AppLogger.debug("[PresenceService] confirm(\(reason)): no usable location fix")
            return
        }

        for group in checkedInGroups where group.isAt(location) == true {
            guard let groupId = group.id else { continue }
            await firestoreService.updatePresence(
                groupId: groupId,
                isPresent: true,
                isManual: false,
                expiresAt: autoPresenceExpiry,
                source: reason,
                waitForServer: true
            )
            // Keep the "When In Use" safety-net timer in step with the new expiry
            if autoCheckOutTimers[groupId] != nil {
                startAutoCheckOutTimer(groupId: groupId)
            }
            AppLogger.debug("[PresenceService] confirm(\(reason)): still at \(group.name)")
        }
    }

    /// When someone opens a group, ask the phones of anyone there who hasn't
    /// confirmed recently to re-check (the server picks who gets a push and
    /// rate-limits it). Skipped when everyone there is fresh.
    func requestRecheckIfNeeded(groupId: String?) {
        guard let groupId else { return }
        let now = Date()
        if let lastRequest = lastRecheckRequestAt[groupId],
           now.timeIntervalSince(lastRequest) < PresencePolicy.recheckRequestInterval {
            return
        }

        // If presence isn't loaded yet, let the server decide
        if let summary = presenceByGroup[groupId] {
            let currentUserId = Auth.auth().currentUser?.uid
            let hasQuietMember = summary.presentMembers.contains { presence in
                presence.userId != currentUserId
                    && !presence.isManual
                    && now.timeIntervalSince(presence.lastUpdated) > onDemandRecheckAfter
            }
            guard hasQuietMember else { return }
        }

        lastRecheckRequestAt[groupId] = now
        Task {
            await firestoreService.requestPresenceRecheck(groupId: groupId)
        }
    }

    /// The current user's own presence in a group, from the live listener if
    /// one is running, otherwise read directly (e.g. after a background launch).
    private func ownPresence(in groupId: String) async -> Presence? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        if presenceListeners[groupId] != nil, let presences = rawPresenceByGroup[groupId] {
            // The listener only returns isPresent == true docs
            return presences.first { $0.userId == userId }
        }
        return await firestoreService.fetchOwnPresence(groupId: groupId)
    }

    // MARK: - Geofence Event Handlers

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
            AppLogger.debug("[PresenceService] handleRegionEnter - Cancelling timer, geofencing takes over for group \(groupId)")
            cancelAutoCheckOutTimer(groupId: groupId)
            // Clear manual override since geofencing is now in control
            manualOverrides.removeValue(forKey: groupId)
        }

        lastAutoUpdate[groupId] = Date()
        checkInTimes[groupId] = Date()

        await firestoreService.updatePresence(groupId: groupId, isPresent: true, isManual: false, expiresAt: autoPresenceExpiry, source: "geofence")
        await refreshPresence(groupId: groupId)

        // Update leaderboard entry and check top visitor achievement
        await firestoreService.updateLeaderboardEntry(groupId: groupId)
        await achievementService.checkTopVisitor(groupId: groupId)

        // Track achievement for automatic check-in
        if let summary = presenceByGroup[groupId] {
            await achievementService.recordCheckIn(groupId: groupId, presentMembers: summary.presentMembers)
        }

        // Award check-in XP
        await levelService.awardCheckInXP()

        // Track analytics
        analyticsService.trackCheckIn(groupId: groupId, isManual: false)

        // For "When In Use" users, start a safety-net auto-checkout timer
        // since they won't get geofence exit events when the app is backgrounded
        if !hasAlwaysLocationPermission {
            AppLogger.debug("[PresenceService] handleRegionEnter - 'When In Use' user, starting safety timer for \(autoCheckOutMinutes) min")
            startAutoCheckOutTimer(groupId: groupId)
        }
    }

    private func handleRegionExit(groupId: String) async {
        // Don't update if manually checked in
        if manualOverrides[groupId] == true {
            return
        }

        // Calculate duration
        let durationMinutes: Int
        if let checkInTime = checkInTimes[groupId] {
            durationMinutes = Int(Date().timeIntervalSince(checkInTime) / 60)
            checkInTimes.removeValue(forKey: groupId)
        } else {
            durationMinutes = 0
        }

        lastAutoUpdate[groupId] = Date()
        await firestoreService.updatePresence(groupId: groupId, isPresent: false, isManual: false, source: "geofence")
        await refreshPresence(groupId: groupId)

        // Track analytics
        analyticsService.trackCheckOut(groupId: groupId, isManual: false, durationMinutes: durationMinutes)
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
            let expiresAt = isPresent ? autoPresenceExpiry : nil
            await firestoreService.updatePresence(groupId: groupId, isPresent: isPresent, isManual: false, expiresAt: expiresAt, source: "location_check")

            // For "When In Use" users who are present, start a safety-net timer
            if isPresent && !hasAlwaysLocationPermission && autoCheckOutTimers[groupId] == nil {
                checkInTimes[groupId] = Date()
                AppLogger.debug("[PresenceService] initialSweep - 'When In Use' user present at \(groupId), starting safety timer")
                startAutoCheckOutTimer(groupId: groupId)
            }
        }

        // Refresh all presence data
        for group in groups {
            if let groupId = group.id {
                await refreshPresence(groupId: groupId)
            }
        }
    }

    // MARK: - Stale Presence Cleanup

    /// If the current user's own check-in has lapsed, write the checkout so other
    /// members' phones (and arrival/departure notifications) see it too.
    /// Security rules only allow writing your own presence, so other people's
    /// lapsed check-ins are just hidden by `Presence.isActive`.
    private func checkOutOwnStalePresence(in groupId: String) {
        guard let userId = firestoreService.currentUser?.id,
              !pendingStaleCheckouts.contains(groupId),
              let own = rawPresenceByGroup[groupId]?.first(where: { $0.userId == userId }),
              own.isPresent,
              !own.isActive() else { return }

        pendingStaleCheckouts.insert(groupId)
        AppLogger.debug("Auto check-out: own presence lapsed in group \(groupId)")
        Task {
            await performAutoCheckOut(groupId: groupId, reason: "stale")
            pendingStaleCheckouts.remove(groupId)
        }
    }

    /// Clears other members' lapsed check-ins in Firestore so they don't linger
    /// for everyone else. They're already hidden here by `Presence.isActive`.
    private func clearOthersLapsedPresences(in groupId: String) {
        let currentUserId = Auth.auth().currentUser?.uid
        let now = Date()
        for presence in rawPresenceByGroup[groupId] ?? []
        where presence.userId != currentUserId && presence.isPresent && !presence.isActive(at: now) {
            let key = "\(groupId)/\(presence.userId)"
            guard !clearedLapsedPresences.contains(key) else { continue }
            clearedLapsedPresences.insert(key)
            Task {
                await firestoreService.clearLapsedPresence(groupId: groupId, userId: presence.userId)
            }
        }
    }

    /// Checks if the current user has any stale presences and auto checks them out
    func checkAndClearStalePresences() async {
        for groupId in rawPresenceByGroup.keys {
            publishSummary(for: groupId)
            checkOutOwnStalePresence(in: groupId)
        }
    }

    // MARK: - Presence Data (single source of truth)

    /// Keeps a live listener on every group any screen can show — joined groups
    /// plus nearby public groups — so map bubbles, lists and the detail sheet
    /// all read the same `presenceByGroup`.
    private func observeDisplayedGroups() {
        firestoreService.$joinedGroups
            .combineLatest(firestoreService.$publicGroups)
            .map { joined, publicGroups in Set((joined + publicGroups).compactMap(\.id)) }
            .removeDuplicates()
            .sink { [weak self] groupIds in
                Task { @MainActor in
                    self?.displayedGroupIds = groupIds
                    self?.syncPresenceListeners()
                }
            }
            .store(in: &cancellables)
    }

    /// Makes sure presence is live for a group opened from somewhere other than
    /// the map or list (e.g. a notification). Pass nil when the sheet closes.
    func focusPresence(on groupId: String?) {
        focusedGroupId = groupId
        syncPresenceListeners()
    }

    /// Adds listeners for newly shown groups and removes ones no longer shown.
    private func syncPresenceListeners() {
        var wanted = monitoredGroupIds.union(displayedGroupIds)
        if let focusedGroupId {
            wanted.insert(focusedGroupId)
        }

        for (groupId, listener) in presenceListeners where !wanted.contains(groupId) {
            listener.remove()
            presenceListeners.removeValue(forKey: groupId)
            rawPresenceByGroup.removeValue(forKey: groupId)
            presenceByGroup.removeValue(forKey: groupId)
        }

        for groupId in wanted where presenceListeners[groupId] == nil {
            startListeningToPresence(groupId: groupId)
        }

        if wanted.isEmpty {
            stopExpiryTick()
        } else {
            startExpiryTick()
        }
    }

    private func startListeningToPresence(groupId: String) {
        presenceListeners[groupId] = firestoreService.listenToPresence(groupId: groupId) { [weak self] presences in
            Task { @MainActor in
                // Ignore callbacks that land after the listener was removed
                guard let self, self.presenceListeners[groupId] != nil else { return }
                self.applyPresence(presences, for: groupId)
            }
        }
    }

    /// Stores a fresh set of presence docs and republishes the filtered summary.
    private func applyPresence(_ presences: [Presence], for groupId: String) {
        rawPresenceByGroup[groupId] = presences
        publishSummary(for: groupId)
        checkOutOwnStalePresence(in: groupId)
        clearOthersLapsedPresences(in: groupId)
    }

    private func publishSummary(for groupId: String, now: Date = Date()) {
        let active = (rawPresenceByGroup[groupId] ?? []).filter { $0.isActive(at: now) }
        presenceByGroup[groupId] = GroupPresenceSummary(
            groupId: groupId,
            presentCount: active.count,
            presentMembers: active
        )
    }

    // MARK: - Expiry Tick

    private func startExpiryTick() {
        guard expiryTickTask == nil else { return }
        expiryTickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.expiryTickInterval ?? 30) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.dropLapsedPresences()
            }
        }
    }

    private func stopExpiryTick() {
        expiryTickTask?.cancel()
        expiryTickTask = nil
    }

    /// Removes people whose check-in lapsed since the last snapshot, so the UI
    /// updates on its own instead of waiting for Firestore to send something.
    private func dropLapsedPresences() {
        let now = Date()
        for (groupId, summary) in presenceByGroup
        where summary.presentMembers.contains(where: { !$0.isActive(at: now) }) {
            publishSummary(for: groupId, now: now)
            checkOutOwnStalePresence(in: groupId)
            clearOthersLapsedPresences(in: groupId)
        }
    }

    func refreshPresence(groupId: String) async {
        // On a failed fetch keep what we have rather than showing "No one here"
        if let presences = await firestoreService.fetchPresenceForGroup(groupId: groupId) {
            applyPresence(presences, for: groupId)
        }

        // Sync updated presence data to widget
        WidgetDataService.shared.syncToWidget()
    }

    func getPresenceSummary(for groupId: String) -> GroupPresenceSummary? {
        return presenceByGroup[groupId]
    }

    func isUserPresent(groupId: String, userId: String) -> Bool {
        guard let summary = presenceByGroup[groupId] else { return false }
        return summary.presentMembers.contains { $0.userId == userId }
    }

    // MARK: - Helpers

    /// Returns the number of members currently present in a group, excluding the current user.
    /// Used before check-out to determine how many people remain after the user leaves.
    private func countRemainingMembers(groupId: String) -> Int {
        guard let summary = presenceByGroup[groupId] else { return 0 }
        let currentUserId = firestoreService.currentUser?.id
        return summary.presentMembers.filter { $0.userId != currentUserId }.count
    }

    // MARK: - Display Formatting

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
            } else if names.count == 1 {
                return names[0]
            } else if names.count == 2 {
                return "\(names[0]) and \(names[1])"
            } else {
                let firstTwo = names.prefix(2).joined(separator: ", ")
                let remaining = names.count - 2
                return "\(firstTwo) and \(remaining) \(remaining == 1 ? "other" : "others")"
            }
        }
    }
}
