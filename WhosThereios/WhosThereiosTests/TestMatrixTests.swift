//
//  TestMatrixTests.swift
//  WhosThereiosTests
//
//  Created by Claude on 2/4/26.
//

import XCTest
@testable import WhosThereios

// MARK: - DeviceInfo Tests

final class DeviceInfoTests: XCTestCase {

    func testDeviceInfoInitialization() {
        let deviceInfo = DeviceInfo(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        XCTAssertEqual(deviceInfo.deviceModel, "iPhone17,3")
        XCTAssertEqual(deviceInfo.deviceName, "iPhone 16 Pro")
        XCTAssertEqual(deviceInfo.systemName, "iOS")
        XCTAssertEqual(deviceInfo.systemVersion, "18.0")
        XCTAssertFalse(deviceInfo.isSimulator)
        XCTAssertEqual(deviceInfo.screenWidth, 393)
        XCTAssertEqual(deviceInfo.screenHeight, 852)
        XCTAssertEqual(deviceInfo.screenScale, 3.0)
        XCTAssertNotNil(deviceInfo.id)
        XCTAssertNotNil(deviceInfo.capturedAt)
    }

    func testUniqueKey() {
        let device1 = DeviceInfo(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        let device2 = DeviceInfo(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            systemName: "iOS",
            systemVersion: "18.1",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        XCTAssertEqual(device1.uniqueKey, "iPhone17,3_18.0")
        XCTAssertEqual(device2.uniqueKey, "iPhone17,3_18.1")
        XCTAssertNotEqual(device1.uniqueKey, device2.uniqueKey)
    }

    func testDisplayNameWithSimulator() {
        let simulatorDevice = DeviceInfo(
            deviceModel: "arm64",
            deviceName: "iPhone 17 Pro",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: true,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        XCTAssertEqual(simulatorDevice.displayName, "iPhone 17 Pro (Simulator)")
    }

    func testDisplayNameWithPhysicalDevice() {
        let physicalDevice = DeviceInfo(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        XCTAssertEqual(physicalDevice.displayName, "iPhone 16 Pro")
    }

    func testScreenCategoryCompact() {
        let compactDevice = DeviceInfo(
            deviceModel: "iPhone14,6",
            deviceName: "iPhone SE",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 375,
            screenHeight: 667,
            screenScale: 2.0
        )

        XCTAssertEqual(compactDevice.screenCategory, .compact)
    }

    func testScreenCategoryRegular() {
        let regularDevice = DeviceInfo(
            deviceModel: "iPhone17,1",
            deviceName: "iPhone 16",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        XCTAssertEqual(regularDevice.screenCategory, .regular)
    }

    func testScreenCategoryLarge() {
        let largeDevice = DeviceInfo(
            deviceModel: "iPhone17,4",
            deviceName: "iPhone 16 Pro Max",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 430,
            screenHeight: 932,
            screenScale: 3.0
        )

        XCTAssertEqual(largeDevice.screenCategory, .large)
    }

    func testScreenCategoryTablet() {
        let tabletDevice = DeviceInfo(
            deviceModel: "iPad14,1",
            deviceName: "iPad Pro",
            systemName: "iPadOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 1024,
            screenHeight: 1366,
            screenScale: 2.0
        )

        XCTAssertEqual(tabletDevice.screenCategory, .tablet)
    }
}

// MARK: - ScreenCategory Tests

final class ScreenCategoryTests: XCTestCase {

    func testScreenCategoryRawValues() {
        XCTAssertEqual(ScreenCategory.compact.rawValue, "Compact")
        XCTAssertEqual(ScreenCategory.regular.rawValue, "Regular")
        XCTAssertEqual(ScreenCategory.large.rawValue, "Large")
        XCTAssertEqual(ScreenCategory.tablet.rawValue, "Tablet")
    }

    func testScreenCategoryIcons() {
        XCTAssertFalse(ScreenCategory.compact.icon.isEmpty)
        XCTAssertFalse(ScreenCategory.regular.icon.isEmpty)
        XCTAssertFalse(ScreenCategory.large.icon.isEmpty)
        XCTAssertFalse(ScreenCategory.tablet.icon.isEmpty)
    }
}

// MARK: - TestSession Tests

final class TestSessionTests: XCTestCase {

    func testSessionInitialization() {
        let deviceInfo = DeviceInfo(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        let session = TestSession(deviceInfo: deviceInfo)

        XCTAssertNotNil(session.id)
        XCTAssertEqual(session.deviceInfo.deviceModel, "iPhone17,3")
        XCTAssertNotNil(session.startTime)
        XCTAssertNil(session.endTime)
        XCTAssertTrue(session.screensVisited.isEmpty)
        XCTAssertEqual(session.actionsPerformed, 0)
        XCTAssertEqual(session.errorsEncountered, 0)
        XCTAssertTrue(session.notes.isEmpty)
    }

    func testSessionIsActive() {
        let deviceInfo = DeviceInfo(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        let activeSession = TestSession(deviceInfo: deviceInfo)
        XCTAssertTrue(activeSession.isActive)

        let endedSession = TestSession(deviceInfo: deviceInfo, endTime: Date())
        XCTAssertFalse(endedSession.isActive)
    }

    func testSessionDuration() {
        let deviceInfo = DeviceInfo(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        let startTime = Date().addingTimeInterval(-3600) // 1 hour ago
        let endTime = Date()

        let session = TestSession(
            deviceInfo: deviceInfo,
            startTime: startTime,
            endTime: endTime
        )

        XCTAssertEqual(session.duration, 3600, accuracy: 1)
    }
}

// MARK: - TestMatrixEntry Tests

final class TestMatrixEntryTests: XCTestCase {

    func testEntryInitialization() {
        let entry = TestMatrixEntry(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            osVersion: "18.0",
            isSimulator: false,
            screenCategory: .regular
        )

        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.deviceModel, "iPhone17,3")
        XCTAssertEqual(entry.deviceName, "iPhone 16 Pro")
        XCTAssertEqual(entry.osVersion, "18.0")
        XCTAssertFalse(entry.isSimulator)
        XCTAssertEqual(entry.screenCategory, .regular)
        XCTAssertEqual(entry.testCount, 1)
        XCTAssertEqual(entry.status, .passed)
        XCTAssertTrue(entry.issues.isEmpty)
    }

    func testEntryFromDeviceInfo() {
        let deviceInfo = DeviceInfo(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            systemName: "iOS",
            systemVersion: "18.0",
            isSimulator: false,
            screenWidth: 393,
            screenHeight: 852,
            screenScale: 3.0
        )

        let entry = TestMatrixEntry(from: deviceInfo)

        XCTAssertEqual(entry.deviceModel, deviceInfo.deviceModel)
        XCTAssertEqual(entry.deviceName, deviceInfo.deviceName)
        XCTAssertEqual(entry.osVersion, deviceInfo.systemVersion)
        XCTAssertEqual(entry.isSimulator, deviceInfo.isSimulator)
        XCTAssertEqual(entry.screenCategory, deviceInfo.screenCategory)
    }

    func testUniqueKey() {
        let entry = TestMatrixEntry(
            deviceModel: "iPhone17,3",
            deviceName: "iPhone 16 Pro",
            osVersion: "18.0",
            isSimulator: false,
            screenCategory: .regular
        )

        XCTAssertEqual(entry.uniqueKey, "iPhone17,3_18.0")
    }
}

// MARK: - TestStatus Tests

final class TestStatusTests: XCTestCase {

    func testStatusRawValues() {
        XCTAssertEqual(TestStatus.passed.rawValue, "Passed")
        XCTAssertEqual(TestStatus.failed.rawValue, "Failed")
        XCTAssertEqual(TestStatus.partial.rawValue, "Partial")
        XCTAssertEqual(TestStatus.untested.rawValue, "Untested")
    }

    func testStatusColors() {
        XCTAssertEqual(TestStatus.passed.color, "green")
        XCTAssertEqual(TestStatus.failed.color, "red")
        XCTAssertEqual(TestStatus.partial.color, "orange")
        XCTAssertEqual(TestStatus.untested.color, "gray")
    }

    func testStatusIcons() {
        XCTAssertFalse(TestStatus.passed.icon.isEmpty)
        XCTAssertFalse(TestStatus.failed.icon.isEmpty)
        XCTAssertFalse(TestStatus.partial.icon.isEmpty)
        XCTAssertFalse(TestStatus.untested.icon.isEmpty)
    }
}

// MARK: - TestCoverageSummary Tests

final class TestCoverageSummaryTests: XCTestCase {

    func testDefaultSummary() {
        let summary = TestCoverageSummary()

        XCTAssertEqual(summary.totalDevices, 0)
        XCTAssertEqual(summary.physicalDevices, 0)
        XCTAssertEqual(summary.simulators, 0)
        XCTAssertEqual(summary.uniqueOSVersions, 0)
        XCTAssertTrue(summary.screenCategories.isEmpty)
        XCTAssertEqual(summary.passedCount, 0)
        XCTAssertEqual(summary.failedCount, 0)
        XCTAssertEqual(summary.partialCount, 0)
    }

    func testCoveragePercentage() {
        var summary = TestCoverageSummary()
        summary.totalDevices = 10
        summary.passedCount = 8

        XCTAssertEqual(summary.coveragePercentage, 80.0)
    }

    func testCoveragePercentageWithZeroDevices() {
        let summary = TestCoverageSummary()
        XCTAssertEqual(summary.coveragePercentage, 0)
    }

    func testHasCompleteCoverage() {
        var completeSummary = TestCoverageSummary()
        completeSummary.screenCategories = [.compact, .regular, .large]
        completeSummary.physicalDevices = 1

        XCTAssertTrue(completeSummary.hasCompleteCoverage)

        var incompleteSummary = TestCoverageSummary()
        incompleteSummary.screenCategories = [.regular]
        incompleteSummary.physicalDevices = 0

        XCTAssertFalse(incompleteSummary.hasCompleteCoverage)
    }
}

// MARK: - TestMatrixService Tests

@MainActor
final class TestMatrixServiceTests: XCTestCase {

    var service: TestMatrixService!

    override func setUp() async throws {
        service = TestMatrixService.shared
        service.clearAllData()
    }

    override func tearDown() async throws {
        service.clearAllData()
    }

    func testServiceIsSingleton() {
        let service1 = TestMatrixService.shared
        let service2 = TestMatrixService.shared

        XCTAssertTrue(service1 === service2)
    }

    func testCaptureCurrentDevice() {
        service.captureCurrentDevice()

        XCTAssertNotNil(service.currentDevice)
        XCTAssertFalse(service.matrixEntries.isEmpty)
    }

    func testStartSession() {
        service.captureCurrentDevice()
        service.startSession()

        XCTAssertNotNil(service.currentSession)
        XCTAssertTrue(service.currentSession?.isActive ?? false)
        XCTAssertFalse(service.sessions.isEmpty)
    }

    func testEndSession() {
        service.captureCurrentDevice()
        service.startSession()

        XCTAssertNotNil(service.currentSession)

        service.endSession(notes: "Test notes")

        XCTAssertNil(service.currentSession)
        XCTAssertFalse(service.sessions.first?.isActive ?? true)
        XCTAssertEqual(service.sessions.first?.notes, "Test notes")
    }

    func testRecordScreenVisit() {
        service.captureCurrentDevice()
        service.startSession()

        service.recordScreenVisit("HomeView")
        service.recordScreenVisit("ProfileView")
        service.recordScreenVisit("HomeView") // Duplicate

        XCTAssertEqual(service.currentSession?.screensVisited.count, 2)
        XCTAssertTrue(service.currentSession?.screensVisited.contains("HomeView") ?? false)
        XCTAssertTrue(service.currentSession?.screensVisited.contains("ProfileView") ?? false)
    }

    func testRecordAction() {
        service.captureCurrentDevice()
        service.startSession()

        service.recordAction()
        service.recordAction()
        service.recordAction()

        XCTAssertEqual(service.currentSession?.actionsPerformed, 3)
    }

    func testRecordError() {
        service.captureCurrentDevice()
        service.startSession()

        service.recordError()

        XCTAssertEqual(service.currentSession?.errorsEncountered, 1)
    }

    func testUpdateStatus() {
        service.captureCurrentDevice()

        guard let entry = service.matrixEntries.first else {
            XCTFail("No entries found")
            return
        }

        service.updateStatus(for: entry, status: .failed)

        XCTAssertEqual(service.matrixEntries.first?.status, .failed)
    }

    func testAddIssue() {
        service.captureCurrentDevice()

        guard let entry = service.matrixEntries.first else {
            XCTFail("No entries found")
            return
        }

        service.addIssue(to: entry, issue: "Test issue")

        XCTAssertEqual(service.matrixEntries.first?.issues.count, 1)
        XCTAssertEqual(service.matrixEntries.first?.issues.first, "Test issue")
        XCTAssertEqual(service.matrixEntries.first?.status, .partial)
    }

    func testRemoveIssue() {
        service.captureCurrentDevice()

        guard let entry = service.matrixEntries.first else {
            XCTFail("No entries found")
            return
        }

        service.addIssue(to: entry, issue: "Issue 1")
        service.addIssue(to: entry, issue: "Issue 2")

        guard let updatedEntry = service.matrixEntries.first else {
            XCTFail("No entries found")
            return
        }

        service.removeIssue(from: updatedEntry, at: 0)

        XCTAssertEqual(service.matrixEntries.first?.issues.count, 1)
        XCTAssertEqual(service.matrixEntries.first?.issues.first, "Issue 2")
    }

    func testDeleteEntry() {
        service.captureCurrentDevice()

        XCTAssertFalse(service.matrixEntries.isEmpty)

        guard let entry = service.matrixEntries.first else {
            XCTFail("No entries found")
            return
        }

        service.deleteEntry(entry)

        XCTAssertTrue(service.matrixEntries.isEmpty)
    }

    func testCoverageSummary() {
        service.captureCurrentDevice()

        let summary = service.coverageSummary

        XCTAssertGreaterThan(summary.totalDevices, 0)
    }

    func testClearAllData() {
        service.captureCurrentDevice()
        service.startSession()

        service.clearAllData()

        XCTAssertTrue(service.matrixEntries.isEmpty)
        XCTAssertTrue(service.sessions.isEmpty)
        XCTAssertNil(service.currentSession)
    }

    func testExportAsJSON() {
        service.captureCurrentDevice()

        let json = service.exportAsJSON()

        XCTAssertFalse(json.isEmpty)
        XCTAssertTrue(json.contains("summary"))
        XCTAssertTrue(json.contains("entries"))
    }
}
