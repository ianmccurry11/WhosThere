//
//  RegressionChecklistTests.swift
//  WhosThereiosTests
//
//  Created by Claude on 2/5/26.
//

import XCTest
@testable import WhosThereios

// MARK: - RegressionCheck Model Tests

final class RegressionCheckTests: XCTestCase {

    func testDefaultInitialization() {
        let check = RegressionCheck(
            testId: "REG-AUTH-001",
            category: .authentication,
            title: "Test auth",
            description: "Test anonymous auth",
            expectedResult: "User signed in"
        )

        XCTAssertFalse(check.id.uuidString.isEmpty)
        XCTAssertEqual(check.testId, "REG-AUTH-001")
        XCTAssertEqual(check.category, .authentication)
        XCTAssertEqual(check.title, "Test auth")
        XCTAssertEqual(check.description, "Test anonymous auth")
        XCTAssertEqual(check.expectedResult, "User signed in")
        XCTAssertEqual(check.status, .notRun)
        XCTAssertEqual(check.notes, "")
        XCTAssertNil(check.lastRunAt)
        XCTAssertNil(check.lastRunBy)
    }

    func testCustomInitialization() {
        let date = Date()
        let check = RegressionCheck(
            testId: "REG-GRP-001",
            category: .groups,
            title: "Create group",
            description: "Create with default boundary",
            expectedResult: "Group created",
            status: .passed,
            notes: "Works fine",
            lastRunAt: date,
            lastRunBy: "Tester"
        )

        XCTAssertEqual(check.status, .passed)
        XCTAssertEqual(check.notes, "Works fine")
        XCTAssertEqual(check.lastRunAt, date)
        XCTAssertEqual(check.lastRunBy, "Tester")
    }

    func testCodable() throws {
        let original = RegressionCheck(
            testId: "REG-LOC-001",
            category: .locationPresence,
            title: "Manual check-in",
            description: "Tap check-in button",
            expectedResult: "Presence created",
            status: .failed,
            notes: "Button unresponsive"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RegressionCheck.self, from: data)

        XCTAssertEqual(decoded.testId, original.testId)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.status, original.status)
        XCTAssertEqual(decoded.notes, original.notes)
    }
}

// MARK: - CheckStatus Tests

final class CheckStatusTests: XCTestCase {

    func testAllCases() {
        let allCases = CheckStatus.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.notRun))
        XCTAssertTrue(allCases.contains(.passed))
        XCTAssertTrue(allCases.contains(.failed))
        XCTAssertTrue(allCases.contains(.blocked))
        XCTAssertTrue(allCases.contains(.skipped))
    }

    func testRawValues() {
        XCTAssertEqual(CheckStatus.notRun.rawValue, "Not Run")
        XCTAssertEqual(CheckStatus.passed.rawValue, "Passed")
        XCTAssertEqual(CheckStatus.failed.rawValue, "Failed")
        XCTAssertEqual(CheckStatus.blocked.rawValue, "Blocked")
        XCTAssertEqual(CheckStatus.skipped.rawValue, "Skipped")
    }

    func testIcons() {
        XCTAssertEqual(CheckStatus.notRun.icon, "circle.dashed")
        XCTAssertEqual(CheckStatus.passed.icon, "checkmark.circle.fill")
        XCTAssertEqual(CheckStatus.failed.icon, "xmark.circle.fill")
        XCTAssertEqual(CheckStatus.blocked.icon, "nosign")
        XCTAssertEqual(CheckStatus.skipped.icon, "arrow.right.circle")
    }

    func testColorNames() {
        XCTAssertEqual(CheckStatus.notRun.colorName, "gray")
        XCTAssertEqual(CheckStatus.passed.colorName, "green")
        XCTAssertEqual(CheckStatus.failed.colorName, "red")
        XCTAssertEqual(CheckStatus.blocked.colorName, "orange")
        XCTAssertEqual(CheckStatus.skipped.colorName, "purple")
    }

    func testCodable() throws {
        for status in CheckStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(CheckStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }
}

// MARK: - RegressionCategory Tests

final class RegressionCategoryTests: XCTestCase {

