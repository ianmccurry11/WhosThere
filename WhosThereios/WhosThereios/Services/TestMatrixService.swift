//
//  TestMatrixService.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import Foundation
import Combine

/// Service for tracking device/OS test matrix coverage
/// Persists tested configurations and provides coverage analysis
@MainActor
final class TestMatrixService: ObservableObject {
    static let shared = TestMatrixService()

    // MARK: - Published Properties

    /// All tested device/OS configurations
    @Published var matrixEntries: [TestMatrixEntry] = []

    /// Current device info
    @Published var currentDevice: DeviceInfo?

    /// Current test session
    @Published var currentSession: TestSession?

    /// All test sessions
    @Published var sessions: [TestSession] = []

    // MARK: - Private Properties

    private let matrixKey = "test_matrix_entries"
    private let sessionsKey = "test_sessions"

    // MARK: - Initialization

    private init() {
        loadPersistedData()
        captureCurrentDevice()
    }

    // MARK: - Device Capture

    /// Capture and record current device info
    func captureCurrentDevice() {
        let deviceInfo = DeviceInfo.current()
        currentDevice = deviceInfo

        // Add or update matrix entry
        addOrUpdateEntry(from: deviceInfo)
    }

    /// Add or update a matrix entry from device info
    private func addOrUpdateEntry(from deviceInfo: DeviceInfo) {
        let key = deviceInfo.uniqueKey

        if let index = matrixEntries.firstIndex(where: { $0.uniqueKey == key }) {
            // Update existing entry
            matrixEntries[index].testCount += 1
            matrixEntries[index].lastTestedAt = Date()
        } else {
            // Add new entry
            let entry = TestMatrixEntry(from: deviceInfo)
            matrixEntries.append(entry)
        }

        persistData()
    }

    // MARK: - Test Sessions

    /// Start a new test session
    func startSession() {
        guard let device = currentDevice else {
            captureCurrentDevice()
            return
        }

        let session = TestSession(deviceInfo: device)
        currentSession = session
        sessions.insert(session, at: 0)
        persistData()
    }

    /// End the current test session
    func endSession(notes: String = "") {
        guard var session = currentSession else { return }

        session.endTime = Date()
        session.notes = notes

        // Update in sessions array
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }

        currentSession = nil
        persistData()
    }

    /// Record a screen visit in current session
    func recordScreenVisit(_ screenName: String) {
        guard var session = currentSession else { return }

        if !session.screensVisited.contains(screenName) {
            session.screensVisited.append(screenName)
        }
        session.actionsPerformed += 1

        // Update in sessions array
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        currentSession = session
    }

    /// Record an action in current session
    func recordAction() {
        guard var session = currentSession else { return }

        session.actionsPerformed += 1

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        currentSession = session
    }

    /// Record an error in current session
    func recordError() {
        guard var session = currentSession else { return }

        session.errorsEncountered += 1

        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
        currentSession = session

        // Update matrix entry status if errors encountered
        if let device = currentDevice,
           let entryIndex = matrixEntries.firstIndex(where: { $0.uniqueKey == device.uniqueKey }) {
            if matrixEntries[entryIndex].status == .passed {
                matrixEntries[entryIndex].status = .partial
            }
        }
    }

    // MARK: - Matrix Management

    /// Update status for a matrix entry
    func updateStatus(for entry: TestMatrixEntry, status: TestStatus) {
        guard let index = matrixEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        matrixEntries[index].status = status
        persistData()
    }

    /// Add an issue to a matrix entry
    func addIssue(to entry: TestMatrixEntry, issue: String) {
        guard let index = matrixEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        matrixEntries[index].issues.append(issue)
        if matrixEntries[index].status == .passed {
            matrixEntries[index].status = .partial
        }
        persistData()
    }

    /// Remove an issue from a matrix entry
    func removeIssue(from entry: TestMatrixEntry, at issueIndex: Int) {
        guard let entryIndex = matrixEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        guard issueIndex < matrixEntries[entryIndex].issues.count else { return }
        matrixEntries[entryIndex].issues.remove(at: issueIndex)
        persistData()
    }

    /// Delete a matrix entry
    func deleteEntry(_ entry: TestMatrixEntry) {
        matrixEntries.removeAll { $0.id == entry.id }
        persistData()
    }

    // MARK: - Coverage Analysis

    /// Get coverage summary
    var coverageSummary: TestCoverageSummary {
        var summary = TestCoverageSummary()

        summary.totalDevices = matrixEntries.count
        summary.physicalDevices = matrixEntries.filter { !$0.isSimulator }.count
        summary.simulators = matrixEntries.filter { $0.isSimulator }.count

        let osVersions = Set(matrixEntries.map { $0.osVersion })
        summary.uniqueOSVersions = osVersions.count

        summary.screenCategories = Set(matrixEntries.map { $0.screenCategory })

        summary.passedCount = matrixEntries.filter { $0.status == .passed }.count
        summary.failedCount = matrixEntries.filter { $0.status == .failed }.count
        summary.partialCount = matrixEntries.filter { $0.status == .partial }.count

        return summary
    }

    /// Get entries grouped by OS version
    var entriesByOSVersion: [String: [TestMatrixEntry]] {
        Dictionary(grouping: matrixEntries) { $0.osVersion }
    }

    /// Get entries grouped by screen category
    var entriesByScreenCategory: [ScreenCategory: [TestMatrixEntry]] {
        Dictionary(grouping: matrixEntries) { $0.screenCategory }
    }

    /// Get entries grouped by status
    var entriesByStatus: [TestStatus: [TestMatrixEntry]] {
        Dictionary(grouping: matrixEntries) { $0.status }
    }

    /// Check if current device has been tested before
    var isCurrentDeviceTested: Bool {
        guard let device = currentDevice else { return false }
        return matrixEntries.contains { $0.uniqueKey == device.uniqueKey }
    }

    /// Get recommended devices to test (not yet in matrix)
    var recommendedDevices: [String] {
        var recommended: [String] = []

        // Check for missing screen categories
        let testedCategories = Set(matrixEntries.map { $0.screenCategory })
        if !testedCategories.contains(.compact) {
            recommended.append("iPhone SE or mini (compact screen)")
        }
        if !testedCategories.contains(.large) {
            recommended.append("iPhone Pro Max (large screen)")
        }
        if !testedCategories.contains(.tablet) {
            recommended.append("iPad (tablet)")
        }

        // Check for physical device
        if matrixEntries.filter({ !$0.isSimulator }).isEmpty {
            recommended.append("Physical device (not simulator)")
        }

        return recommended
    }

    // MARK: - Persistence

    private func persistData() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let matrixData = try? encoder.encode(matrixEntries) {
            UserDefaults.standard.set(matrixData, forKey: matrixKey)
        }

        if let sessionsData = try? encoder.encode(sessions) {
            UserDefaults.standard.set(sessionsData, forKey: sessionsKey)
        }
    }

    private func loadPersistedData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let matrixData = UserDefaults.standard.data(forKey: matrixKey),
           let entries = try? decoder.decode([TestMatrixEntry].self, from: matrixData) {
            matrixEntries = entries
        }

        if let sessionsData = UserDefaults.standard.data(forKey: sessionsKey),
           let loadedSessions = try? decoder.decode([TestSession].self, from: sessionsData) {
            sessions = loadedSessions
        }
    }

    /// Clear all data (for testing)
    func clearAllData() {
        matrixEntries.removeAll()
        sessions.removeAll()
        currentSession = nil
        UserDefaults.standard.removeObject(forKey: matrixKey)
        UserDefaults.standard.removeObject(forKey: sessionsKey)
    }

    /// Export matrix as JSON
    func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let exportData: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "summary": [
                "totalDevices": coverageSummary.totalDevices,
                "physicalDevices": coverageSummary.physicalDevices,
                "simulators": coverageSummary.simulators,
                "uniqueOSVersions": coverageSummary.uniqueOSVersions,
                "coveragePercentage": coverageSummary.coveragePercentage
            ]
        ]

        // Encode entries separately
        if let entriesData = try? encoder.encode(matrixEntries),
           let entriesString = String(data: entriesData, encoding: .utf8) {
            return """
            {
              "summary": {
                "totalDevices": \(coverageSummary.totalDevices),
                "physicalDevices": \(coverageSummary.physicalDevices),
                "simulators": \(coverageSummary.simulators),
                "uniqueOSVersions": \(coverageSummary.uniqueOSVersions),
                "coveragePercentage": \(String(format: "%.1f", coverageSummary.coveragePercentage))
              },
              "entries": \(entriesString)
            }
            """
        }

        return "{}"
    }
}
