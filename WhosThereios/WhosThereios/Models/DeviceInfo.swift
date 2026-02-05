//
//  DeviceInfo.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import Foundation
import UIKit

// MARK: - Device Info Model

/// Captures device and OS information for test matrix tracking
struct DeviceInfo: Identifiable, Codable, Equatable {
    let id: UUID
    let deviceModel: String
    let deviceName: String
    let systemName: String
    let systemVersion: String
    let isSimulator: Bool
    let screenWidth: Double
    let screenHeight: Double
    let screenScale: Double
    let capturedAt: Date

    init(
        id: UUID = UUID(),
        deviceModel: String,
        deviceName: String,
        systemName: String,
        systemVersion: String,
        isSimulator: Bool,
        screenWidth: Double,
        screenHeight: Double,
        screenScale: Double,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.deviceModel = deviceModel
        self.deviceName = deviceName
        self.systemName = systemName
        self.systemVersion = systemVersion
        self.isSimulator = isSimulator
        self.screenWidth = screenWidth
        self.screenHeight = screenHeight
        self.screenScale = screenScale
        self.capturedAt = capturedAt
    }

    /// Unique key for deduplication (model + OS version)
    var uniqueKey: String {
        "\(deviceModel)_\(systemVersion)"
    }

    /// Display string for the device
    var displayName: String {
        if isSimulator {
            return "\(deviceName) (Simulator)"
        }
        return deviceName
    }

    /// Screen size category
    var screenCategory: ScreenCategory {
        let diagonal = sqrt(screenWidth * screenWidth + screenHeight * screenHeight)
        if diagonal < 700 {
            return .compact // iPhone SE, mini
        } else if diagonal < 900 {
            return .regular // Standard iPhones
        } else if diagonal < 1200 {
            return .large // iPhone Pro Max, Plus
        } else {
            return .tablet // iPad
        }
    }

    /// Capture current device info
    @MainActor
    static func current() -> DeviceInfo {
        let device = UIDevice.current
        let screen = UIScreen.main

        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }

        let isSimulator = modelCode.contains("x86") || modelCode.contains("arm64") && ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil

        return DeviceInfo(
            deviceModel: modelCode,
            deviceName: mapModelToName(modelCode),
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            isSimulator: isSimulator,
            screenWidth: screen.bounds.width,
            screenHeight: screen.bounds.height,
            screenScale: screen.scale
        )
    }

    /// Map device model codes to human-readable names
    private static func mapModelToName(_ model: String) -> String {
        // Check for simulator
        if let simulatorName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] {
            return simulatorName
        }

        // Common iPhone models
        let modelMap: [String: String] = [
            // iPhone 17 series
            "iPhone18,1": "iPhone 17",
            "iPhone18,2": "iPhone 17 Plus",
            "iPhone18,3": "iPhone 17 Pro",
            "iPhone18,4": "iPhone 17 Pro Max",
            // iPhone 16 series
            "iPhone17,1": "iPhone 16",
            "iPhone17,2": "iPhone 16 Plus",
            "iPhone17,3": "iPhone 16 Pro",
            "iPhone17,4": "iPhone 16 Pro Max",
            // iPhone 15 series
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            // iPhone 14 series
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            // iPhone SE
            "iPhone14,6": "iPhone SE (3rd gen)",
            // iPad models
            "iPad14,1": "iPad Pro 11-inch",
            "iPad14,2": "iPad Pro 12.9-inch",
        ]

        return modelMap[model] ?? model
    }
}

// MARK: - Screen Category

enum ScreenCategory: String, Codable, CaseIterable {
    case compact = "Compact"
    case regular = "Regular"
    case large = "Large"
    case tablet = "Tablet"

    var icon: String {
        switch self {
        case .compact: return "iphone.gen1"
        case .regular: return "iphone"
        case .large: return "iphone.gen3"
        case .tablet: return "ipad"
        }
    }
}

// MARK: - Test Session

/// Represents a testing session on a specific device
struct TestSession: Identifiable, Codable {
    let id: UUID
    let deviceInfo: DeviceInfo
    let startTime: Date
    var endTime: Date?
    var screensVisited: [String]
    var actionsPerformed: Int
    var errorsEncountered: Int
    var notes: String

    init(
        id: UUID = UUID(),
        deviceInfo: DeviceInfo,
        startTime: Date = Date(),
        endTime: Date? = nil,
        screensVisited: [String] = [],
        actionsPerformed: Int = 0,
        errorsEncountered: Int = 0,
        notes: String = ""
    ) {
        self.id = id
        self.deviceInfo = deviceInfo
        self.startTime = startTime
        self.endTime = endTime
        self.screensVisited = screensVisited
        self.actionsPerformed = actionsPerformed
        self.errorsEncountered = errorsEncountered
        self.notes = notes
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var isActive: Bool {
        endTime == nil
    }
}

// MARK: - Test Matrix Entry

/// Represents a tested device/OS combination in the matrix
struct TestMatrixEntry: Identifiable, Codable {
    let id: UUID
    let deviceModel: String
    let deviceName: String
    let osVersion: String
    let isSimulator: Bool
    let screenCategory: ScreenCategory
    var testCount: Int
    var lastTestedAt: Date
    var status: TestStatus
    var issues: [String]

    init(
        id: UUID = UUID(),
        deviceModel: String,
        deviceName: String,
        osVersion: String,
        isSimulator: Bool,
        screenCategory: ScreenCategory,
        testCount: Int = 1,
        lastTestedAt: Date = Date(),
        status: TestStatus = .passed,
        issues: [String] = []
    ) {
        self.id = id
        self.deviceModel = deviceModel
        self.deviceName = deviceName
        self.osVersion = osVersion
        self.isSimulator = isSimulator
        self.screenCategory = screenCategory
        self.testCount = testCount
        self.lastTestedAt = lastTestedAt
        self.status = status
        self.issues = issues
    }

    /// Create from DeviceInfo
    init(from deviceInfo: DeviceInfo) {
        self.id = UUID()
        self.deviceModel = deviceInfo.deviceModel
        self.deviceName = deviceInfo.deviceName
        self.osVersion = deviceInfo.systemVersion
        self.isSimulator = deviceInfo.isSimulator
        self.screenCategory = deviceInfo.screenCategory
        self.testCount = 1
        self.lastTestedAt = deviceInfo.capturedAt
        self.status = .passed
        self.issues = []
    }

    var uniqueKey: String {
        "\(deviceModel)_\(osVersion)"
    }
}

// MARK: - Test Status

enum TestStatus: String, Codable, CaseIterable {
    case passed = "Passed"
    case failed = "Failed"
    case partial = "Partial"
    case untested = "Untested"

    var color: String {
        switch self {
        case .passed: return "green"
        case .failed: return "red"
        case .partial: return "orange"
        case .untested: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .partial: return "exclamationmark.circle.fill"
        case .untested: return "circle.dashed"
        }
    }
}

// MARK: - Coverage Summary

struct TestCoverageSummary {
    var totalDevices: Int = 0
    var physicalDevices: Int = 0
    var simulators: Int = 0
    var uniqueOSVersions: Int = 0
    var screenCategories: Set<ScreenCategory> = []
    var passedCount: Int = 0
    var failedCount: Int = 0
    var partialCount: Int = 0

    var coveragePercentage: Double {
        guard totalDevices > 0 else { return 0 }
        return Double(passedCount) / Double(totalDevices) * 100
    }

    var hasCompleteCoverage: Bool {
        // Check if we have at least one device per screen category
        screenCategories.count >= 3 && physicalDevices >= 1
    }
}