    func testAllCases() {
        let allCases = RegressionCategory.allCases
        XCTAssertEqual(allCases.count, 8)
    }

    func testRawValues() {
        XCTAssertEqual(RegressionCategory.authentication.rawValue, "Authentication")
        XCTAssertEqual(RegressionCategory.groups.rawValue, "Groups")
        XCTAssertEqual(RegressionCategory.locationPresence.rawValue, "Location & Presence")
        XCTAssertEqual(RegressionCategory.chat.rawValue, "Chat")
        XCTAssertEqual(RegressionCategory.achievements.rawValue, "Achievements")
        XCTAssertEqual(RegressionCategory.analytics.rawValue, "Analytics")
        XCTAssertEqual(RegressionCategory.offline.rawValue, "Offline")
        XCTAssertEqual(RegressionCategory.watchApp.rawValue, "Watch App")
    }

    func testIcons() {
        XCTAssertEqual(RegressionCategory.authentication.icon, "person.circle")
        XCTAssertEqual(RegressionCategory.groups.icon, "person.3")
        XCTAssertEqual(RegressionCategory.locationPresence.icon, "location")
        XCTAssertEqual(RegressionCategory.chat.icon, "bubble.left")
        XCTAssertEqual(RegressionCategory.achievements.icon, "trophy")
        XCTAssertEqual(RegressionCategory.analytics.icon, "chart.bar")
        XCTAssertEqual(RegressionCategory.offline.icon, "wifi.slash")
        XCTAssertEqual(RegressionCategory.watchApp.icon, "applewatch")
    }

    func testTestCounts() {
        XCTAssertEqual(RegressionCategory.authentication.testCount, 5)
        XCTAssertEqual(RegressionCategory.groups.testCount, 8)
        XCTAssertEqual(RegressionCategory.locationPresence.testCount, 10)
        XCTAssertEqual(RegressionCategory.chat.testCount, 5)
        XCTAssertEqual(RegressionCategory.achievements.testCount, 5)
        XCTAssertEqual(RegressionCategory.analytics.testCount, 5)
        XCTAssertEqual(RegressionCategory.offline.testCount, 4)
        XCTAssertEqual(RegressionCategory.watchApp.testCount, 3)

        // Verify total matches default checks
        let total = RegressionCategory.allCases.reduce(0) { $0 + $1.testCount }
        XCTAssertEqual(total, 45)
    }

    func testCodable() throws {
        for category in RegressionCategory.allCases {
            let data = try JSONEncoder().encode(category)
            let decoded = try JSONDecoder().decode(RegressionCategory.self, from: data)
            XCTAssertEqual(decoded, category)
        }
    }
}

// MARK: - RegressionRun Tests

final class RegressionRunTests: XCTestCase {

    func testDefaultInitialization() {
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "42",
            deviceName: "iPhone 17 Pro",
            osVersion: "18.0"
        )

