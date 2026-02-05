//
//  RegressionChecklistService.swift
//  WhosThereios
//
//  Created by Claude on 2/5/26.
//

import Combine
import Foundation
import UIKit

/// Service for managing regression test checklists and runs
@MainActor
final class RegressionChecklistService: ObservableObject {
    static let shared = RegressionChecklistService()

    // MARK: - Published Properties

    /// Current active regression run
    @Published var currentRun: RegressionRun?

    /// All completed regression runs
    @Published var completedRuns: [RegressionRun] = []

    // MARK: - Private Properties

    private let runsKey = "regression_runs"

    // MARK: - Initialization

    private init() {
        loadPersistedData()
    }

    // MARK: - Default Checklist

    /// Generate the default set of regression checks
    static func defaultChecks() -> [RegressionCheck] {
        var checks: [RegressionCheck] = []

        // Authentication (5 tests)
        checks.append(contentsOf: [
            RegressionCheck(
                testId: "REG-AUTH-001",
                category: .authentication,
                title: "Anonymous sign-in on fresh install",
                description: "Delete and reinstall app, verify anonymous auth completes",
                expectedResult: "User is signed in and can access main screen"
            ),
            RegressionCheck(
                testId: "REG-AUTH-002",
                category: .authentication,
                title: "Apple Sign-In completes",
                description: "Sign in with Apple ID and verify account creation",
                expectedResult: "Apple credential linked, display name populated"
            ),
            RegressionCheck(
                testId: "REG-AUTH-003",
                category: .authentication,
                title: "Sign out clears local data",
                description: "Sign out and verify all local state is cleared",
                expectedResult: "Returns to sign-in screen, no cached user data"
            ),
            RegressionCheck(
                testId: "REG-AUTH-004",
                category: .authentication,
                title: "Auth token expiration handled",
                description: "Force token expiration and verify graceful recovery",
                expectedResult: "Token refreshed automatically or re-auth prompted"
            ),
            RegressionCheck(
                testId: "REG-AUTH-005",
                category: .authentication,
                title: "Re-authentication preserves data",
                description: "Sign out and sign back in, verify data persistence",
                expectedResult: "Groups, achievements, and settings preserved"
            ),
        ])

        // Groups (8 tests)
        checks.append(contentsOf: [
            RegressionCheck(
                testId: "REG-GRP-001",
                category: .groups,
                title: "Create group with default boundary",
                description: "Create a new group using the default boundary radius",
                expectedResult: "Group created, appears in list, geofence registered"
            ),
            RegressionCheck(
                testId: "REG-GRP-002",
                category: .groups,
                title: "Create group with custom boundary",
                description: "Create a group and adjust the boundary on the map",
                expectedResult: "Custom boundary saved, correct radius shown"
            ),
            RegressionCheck(
                testId: "REG-GRP-003",
                category: .groups,
                title: "Join group via invite code",
                description: "Use another user's invite code to join their group",
                expectedResult: "Successfully joined, group appears in list"
            ),
            RegressionCheck(
                testId: "REG-GRP-004",
                category: .groups,
                title: "Join public group from search",
                description: "Find and join a public group from the browse view",
                expectedResult: "Group joined, presence tracking begins"
            ),
            RegressionCheck(
                testId: "REG-GRP-005",
                category: .groups,
                title: "Leave group as member",
                description: "Leave a group where you are not the owner",
                expectedResult: "Removed from group, geofence unregistered"
            ),
            RegressionCheck(
                testId: "REG-GRP-006",
                category: .groups,
                title: "Delete group as owner",
                description: "Delete a group you own with active members",
                expectedResult: "Group deleted, all members removed"
            ),
            RegressionCheck(
                testId: "REG-GRP-007",
                category: .groups,
                title: "Edit group settings",
                description: "Change group name, visibility, and auto-checkout timer",
                expectedResult: "Settings saved and reflected for all members"
            ),
            RegressionCheck(
                testId: "REG-GRP-008",
                category: .groups,
                title: "Edit group boundary",
                description: "Adjust the geofence boundary in group settings",
                expectedResult: "New boundary saved, geofence updated"
            ),
        ])

        // Location & Presence (10 tests)
        checks.append(contentsOf: [
            RegressionCheck(
                testId: "REG-LOC-001",
                category: .locationPresence,
                title: "Manual check-in works",
                description: "Tap check-in button while inside group boundary",
                expectedResult: "Presence created, status shown as checked in"
            ),
            RegressionCheck(
                testId: "REG-LOC-002",
                category: .locationPresence,
                title: "Manual check-out works",
                description: "Tap check-out button while checked in",
                expectedResult: "Presence removed, status shown as checked out"
            ),
            RegressionCheck(
                testId: "REG-LOC-003",
                category: .locationPresence,
                title: "Auto check-in on geofence entry",
                description: "Walk into group boundary with Always permission",
                expectedResult: "Automatically checked in, notification received"
            ),
            RegressionCheck(
                testId: "REG-LOC-004",
                category: .locationPresence,
                title: "Auto check-out on geofence exit",
                description: "Walk out of group boundary",
                expectedResult: "Automatically checked out after delay"
            ),
            RegressionCheck(
                testId: "REG-LOC-005",
                category: .locationPresence,
                title: "Auto-checkout timer",
                description: "Check in and wait for auto-checkout timer to fire",
                expectedResult: "Checked out after configured timeout"
            ),
            RegressionCheck(
                testId: "REG-LOC-006",
                category: .locationPresence,
                title: "Stale presence cleanup",
                description: "Verify presences older than 10 hours are cleaned up",
                expectedResult: "Stale presences removed automatically"
            ),
            RegressionCheck(
                testId: "REG-LOC-007",
                category: .locationPresence,
                title: "Manual override prevents auto check-out",
                description: "Manually check in, verify auto-checkout is suppressed",
                expectedResult: "Manual check-in not auto-removed by geofence exit"
            ),
            RegressionCheck(
                testId: "REG-LOC-008",
                category: .locationPresence,
                title: "Location permission request flow",
                description: "Verify location permission dialog and fallback",
                expectedResult: "Permission granted or settings redirect offered"
            ),
            RegressionCheck(
                testId: "REG-LOC-009",
                category: .locationPresence,
                title: "Presence visible to other members",
                description: "Check in on device A, verify presence on device B",
                expectedResult: "Other members see presence in real-time"
            ),
            RegressionCheck(
                testId: "REG-LOC-010",
                category: .locationPresence,
                title: "Throttling prevents rapid updates",
                description: "Attempt rapid check-in/out within 30 seconds",
                expectedResult: "Updates throttled, no excessive Firestore writes"
            ),
        ])

        // Chat (5 tests)
        checks.append(contentsOf: [
            RegressionCheck(
                testId: "REG-CHAT-001",
                category: .chat,
                title: "Send message in group",
                description: "Type and send a message in group chat",
                expectedResult: "Message appears in chat, timestamp shown"
            ),
            RegressionCheck(
                testId: "REG-CHAT-002",
                category: .chat,
                title: "Receive message from other user",
                description: "Have another user send a message, verify receipt",
                expectedResult: "Message appears in real-time with sender info"
            ),
            RegressionCheck(
                testId: "REG-CHAT-003",
                category: .chat,
                title: "Rate limiting enforced",
                description: "Send messages rapidly, verify rate limit kicks in",
                expectedResult: "Messages blocked after rate limit exceeded"
            ),
            RegressionCheck(
                testId: "REG-CHAT-004",
                category: .chat,
                title: "Message character limit",
                description: "Try to send a message exceeding character limit",
                expectedResult: "Message truncated or blocked with error"
            ),
            RegressionCheck(
                testId: "REG-CHAT-005",
                category: .chat,
                title: "Messages load on group open",
                description: "Open group chat and verify message history loads",
                expectedResult: "Recent messages displayed, older scrollable"
            ),
        ])

        // Achievements (5 tests)
        checks.append(contentsOf: [
            RegressionCheck(
                testId: "REG-ACH-001",
                category: .achievements,
                title: "First check-in achievement unlocks",
                description: "Perform first-ever check-in for the user",
                expectedResult: "First Steps achievement unlocked with notification"
            ),
            RegressionCheck(
                testId: "REG-ACH-002",
                category: .achievements,
                title: "Streak tracking increments",
                description: "Check in on consecutive days and verify streak",
                expectedResult: "Streak counter increments correctly"
            ),
            RegressionCheck(
                testId: "REG-ACH-003",
                category: .achievements,
                title: "Early bird achievement",
                description: "Check in before 7 AM",
                expectedResult: "Early Bird achievement unlocked"
            ),
            RegressionCheck(
                testId: "REG-ACH-004",
                category: .achievements,
                title: "Achievement notification shows",
                description: "Unlock any achievement, verify notification UI",
                expectedResult: "Achievement banner shown with confetti"
            ),
            RegressionCheck(
                testId: "REG-ACH-005",
                category: .achievements,
                title: "Achievement points accumulate",
                description: "Unlock multiple achievements, check total points",
                expectedResult: "Points sum correctly in profile"
            ),
        ])

        // Analytics (5 tests)
        checks.append(contentsOf: [
            RegressionCheck(
                testId: "REG-ANA-001",
                category: .analytics,
                title: "App launch event fires",
                description: "Open app and check analytics dashboard for launch event",
                expectedResult: "app_launch event with correct launch_type"
            ),
            RegressionCheck(
                testId: "REG-ANA-002",
                category: .analytics,
                title: "Sign-in events tracked",
                description: "Sign in and verify analytics captures the event",
                expectedResult: "sign_in_success event with method parameter"
            ),
            RegressionCheck(
                testId: "REG-ANA-003",
                category: .analytics,
                title: "Check-in events include parameters",
                description: "Check in and verify event parameters in dashboard",
                expectedResult: "check_in event with group_id and is_manual"
            ),
            RegressionCheck(
                testId: "REG-ANA-004",
                category: .analytics,
                title: "Error events captured",
                description: "Trigger an error and verify it appears in analytics",
                expectedResult: "error_occurred event with type and context"
            ),
            RegressionCheck(
                testId: "REG-ANA-005",
                category: .analytics,
                title: "Dashboard counts match actions",
                description: "Perform known actions, verify counts in dashboard",
                expectedResult: "Event counts match performed actions exactly"
            ),
        ])

        // Offline (4 tests)
        checks.append(contentsOf: [
            RegressionCheck(
                testId: "REG-OFF-001",
                category: .offline,
                title: "App launches offline",
                description: "Enable airplane mode, launch app",
                expectedResult: "App launches with cached data, no crash"
            ),
            RegressionCheck(
                testId: "REG-OFF-002",
                category: .offline,
                title: "Offline indicator shows",
                description: "Go offline and verify status banner appears",
                expectedResult: "Offline banner shown prominently"
            ),
            RegressionCheck(
                testId: "REG-OFF-003",
                category: .offline,
                title: "Operations queue when offline",
                description: "Try to check in while offline",
                expectedResult: "Action queued or clear error message shown"
            ),
            RegressionCheck(
                testId: "REG-OFF-004",
                category: .offline,
                title: "Sync completes when online",
                description: "Go online after queued operations",
                expectedResult: "Queued operations complete, data consistent"
            ),
        ])

        // Watch App (3 tests)
        checks.append(contentsOf: [
            RegressionCheck(
                testId: "REG-WCH-001",
                category: .watchApp,
                title: "Watch connects to phone",
                description: "Open Watch app and verify connection to iPhone",
                expectedResult: "Connection established, data synced"
            ),
            RegressionCheck(
                testId: "REG-WCH-002",
                category: .watchApp,
                title: "Presence syncs to watch",
                description: "Check in on phone, verify presence on watch",
                expectedResult: "Watch shows current presence status"
            ),
            RegressionCheck(
                testId: "REG-WCH-003",
                category: .watchApp,
                title: "Check-in from watch works",
                description: "Use Watch to check into a group",
                expectedResult: "Check-in reflected on phone and Firestore"
            ),
        ])

        return checks
    }

