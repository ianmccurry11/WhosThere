//
//  AnalyticsService.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import Foundation
import Combine

/// Service for tracking and validating analytics events
/// Provides both Firebase Analytics integration and local event buffering for validation
@MainActor
final class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    // MARK: - Published Properties

    /// Recent events for dashboard display (last 100)
    @Published var recentEvents: [AnalyticsEvent] = []

    /// Aggregated counts by event name
    @Published var eventCounts: [String: Int] = [:]

    /// Session identifier for current app session
    @Published private(set) var sessionId: String

    /// Session start time
    @Published private(set) var sessionStartTime: Date

    // MARK: - Private Properties

    private let maxRecentEvents = 100
    private let userDefaultsKey = "analytics_event_counts"

    // MARK: - Initialization

    private init() {
        self.sessionId = UUID().uuidString
        self.sessionStartTime = Date()
        loadPersistedCounts()
    }

    // MARK: - Event Tracking

    /// Track an analytics event
    /// - Parameters:
    ///   - name: The event name (use AnalyticsEventName for type safety)
    ///   - parameters: Optional event parameters
    func track(_ name: AnalyticsEventName, parameters: [String: String] = [:]) {
        track(name.rawValue, parameters: parameters)
    }

    /// Track an analytics event with raw string name
    /// - Parameters:
    ///   - name: The raw event name string
    ///   - parameters: Optional event parameters
    func track(_ name: String, parameters: [String: String] = [:]) {
        let event = AnalyticsEvent(
            name: name,
            parameters: parameters,
            sessionId: sessionId
        )

        // Add to recent events (maintaining max size)
        recentEvents.insert(event, at: 0)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeLast()
        }

        // Update counts
        eventCounts[name, default: 0] += 1
        persistCounts()

        // Send to Firebase Analytics
        sendToFirebase(event)

        // Debug logging
        #if DEBUG
        print("[Analytics] \(name): \(parameters)")
        #endif
    }

    // MARK: - Convenience Tracking Methods

    /// Track app launch
    func trackAppLaunch(launchType: String = "cold") {
        track(.appLaunch, parameters: AnalyticsParameters.with { params in
            params.add("launch_type", launchType)
            params.add("session_id", sessionId)
        })
    }

    /// Track screen view
    func trackScreenView(_ screenName: String) {
        track(.screenView, parameters: AnalyticsParameters.with { params in
            params.add("screen_name", screenName)
        })
    }

    /// Track sign-in attempt
    func trackSignInAttempted(method: String) {
        track(.signInAttempted, parameters: AnalyticsParameters.with { params in
            params.add("method", method)
        })
    }

    /// Track sign-in success
    func trackSignInSuccess(method: String, isNewUser: Bool) {
        track(.signInSuccess, parameters: AnalyticsParameters.with { params in
            params.add("method", method)
            params.add("is_new_user", isNewUser)
        })
    }

    /// Track sign-in failure
    func trackSignInFailure(method: String, errorCode: String) {
        track(.signInFailure, parameters: AnalyticsParameters.with { params in
            params.add("method", method)
            params.add("error_code", errorCode)
        })
    }

    /// Track sign out
    func trackSignOut() {
        track(.signOut)
    }

    /// Track group creation
    func trackGroupCreated(groupId: String, hasBoundary: Bool, isPublic: Bool) {
        track(.groupCreated, parameters: AnalyticsParameters.with { params in
            params.add("group_id", groupId)
            params.add("has_boundary", hasBoundary)
            params.add("is_public", isPublic)
        })
    }

    /// Track group joined
    func trackGroupJoined(groupId: String, joinMethod: String) {
        track(.groupJoined, parameters: AnalyticsParameters.with { params in
            params.add("group_id", groupId)
            params.add("join_method", joinMethod)
        })
    }

    /// Track group left
    func trackGroupLeft(groupId: String, wasOwner: Bool) {
        track(.groupLeft, parameters: AnalyticsParameters.with { params in
            params.add("group_id", groupId)
            params.add("was_owner", wasOwner)
        })
    }

    /// Track group deleted
    func trackGroupDeleted(groupId: String, memberCount: Int) {
        track(.groupDeleted, parameters: AnalyticsParameters.with { params in
            params.add("group_id", groupId)
            params.add("member_count", memberCount)
        })
    }

    /// Track check-in
    func trackCheckIn(groupId: String, isManual: Bool) {
        track(.checkIn, parameters: AnalyticsParameters.with { params in
            params.add("group_id", groupId)
            params.add("is_manual", isManual)
        })
    }

    /// Track check-out
    func trackCheckOut(groupId: String, isManual: Bool, durationMinutes: Int) {
        track(.checkOut, parameters: AnalyticsParameters.with { params in
            params.add("group_id", groupId)
            params.add("is_manual", isManual)
            params.add("duration_minutes", durationMinutes)
        })
    }

    /// Track auto check-out
    func trackAutoCheckOut(groupId: String, reason: String) {
        track(.autoCheckOut, parameters: AnalyticsParameters.with { params in
            params.add("group_id", groupId)
            params.add("reason", reason)
        })
    }

    /// Track achievement unlocked
    func trackAchievementUnlocked(achievementType: String, points: Int) {
        track(.achievementUnlocked, parameters: AnalyticsParameters.with { params in
            params.add("achievement_type", achievementType)
            params.add("points", points)
        })
    }

    /// Track message sent
    func trackMessageSent(groupId: String, messageLength: Int) {
        track(.messageSent, parameters: AnalyticsParameters.with { params in
            params.add("group_id", groupId)
            params.add("message_length", messageLength)
        })
    }

    /// Track error
    func trackError(errorType: String, context: String, message: String? = nil) {
        track(.errorOccurred, parameters: AnalyticsParameters.with { params in
            params.add("error_type", errorType)
            params.add("context", context)
            params.add("message", message)
        })
    }

    // MARK: - Dashboard Data

    /// Get events since a specific date
    func getEventsSince(_ date: Date) -> [AnalyticsEvent] {
        return recentEvents.filter { $0.timestamp >= date }
    }

    /// Get aggregated counts
    func getAggregatedCounts() -> [String: Int] {
        return eventCounts
    }

    /// Get events filtered by name
    func getEvents(named name: String) -> [AnalyticsEvent] {
        return recentEvents.filter { $0.name == name }
    }

    /// Get events filtered by name enum
    func getEvents(named name: AnalyticsEventName) -> [AnalyticsEvent] {
        return getEvents(named: name.rawValue)
    }

    /// Clear all events (for testing)
    func clearEvents() {
        recentEvents.removeAll()
    }

    /// Reset session (start new session)
    func resetSession() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        clearEvents()
    }

    /// Get session duration in seconds
    var sessionDuration: TimeInterval {
        return Date().timeIntervalSince(sessionStartTime)
    }

    /// Get discrepancies between local counts and expected values
    /// This compares analytics counts with actual app state
    func getDiscrepancies(
        actualCheckIns: Int,
        actualGroupsCreated: Int,
        actualAchievements: Int
    ) -> [AnalyticsDiscrepancy] {
        var discrepancies: [AnalyticsDiscrepancy] = []

        let trackedCheckIns = eventCounts[AnalyticsEventName.checkIn.rawValue, default: 0]
        if trackedCheckIns != actualCheckIns {
            discrepancies.append(AnalyticsDiscrepancy(
                eventName: AnalyticsEventName.checkIn.rawValue,
                localCount: trackedCheckIns,
                expectedCount: actualCheckIns,
                description: "Check-in count mismatch: tracked \(trackedCheckIns), actual \(actualCheckIns)"
            ))
        }

        let trackedGroupsCreated = eventCounts[AnalyticsEventName.groupCreated.rawValue, default: 0]
        if trackedGroupsCreated != actualGroupsCreated {
            discrepancies.append(AnalyticsDiscrepancy(
                eventName: AnalyticsEventName.groupCreated.rawValue,
                localCount: trackedGroupsCreated,
                expectedCount: actualGroupsCreated,
                description: "Groups created mismatch: tracked \(trackedGroupsCreated), actual \(actualGroupsCreated)"
            ))
        }

        let trackedAchievements = eventCounts[AnalyticsEventName.achievementUnlocked.rawValue, default: 0]
        if trackedAchievements != actualAchievements {
            discrepancies.append(AnalyticsDiscrepancy(
                eventName: AnalyticsEventName.achievementUnlocked.rawValue,
                localCount: trackedAchievements,
                expectedCount: actualAchievements,
                description: "Achievements mismatch: tracked \(trackedAchievements), actual \(actualAchievements)"
            ))
        }

        return discrepancies
    }

    /// Export events as JSON string
    func exportEventsAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(recentEvents)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "Error encoding events: \(error.localizedDescription)"
        }
    }

    // MARK: - Private Methods

    private func sendToFirebase(_ event: AnalyticsEvent) {
        // Note: FirebaseAnalytics is not included in this project.
        // Events are stored locally for validation dashboard.
        // To enable Firebase Analytics, add the FirebaseAnalytics package
        // and uncomment the following:
        //
        // var firebaseParams: [String: Any] = event.parameters
        // firebaseParams["session_id"] = event.sessionId
        // firebaseParams["client_timestamp"] = event.timestamp.timeIntervalSince1970
        // Analytics.logEvent(event.name, parameters: firebaseParams)

        // For now, events are captured locally only
    }

    private func persistCounts() {
        UserDefaults.standard.set(eventCounts, forKey: userDefaultsKey)
    }

    private func loadPersistedCounts() {
        if let counts = UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: Int] {
            eventCounts = counts
        }
    }

    /// Reset persisted counts (for testing or new user)
    func resetPersistedCounts() {
        eventCounts.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