        XCTAssertEqual(run.appVersion, "1.0")
        XCTAssertEqual(run.buildNumber, "42")
        XCTAssertEqual(run.deviceName, "iPhone 17 Pro")
        XCTAssertEqual(run.osVersion, "18.0")
        XCTAssertNil(run.completedAt)
        XCTAssertTrue(run.checks.isEmpty)
        XCTAssertEqual(run.notes, "")
    }

    func testCountsWithNoChecks() {
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0"
        )

        XCTAssertEqual(run.totalChecks, 0)
        XCTAssertEqual(run.passedCount, 0)
        XCTAssertEqual(run.failedCount, 0)
        XCTAssertEqual(run.blockedCount, 0)
        XCTAssertEqual(run.skippedCount, 0)
        XCTAssertEqual(run.notRunCount, 0)
    }

    func testCountsWithMixedStatuses() {
        var checks = [
            makeCheck(status: .passed),
            makeCheck(status: .passed),
            makeCheck(status: .passed),
            makeCheck(status: .failed),
            makeCheck(status: .blocked),
            makeCheck(status: .skipped),
            makeCheck(status: .notRun),
            makeCheck(status: .notRun),
        ]

        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: checks
        )

        XCTAssertEqual(run.totalChecks, 8)
        XCTAssertEqual(run.passedCount, 3)
        XCTAssertEqual(run.failedCount, 1)
        XCTAssertEqual(run.blockedCount, 1)
        XCTAssertEqual(run.skippedCount, 1)
        XCTAssertEqual(run.notRunCount, 2)
    }

    func testIsComplete() {
        let incompleteRun = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [makeCheck(status: .passed), makeCheck(status: .notRun)]
        )
        XCTAssertFalse(incompleteRun.isComplete)

        let completeRun = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [makeCheck(status: .passed), makeCheck(status: .failed)]
        )
        XCTAssertTrue(completeRun.isComplete)
    }

    func testPassRate() {
        // 3 passed, 1 failed, 1 skipped = 3/4 = 75% (skipped excluded)
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [
                makeCheck(status: .passed),
                makeCheck(status: .passed),
                makeCheck(status: .passed),
                makeCheck(status: .failed),
                makeCheck(status: .skipped),
            ]
        )

        XCTAssertEqual(run.passRate, 75.0, accuracy: 0.01)
    }

    func testPassRateWithNoExecuted() {
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [makeCheck(status: .notRun), makeCheck(status: .skipped)]
        )

        XCTAssertEqual(run.passRate, 0)
    }

    func testOverallStatusPassed() {
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [makeCheck(status: .passed), makeCheck(status: .passed)]
        )

        XCTAssertEqual(run.overallStatus, .passed)
    }

    func testOverallStatusFailed() {
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [makeCheck(status: .passed), makeCheck(status: .failed)]
        )

        XCTAssertEqual(run.overallStatus, .failed)
    }

    func testOverallStatusBlocked() {
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [makeCheck(status: .passed), makeCheck(status: .blocked)]
        )

        XCTAssertEqual(run.overallStatus, .blocked)
    }

    func testOverallStatusInProgress() {
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [makeCheck(status: .passed), makeCheck(status: .notRun)]
        )

        XCTAssertEqual(run.overallStatus, .inProgress)
    }

    func testFailedTakesPrecedenceOverBlocked() {
        let run = RegressionRun(
            appVersion: "1.0",
            buildNumber: "1",
            deviceName: "Test",
            osVersion: "18.0",
            checks: [makeCheck(status: .failed), makeCheck(status: .blocked)]
        )

        XCTAssertEqual(run.overallStatus, .failed)
    }

    func testCodable() throws {
        let run = RegressionRun(
            appVersion: "2.0",
            buildNumber: "100",
            deviceName: "iPhone SE",
            osVersion: "17.5",
            checks: [makeCheck(status: .passed), makeCheck(status: .failed)],
            notes: "Test run"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(run)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RegressionRun.self, from: data)

        XCTAssertEqual(decoded.appVersion, run.appVersion)
        XCTAssertEqual(decoded.buildNumber, run.buildNumber)
        XCTAssertEqual(decoded.deviceName, run.deviceName)
        XCTAssertEqual(decoded.osVersion, run.osVersion)
        XCTAssertEqual(decoded.checks.count, 2)
        XCTAssertEqual(decoded.notes, "Test run")
    }

    // MARK: - Helpers

    private func makeCheck(status: CheckStatus) -> RegressionCheck {
        RegressionCheck(
            testId: "TEST-\(UUID().uuidString.prefix(4))",
            category: .authentication,
            title: "Test",
            description: "Test description",
            expectedResult: "Expected",
            status: status
        )
    }
}

// MARK: - RunStatus Tests

final class RunStatusTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(RunStatus.inProgress.rawValue, "In Progress")
        XCTAssertEqual(RunStatus.passed.rawValue, "Passed")
        XCTAssertEqual(RunStatus.failed.rawValue, "Failed")
        XCTAssertEqual(RunStatus.blocked.rawValue, "Blocked")
    }

    func testIcons() {
        XCTAssertEqual(RunStatus.inProgress.icon, "clock")
        XCTAssertEqual(RunStatus.passed.icon, "checkmark.seal.fill")
        XCTAssertEqual(RunStatus.failed.icon, "xmark.seal.fill")
        XCTAssertEqual(RunStatus.blocked.icon, "exclamationmark.triangle.fill")
    }

    func testColorNames() {
        XCTAssertEqual(RunStatus.inProgress.colorName, "blue")
        XCTAssertEqual(RunStatus.passed.colorName, "green")
        XCTAssertEqual(RunStatus.failed.colorName, "red")
        XCTAssertEqual(RunStatus.blocked.colorName, "orange")
    }
}