    // MARK: - Run Management

    /// Start a new regression test run
    func startNewRun() {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        let run = RegressionRun(
            appVersion: appVersion,
            buildNumber: buildNumber,
            deviceName: device.name,
            osVersion: device.systemVersion,
            checks: Self.defaultChecks()
        )

        currentRun = run
        persistData()
    }

    /// Update the status of a check in the current run
    func updateCheckStatus(_ checkId: UUID, status: CheckStatus, notes: String = "") {
        guard var run = currentRun else { return }

        if let index = run.checks.firstIndex(where: { $0.id == checkId }) {
            run.checks[index].status = status
            run.checks[index].lastRunAt = Date()
            if !notes.isEmpty {
                run.checks[index].notes = notes
            }
        }

        currentRun = run
        persistData()
    }

    /// Add notes to a check
    func addNotes(to checkId: UUID, notes: String) {
        guard var run = currentRun else { return }

        if let index = run.checks.firstIndex(where: { $0.id == checkId }) {
            run.checks[index].notes = notes
        }

        currentRun = run
        persistData()
    }

    /// Complete the current run
    func completeCurrentRun(notes: String = "") {
        guard var run = currentRun else { return }

        run.completedAt = Date()
        run.notes = notes
        completedRuns.insert(run, at: 0)
        currentRun = nil
        persistData()
    }

