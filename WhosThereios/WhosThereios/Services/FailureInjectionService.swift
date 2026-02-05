//
//  FailureInjectionService.swift
//  WhosThereios
//
//  Created by Claude on 2/5/26.
//

import Combine
import Foundation

// MARK: - Failure Mode

/// Available failure simulation modes for resilience testing
enum FailureMode: String, Codable, CaseIterable {
    case none = "Normal"
    case noNetwork = "No Network"
    case slowNetwork = "Slow Network (3s delay)"
    case intermittent = "Intermittent Failures (50%)"
    case authFailure = "Auth Always Fails"
    case firestoreFailure = "Firestore Always Fails"
    case timeout = "Request Timeout (10s)"

    var icon: String {
        switch self {
        case .none: return "checkmark.circle"
        case .noNetwork: return "wifi.slash"
        case .slowNetwork: return "tortoise"
        case .intermittent: return "dice"
        case .authFailure: return "person.crop.circle.badge.xmark"
        case .firestoreFailure: return "externaldrive.badge.xmark"
        case .timeout: return "clock.badge.exclamationmark"
        }
    }

    var description: String {
        switch self {
        case .none: return "All operations function normally"
        case .noNetwork: return "All network requests fail immediately"
        case .slowNetwork: return "All requests delayed by 3 seconds"
        case .intermittent: return "50% of requests fail randomly"
        case .authFailure: return "Authentication requests always fail"
        case .firestoreFailure: return "All Firestore operations fail"
        case .timeout: return "Requests hang for 10 seconds then fail"
        }
    }
}

// MARK: - Failure Event

/// Records an injected failure and the app's response
struct FailureEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let operation: String
    let injectedMode: FailureMode
    let didFail: Bool
    let appBehavior: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        operation: String,
        injectedMode: FailureMode,
        didFail: Bool,
        appBehavior: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.injectedMode = injectedMode
        self.didFail = didFail
        self.appBehavior = appBehavior
    }
}

// MARK: - Injection Error

/// Errors thrown by the failure injection system
enum InjectionError: LocalizedError {
    case networkUnavailable
    case authenticationFailed
    case firestoreUnavailable
    case requestTimeout
    case intermittentFailure

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "[INJECTED] Network unavailable"
        case .authenticationFailed:
            return "[INJECTED] Authentication failed"
        case .firestoreUnavailable:
            return "[INJECTED] Firestore unavailable"
        case .requestTimeout:
            return "[INJECTED] Request timed out"
        case .intermittentFailure:
            return "[INJECTED] Random failure occurred"
        }
    }
}

// MARK: - Failure Injection Service

/// Service for simulating failures to test app resilience
/// Only active in DEBUG builds
@MainActor
final class FailureInjectionService: ObservableObject {
    static let shared = FailureInjectionService()

    // MARK: - Published Properties

    /// Current active failure mode
    @Published var currentMode: FailureMode = .none

    /// Log of all injected failures
    @Published var failureLog: [FailureEvent] = []

    /// Whether injection is enabled
    @Published var isEnabled = false

    /// Count of injected failures this session
    @Published var injectedCount: Int = 0

    /// Count of passed-through operations this session
    @Published var passedCount: Int = 0

    // MARK: - Private Properties

    private let maxLogEntries = 100

    // MARK: - Initialization

    private init() {}

    // MARK: - Injection Points

    /// Check if an operation should fail based on current mode
    /// - Parameter operation: Name of the operation being checked
    /// - Returns: true if the operation should be failed
    func shouldFail(for operation: String) -> Bool {
        guard isEnabled, currentMode != .none else {
            return false
        }

        let shouldFail: Bool

        switch currentMode {
        case .none:
            shouldFail = false

        case .noNetwork:
            shouldFail = true

        case .slowNetwork:
            // Slow network doesn't fail, just delays
            shouldFail = false

        case .intermittent:
            shouldFail = Bool.random()

        case .authFailure:
            shouldFail = operation.lowercased().contains("auth") ||
                         operation.lowercased().contains("sign")

        case .firestoreFailure:
            shouldFail = operation.lowercased().contains("firestore") ||
                         operation.lowercased().contains("fetch") ||
                         operation.lowercased().contains("create") ||
                         operation.lowercased().contains("update") ||
                         operation.lowercased().contains("delete")

        case .timeout:
            shouldFail = true
        }

        if shouldFail {
            injectedCount += 1
            logEvent(operation: operation, didFail: true, behavior: "Failure injected: \(currentMode.rawValue)")
        } else {
            passedCount += 1
            logEvent(operation: operation, didFail: false, behavior: "Passed through")
        }

        return shouldFail
    }

    /// Simulate network delay if in slow network mode
    func simulateDelay() async {
        guard isEnabled else { return }

        switch currentMode {
        case .slowNetwork:
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        case .timeout:
            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        default:
            break
        }
    }

    /// Get the appropriate error for the current failure mode
    func getInjectedError() -> Error {
        switch currentMode {
        case .noNetwork:
            return InjectionError.networkUnavailable
        case .authFailure:
            return InjectionError.authenticationFailed
        case .firestoreFailure:
            return InjectionError.firestoreUnavailable
        case .timeout:
            return InjectionError.requestTimeout
        case .intermittent:
            return InjectionError.intermittentFailure
        default:
            return InjectionError.intermittentFailure
        }
    }

    /// Execute a potentially failing operation with injection support
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - block: The async operation to execute
    /// - Returns: The result of the operation
    func withInjection<T>(operation: String, block: () async throws -> T) async throws -> T {
        guard isEnabled, currentMode != .none else {
            return try await block()
        }

        // Pre-operation delay
        await simulateDelay()

        // Check if should fail
        if shouldFail(for: operation) {
            throw getInjectedError()
        }

        return try await block()
    }

    // MARK: - Logging

    /// Log a failure event
    private func logEvent(operation: String, didFail: Bool, behavior: String) {
        let event = FailureEvent(
            operation: operation,
            injectedMode: currentMode,
            didFail: didFail,
            appBehavior: behavior
        )

        failureLog.insert(event, at: 0)

        // Trim log
        if failureLog.count > maxLogEntries {
            failureLog = Array(failureLog.prefix(maxLogEntries))
        }
    }

    /// Log observed app behavior for an operation
    func logBehavior(_ operation: String, behavior: String) {
        logEvent(operation: operation, didFail: false, behavior: behavior)
    }

    // MARK: - Mode Management

    /// Set the failure mode
    func setMode(_ mode: FailureMode) {
        currentMode = mode
        isEnabled = mode != .none

        if mode != .none {
            logEvent(
                operation: "mode_change",
                didFail: false,
                behavior: "Switched to: \(mode.rawValue)"
            )
        }
    }

    /// Reset to normal mode
    func reset() {
        currentMode = .none
        isEnabled = false
        injectedCount = 0
        passedCount = 0
    }

    /// Clear the failure log
    func clearLog() {
        failureLog.removeAll()
        injectedCount = 0
        passedCount = 0
    }

    // MARK: - Statistics

    /// Get failure rate for this session
    var failureRate: Double {
        let total = injectedCount + passedCount
        guard total > 0 else { return 0 }
        return Double(injectedCount) / Double(total) * 100
    }

    /// Get summary of failures by operation
    var failuresByOperation: [String: Int] {
        var counts: [String: Int] = [:]
        for event in failureLog where event.didFail {
            counts[event.operation, default: 0] += 1
        }
        return counts
    }
}