// MARK: - RegressionSummary Tests

final class RegressionSummaryTests: XCTestCase {

    func testDefaultValues() {
        let summary = RegressionSummary()

        XCTAssertEqual(summary.totalRuns, 0)
        XCTAssertNil(summary.lastRunDate)
        XCTAssertEqual(summary.lastPassRate, 0)
        XCTAssertEqual(summary.averagePassRate, 0)
        XCTAssertEqual(summary.totalTestsExecuted, 0)
        XCTAssertTrue(summary.commonFailures.isEmpty)
    }

    func testMutability() {
        var summary = RegressionSummary()
        summary.totalRuns = 5
        summary.lastPassRate = 95.0
        summary.averagePassRate = 90.0
        summary.totalTestsExecuted = 225
        summary.commonFailures = ["REG-AUTH-001", "REG-LOC-003"]

        XCTAssertEqual(summary.totalRuns, 5)
        XCTAssertEqual(summary.lastPassRate, 95.0)
        XCTAssertEqual(summary.averagePassRate, 90.0)
        XCTAssertEqual(summary.totalTestsExecuted, 225)
        XCTAssertEqual(summary.commonFailures.count, 2)
    }
}

// MARK: - Default Checks Tests

final class DefaultChecksTests: XCTestCase {

    func testDefaultCheckCount() {
        let checks = RegressionChecklistService.defaultChecks()
        XCTAssertEqual(checks.count, 45)
    }

    func testUniqueTestIds() {
        let checks = RegressionChecklistService.defaultChecks()
        let ids = Set(checks.map { $0.testId })
        XCTAssertEqual(ids.count, checks.count, "All test IDs should be unique")
    }

    func testAllCategoriesRepresented() {
        let checks = RegressionChecklistService.defaultChecks()
        let categories = Set(checks.map { $0.category })

        for category in RegressionCategory.allCases {
            XCTAssertTrue(categories.contains(category), "\(category.rawValue) should be represented")
        }
    }

    func testCategoryCountsMatch() {
        let checks = RegressionChecklistService.defaultChecks()

        for category in RegressionCategory.allCases {
            let count = checks.filter { $0.category == category }.count
            XCTAssertEqual(count, category.testCount, "\(category.rawValue) should have \(category.testCount) checks, got \(count)")
        }
    }

    func testAllChecksStartNotRun() {
        let checks = RegressionChecklistService.defaultChecks()

        for check in checks {
            XCTAssertEqual(check.status, .notRun, "\(check.testId) should start as not run")
        }
    }

    func testAllChecksHaveContent() {
        let checks = RegressionChecklistService.defaultChecks()

        for check in checks {
            XCTAssertFalse(check.testId.isEmpty, "Test ID should not be empty")
            XCTAssertFalse(check.title.isEmpty, "\(check.testId) should have a title")
            XCTAssertFalse(check.description.isEmpty, "\(check.testId) should have a description")
            XCTAssertFalse(check.expectedResult.isEmpty, "\(check.testId) should have expected result")
        }
    }

    func testTestIdFormat() {
        let checks = RegressionChecklistService.defaultChecks()

        for check in checks {
            XCTAssertTrue(check.testId.hasPrefix("REG-"), "\(check.testId) should start with REG-")
            let parts = check.testId.split(separator: "-")
            XCTAssertEqual(parts.count, 3, "\(check.testId) should have 3 parts (REG-CAT-NNN)")
        }
    }

    func testAuthenticationChecks() {
        let checks = RegressionChecklistService.defaultChecks().filter { $0.category == .authentication }
        XCTAssertEqual(checks.count, 5)
        XCTAssertTrue(checks.allSatisfy { $0.testId.hasPrefix("REG-AUTH-") })
    }

    func testGroupChecks() {
        let checks = RegressionChecklistService.defaultChecks().filter { $0.category == .groups }
        XCTAssertEqual(checks.count, 8)
        XCTAssertTrue(checks.allSatisfy { $0.testId.hasPrefix("REG-GRP-") })
    }

