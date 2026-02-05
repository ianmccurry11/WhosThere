//
//  RegressionCheck.swift
//  WhosThereios
//
//  Created by Claude on 2/5/26.
//

import Foundation

// MARK: - Regression Check Model

/// Represents a single regression test check item
struct RegressionCheck: Identifiable, Codable {
    let id: UUID
    let testId: String // e.g., "REG-AUTH-001"
    let category: RegressionCategory
    let title: String
    let description: String
    let expectedResult: String
    var status: CheckStatus
    var notes: String
    var lastRunAt: Date?
    var lastRunBy: String?

    init(
        id: UUID = UUID(),
        testId: String,
        category: RegressionCategory,
        title: String,
        description: String,
        expectedResult: String,
        status: CheckStatus = .notRun,
        notes: String = "",
        lastRunAt: Date? = nil,
        lastRunBy: String? = nil
    ) {
        self.id = id
        self.testId = testId
        self.category = category
        self.title = title
        self.description = description
        self.expectedResult = expectedResult
        self.status = status
        self.notes = notes
        self.lastRunAt = lastRunAt
        self.lastRunBy = lastRunBy
    }
}

// MARK: - Check Status

enum CheckStatus: String, Codable, CaseIterable {
    case notRun = "Not Run"
    case passed = "Passed"
    case failed = "Failed"
    case blocked = "Blocked"
    case skipped = "Skipped"

    var icon: String {
        switch self {
        case .notRun: return "circle.dashed"
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .blocked: return "nosign"
        case .skipped: return "arrow.right.circle"
        }
    }

    var colorName: String {
        switch self {
        case .notRun: return "gray"
        case .passed: return "green"
        case .failed: return "red"
        case .blocked: return "orange"
        case .skipped: return "purple"
        }
    }
}

// MARK: - Regression Category

enum RegressionCategory: String, Codable, CaseIterable {
    case authentication = "Authentication"
    case groups = "Groups"
    case locationPresence = "Location & Presence"
    case chat = "Chat"
    case achievements = "Achievements"
    case analytics = "Analytics"
    case offline = "Offline"
    case watchApp = "Watch App"

    var icon: String {
        switch self {
        case .authentication: return "person.circle"
        case .groups: return "person.3"
        case .locationPresence: return "location"
        case .chat: return "bubble.left"
        case .achievements: return "trophy"
        case .analytics: return "chart.bar"
        case .offline: return "wifi.slash"
        case .watchApp: return "applewatch"
        }
    }

    var testCount: Int {
        switch self {
        case .authentication: return 5
        case .groups: return 8
        case .locationPresence: return 10
        case .chat: return 5
        case .achievements: return 5
        case .analytics: return 5
        case .offline: return 4
        case .watchApp: return 3
        }
    }
}

// MARK: - Regression Run

/// Represents a complete regression test run (a snapshot of all checks)
struct RegressionRun: Identifiable, Codable {
    let id: UUID
    let startedAt: Date
    var completedAt: Date?
    let appVersion: String
    let buildNumber: String
    let deviceName: String
    let osVersion: String
    var checks: [RegressionCheck]
    var notes: String

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        appVersion: String,
        buildNumber: String,
        deviceName: String,
        osVersion: String,
        checks: [RegressionCheck] = [],
        notes: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.deviceName = deviceName
        self.osVersion = osVersion
        self.checks = checks
        self.notes = notes
    }

    var totalChecks: Int { checks.count }
    var passedCount: Int { checks.filter { $0.status == .passed }.count }
    var failedCount: Int { checks.filter { $0.status == .failed }.count }
    var blockedCount: Int { checks.filter { $0.status == .blocked }.count }
    var skippedCount: Int { checks.filter { $0.status == .skipped }.count }
    var notRunCount: Int { checks.filter { $0.status == .notRun }.count }

    var isComplete: Bool { notRunCount == 0 }

    var passRate: Double {
        let executed = totalChecks - notRunCount - skippedCount
        guard executed > 0 else { return 0 }
        return Double(passedCount) / Double(executed) * 100
    }

    var overallStatus: RunStatus {
        if failedCount > 0 { return .failed }
        if blockedCount > 0 { return .blocked }
        if notRunCount > 0 { return .inProgress }
        return .passed
    }
}

// MARK: - Run Status

enum RunStatus: String, Codable {
    case inProgress = "In Progress"
    case passed = "Passed"
    case failed = "Failed"
    case blocked = "Blocked"

    var icon: String {
        switch self {
        case .inProgress: return "clock"
        case .passed: return "checkmark.seal.fill"
        case .failed: return "xmark.seal.fill"
        case .blocked: return "exclamationmark.triangle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .inProgress: return "blue"
        case .passed: return "green"
        case .failed: return "red"
        case .blocked: return "orange"
        }
    }
}

// MARK: - Regression Summary

struct RegressionSummary {
    var totalRuns: Int = 0
    var lastRunDate: Date?
    var lastPassRate: Double = 0
    var averagePassRate: Double = 0
    var totalTestsExecuted: Int = 0
    var commonFailures: [String] = []
}