    /// Abandon the current run
    func abandonCurrentRun() {
        currentRun = nil
        persistData()
    }

    /// Delete a completed run
    func deleteRun(_ run: RegressionRun) {
        completedRuns.removeAll { $0.id == run.id }
        persistData()
    }

    // MARK: - Queries

    /// Get checks filtered by category for the current run
    func checksForCategory(_ category: RegressionCategory) -> [RegressionCheck] {
        guard let run = currentRun else { return [] }
        return run.checks.filter { $0.category == category }
    }

    /// Get summary statistics across all runs
    var summary: RegressionSummary {
        var s = RegressionSummary()
        s.totalRuns = completedRuns.count

        if let lastRun = completedRuns.first {
            s.lastRunDate = lastRun.completedAt ?? lastRun.startedAt
            s.lastPassRate = lastRun.passRate
        }

        if !completedRuns.isEmpty {
            let totalRate = completedRuns.reduce(0.0) { $0 + $1.passRate }
            s.averagePassRate = totalRate / Double(completedRuns.count)
            s.totalTestsExecuted = completedRuns.reduce(0) { $0 + $1.totalChecks - $1.notRunCount }
        }

        // Find common failures
        var failureCounts: [String: Int] = [:]
        for run in completedRuns {
            for check in run.checks where check.status == .failed {
                failureCounts[check.testId, default: 0] += 1
            }
        }
        s.commonFailures = failureCounts
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0.key }

        return s
    }

    // MARK: - Persistence

    private func persistData() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var allRuns = completedRuns
        if let current = currentRun {
            allRuns.insert(current, at: 0)
        }

        if let data = try? encoder.encode(allRuns) {
            UserDefaults.standard.set(data, forKey: runsKey)
        }
    }

    private func loadPersistedData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let data = UserDefaults.standard.data(forKey: runsKey),
              let runs = try? decoder.decode([RegressionRun].self, from: data) else { return }

        // Separate current (incomplete) run from completed runs
        let incomplete = runs.filter { $0.completedAt == nil }
        let completed = runs.filter { $0.completedAt != nil }

        currentRun = incomplete.first
        completedRuns = completed
    }

    /// Clear all data
    func clearAllData() {
        currentRun = nil
        completedRuns.removeAll()
        UserDefaults.standard.removeObject(forKey: runsKey)
    }
}