    func testLocationChecks() {
        let checks = RegressionChecklistService.defaultChecks().filter { $0.category == .locationPresence }
        XCTAssertEqual(checks.count, 10)
        XCTAssertTrue(checks.allSatisfy { $0.testId.hasPrefix("REG-LOC-") })
    }

    func testChatChecks() {
        let checks = RegressionChecklistService.defaultChecks().filter { $0.category == .chat }
        XCTAssertEqual(checks.count, 5)
        XCTAssertTrue(checks.allSatisfy { $0.testId.hasPrefix("REG-CHAT-") })
    }

    func testAchievementChecks() {
        let checks = RegressionChecklistService.defaultChecks().filter { $0.category == .achievements }
        XCTAssertEqual(checks.count, 5)
        XCTAssertTrue(checks.allSatisfy { $0.testId.hasPrefix("REG-ACH-") })
    }

    func testAnalyticsChecks() {
        let checks = RegressionChecklistService.defaultChecks().filter { $0.category == .analytics }
        XCTAssertEqual(checks.count, 5)
        XCTAssertTrue(checks.allSatisfy { $0.testId.hasPrefix("REG-ANA-") })
    }

    func testOfflineChecks() {
        let checks = RegressionChecklistService.defaultChecks().filter { $0.category == .offline }
        XCTAssertEqual(checks.count, 4)
        XCTAssertTrue(checks.allSatisfy { $0.testId.hasPrefix("REG-OFF-") })
    }

    func testWatchChecks() {
        let checks = RegressionChecklistService.defaultChecks().filter { $0.category == .watchApp }
        XCTAssertEqual(checks.count, 3)
        XCTAssertTrue(checks.allSatisfy { $0.testId.hasPrefix("REG-WCH-") })
    }
}

// MARK: - RegressionChecklistService Tests

@MainActor
final class RegressionChecklistServiceTests: XCTestCase {

    private var service: RegressionChecklistService!

    override func setUp() {
        super.setUp()
        service = RegressionChecklistService.shared
        service.clearAllData()
    }

    override func tearDown() {
        service.clearAllData()
        super.tearDown()
    }

    func testStartNewRun() {
        XCTAssertNil(service.currentRun)

        service.startNewRun()

        XCTAssertNotNil(service.currentRun)
        XCTAssertEqual(service.currentRun?.checks.count, 45)
        XCTAssertNil(service.currentRun?.completedAt)
    }

    func testStartNewRunPopulatesDeviceInfo() {
        service.startNewRun()

        let run = service.currentRun
        XCTAssertNotNil(run)
        XCTAssertFalse(run!.deviceName.isEmpty)
        XCTAssertFalse(run!.osVersion.isEmpty)
    }

    func testUpdateCheckStatus() {
        service.startNewRun()

        guard let checkId = service.currentRun?.checks.first?.id else {
            XCTFail("No checks found")
            return
        }

        service.updateCheckStatus(checkId, status: .passed)

        let updatedCheck = service.currentRun?.checks.first { $0.id == checkId }
        XCTAssertEqual(updatedCheck?.status, .passed)
        XCTAssertNotNil(updatedCheck?.lastRunAt)
    }

    func testUpdateCheckStatusWithNotes() {
        service.startNewRun()

        guard let checkId = service.currentRun?.checks.first?.id else {
            XCTFail("No checks found")
            return
        }

        service.updateCheckStatus(checkId, status: .failed, notes: "Button not responding")

        let updatedCheck = service.currentRun?.checks.first { $0.id == checkId }
        XCTAssertEqual(updatedCheck?.status, .failed)
        XCTAssertEqual(updatedCheck?.notes, "Button not responding")
    }

    func testAddNotes() {
        service.startNewRun()

        guard let checkId = service.currentRun?.checks.first?.id else {
            XCTFail("No checks found")
            return
        }

        service.addNotes(to: checkId, notes: "Tested on simulator")

        let updatedCheck = service.currentRun?.checks.first { $0.id == checkId }
        XCTAssertEqual(updatedCheck?.notes, "Tested on simulator")
    }

