//
//  AnalyticsEvent.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import Foundation

/// Represents a single analytics event with metadata
struct AnalyticsEvent: Identifiable, Codable {
    let id: UUID
    let name: String
    let parameters: [String: String]
    let timestamp: Date
    let sessionId: String

    init(name: String, parameters: [String: String] = [:], sessionId: String) {
        self.id = UUID()
        self.name = name
        self.parameters = parameters
        self.timestamp = Date()
        self.sessionId = sessionId
    }
}

/// Represents a discrepancy between local event counts and expected values
struct AnalyticsDiscrepancy: Identifiable {
    let id: UUID
    let eventName: String
    let localCount: Int
    let expectedCount: Int
    let description: String

    init(eventName: String, localCount: Int, expectedCount: Int, description: String) {
        self.id = UUID()
        self.eventName = eventName
        self.localCount = localCount
        self.expectedCount = expectedCount
        self.description = description
    }
}

/// Predefined analytics event names for type safety
enum AnalyticsEventName: String {
    // App lifecycle
    case appLaunch = "app_launch"
    case appBackground = "app_background"
    case appForeground = "app_foreground"

    // Authentication
    case signInAttempted = "sign_in_attempted"
    case signInSuccess = "sign_in_success"
    case signInFailure = "sign_in_failure"
    case signOut = "sign_out"

    // Groups
    case groupCreated = "group_created"
    case groupJoined = "group_joined"
    case groupLeft = "group_left"
    case groupDeleted = "group_deleted"
    case groupSettingsUpdated = "group_settings_updated"

    // Presence
    case checkIn = "check_in"
    case checkOut = "check_out"
    case autoCheckOut = "auto_check_out"

    // Achievements
    case achievementUnlocked = "achievement_unlocked"

    // Chat
    case messageSent = "message_sent"

    // Navigation
    case screenView = "screen_view"

    // Errors
    case errorOccurred = "error_occurred"

    // Friends
    case friendRequestSent = "friend_request_sent"
    case friendRequestAccepted = "friend_request_accepted"
    case friendRemoved = "friend_removed"
}

/// Helper to build event parameters
struct AnalyticsParameters {
    private var params: [String: String] = [:]

    mutating func add(_ key: String, _ value: String?) {
        if let value = value {
            params[key] = value
        }
    }

    mutating func add(_ key: String, _ value: Int) {
        params[key] = String(value)
    }

    mutating func add(_ key: String, _ value: Bool) {
        params[key] = value ? "true" : "false"
    }

    mutating func add(_ key: String, _ value: Double) {
        params[key] = String(format: "%.2f", value)
    }

    func build() -> [String: String] {
        return params
    }

    static func with(_ block: (inout AnalyticsParameters) -> Void) -> [String: String] {
        var params = AnalyticsParameters()
        block(&params)
        return params.build()
    }
}