    func testCompleteCurrentRun() {
        service.startNewRun()
        XCTAssertTrue(service.completedRuns.isEmpty)

        service.completeCurrentRun(notes: "All done")

        XCTAssertNil(service.currentRun)
        XCTAssertEqual(service.completedRuns.count, 1)
        XCTAssertEqual(service.completedRuns.first?.notes, "All done")
        XCTAssertNotNil(service.completedRuns.first?.completedAt)
    }

    func testAbandonCurrentRun() {
        service.startNewRun()
        XCTAssertNotNil(service.currentRun)

        service.abandonCurrentRun()

        XCTAssertNil(service.currentRun)
        XCTAssertTrue(service.completedRuns.isEmpty)
    }

    func testDeleteRun() {
        service.startNewRun()
        service.completeCurrentRun()

        XCTAssertEqual(service.completedRuns.count, 1)

        let run = service.completedRuns.first!
        service.deleteRun(run)

        XCTAssertTrue(service.completedRuns.isEmpty)
    }

    func testChecksForCategory() {
        service.startNewRun()

        let authChecks = service.checksForCategory(.authentication)
        XCTAssertEqual(authChecks.count, 5)
        XCTAssertTrue(authChecks.allSatisfy { $0.category == .authentication })

        let groupChecks = service.checksForCategory(.groups)
        XCTAssertEqual(groupChecks.count, 8)
    }

    func testChecksForCategoryWithNoActiveRun() {
        let checks = service.checksForCategory(.authentication)
        XCTAssertTrue(checks.isEmpty)
    }

    func testSummaryWithNoRuns() {
        let summary = service.summary

        XCTAssertEqual(summary.totalRuns, 0)
        XCTAssertNil(summary.lastRunDate)
        XCTAssertEqual(summary.lastPassRate, 0)
        XCTAssertEqual(summary.averagePassRate, 0)
        XCTAssertEqual(summary.totalTestsExecuted, 0)
        XCTAssertTrue(summary.commonFailures.isEmpty)
    }

    func testSummaryWithCompletedRuns() {
        // Create and complete a run with some statuses
        service.startNewRun()

        // Mark first 10 checks as passed
        let checks = service.currentRun!.checks
        for i in 0..<10 {
            service.updateCheckStatus(checks[i].id, status: .passed)
        }
        // Mark next 2 as failed
        service.updateCheckStatus(checks[10].id, status: .failed)
        service.updateCheckStatus(checks[11].id, status: .failed)

        service.completeCurrentRun()

        let summary = service.summary
        XCTAssertEqual(summary.totalRuns, 1)
        XCTAssertNotNil(summary.lastRunDate)
        XCTAssertGreaterThan(summary.totalTestsExecuted, 0)
    }

    func testMultipleCompletedRuns() {
        // Run 1
        service.startNewRun()
        service.completeCurrentRun()

        // Run 2
        service.startNewRun()
        service.completeCurrentRun()

        XCTAssertEqual(service.completedRuns.count, 2)
        XCTAssertEqual(service.summary.totalRuns, 2)
    }

    func testClearAllData() {
        service.startNewRun()
        service.completeCurrentRun()
        service.startNewRun()

        XCTAssertNotNil(service.currentRun)
        XCTAssertEqual(service.completedRuns.count, 1)

        service.clearAllData()

        XCTAssertNil(service.currentRun)
        XCTAssertTrue(service.completedRuns.isEmpty)
    }

    func testUpdateCheckStatusWithNoActiveRun() {
        // Should not crash
        let randomId = UUID()
        service.updateCheckStatus(randomId, status: .passed)
        XCTAssertNil(service.currentRun)
    }

    func testCompleteRunWithNoActiveRun() {
        // Should not crash
        service.completeCurrentRun()
        XCTAssertTrue(service.completedRuns.isEmpty)
    }

    func testRunsOrderedByRecency() {
        service.startNewRun()
        service.completeCurrentRun(notes: "Run 1")

        service.startNewRun()
        service.completeCurrentRun(notes: "Run 2")

        XCTAssertEqual(service.completedRuns.first?.notes, "Run 2")
        XCTAssertEqual(service.completedRuns.last?.notes, "Run 1")
    }
}
