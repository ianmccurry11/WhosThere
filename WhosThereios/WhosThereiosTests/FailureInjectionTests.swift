//
//  FailureInjectionTests.swift
//  WhosThereiosTests
//
//  Created by Claude on 2/5/26.
//

import XCTest
@testable import WhosThereios

// MARK: - FailureMode Tests

final class FailureModeTests: XCTestCase {

    func testAllCases() {
        let allCases = FailureMode.allCases
        XCTAssertEqual(allCases.count, 7)
    }

    func testRawValues() {
        XCTAssertEqual(FailureMode.none.rawValue, "Normal")
        XCTAssertEqual(FailureMode.noNetwork.rawValue, "No Network")
        XCTAssertEqual(FailureMode.slowNetwork.rawValue, "Slow Network (3s delay)")
        XCTAssertEqual(FailureMode.intermittent.rawValue, "Intermittent Failures (50%)")
        XCTAssertEqual(FailureMode.authFailure.rawValue, "Auth Always Fails")
        XCTAssertEqual(FailureMode.firestoreFailure.rawValue, "Firestore Always Fails")
        XCTAssertEqual(FailureMode.timeout.rawValue, "Request Timeout (10s)")
    }

    func testIcons() {
        for mode in FailureMode.allCases {
            XCTAssertFalse(mode.icon.isEmpty, "\(mode.rawValue) should have an icon")
        }
    }

    func testDescriptions() {
        for mode in FailureMode.allCases {
            XCTAssertFalse(mode.description.isEmpty, "\(mode.rawValue) should have a description")
        }
    }

    func testCodable() throws {
        for mode in FailureMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(FailureMode.self, from: data)
            XCTAssertEqual(decoded, mode)
        }
    }
}

// MARK: - FailureEvent Tests

final class FailureEventTests: XCTestCase {

    func testDefaultInitialization() {
        let event = FailureEvent(
            operation: "fetchGroups",
            injectedMode: .noNetwork,
            didFail: true,
            appBehavior: "Error shown"
        )

        XCTAssertFalse(event.id.uuidString.isEmpty)
        XCTAssertEqual(event.operation, "fetchGroups")
        XCTAssertEqual(event.injectedMode, .noNetwork)
        XCTAssertTrue(event.didFail)
        XCTAssertEqual(event.appBehavior, "Error shown")
    }

    func testCodable() throws {
        let original = FailureEvent(
            operation: "signIn",
            injectedMode: .authFailure,
            didFail: true,
            appBehavior: "Auth error displayed"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FailureEvent.self, from: data)

        XCTAssertEqual(decoded.operation, original.operation)
        XCTAssertEqual(decoded.injectedMode, original.injectedMode)
        XCTAssertEqual(decoded.didFail, original.didFail)
        XCTAssertEqual(decoded.appBehavior, original.appBehavior)
    }

    func testPassedEvent() {
        let event = FailureEvent(
            operation: "fetchUser",
            injectedMode: .intermittent,
            didFail: false,
            appBehavior: "Passed through"
        )

        XCTAssertFalse(event.didFail)
    }
}

// MARK: - InjectionError Tests

final class InjectionErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertEqual(InjectionError.networkUnavailable.errorDescription, "[INJECTED] Network unavailable")
        XCTAssertEqual(InjectionError.authenticationFailed.errorDescription, "[INJECTED] Authentication failed")
        XCTAssertEqual(InjectionError.firestoreUnavailable.errorDescription, "[INJECTED] Firestore unavailable")
        XCTAssertEqual(InjectionError.requestTimeout.errorDescription, "[INJECTED] Request timed out")
        XCTAssertEqual(InjectionError.intermittentFailure.errorDescription, "[INJECTED] Random failure occurred")
    }

    func testErrorsAreDistinct() {
        let errors: [InjectionError] = [
            .networkUnavailable,
            .authenticationFailed,
            .firestoreUnavailable,
            .requestTimeout,
            .intermittentFailure
        ]

        let descriptions = Set(errors.map { $0.errorDescription ?? "" })
        XCTAssertEqual(descriptions.count, errors.count, "All errors should have unique descriptions")
    }

    func testAllDescriptionsContainInjectedPrefix() {
        let errors: [InjectionError] = [
            .networkUnavailable,
            .authenticationFailed,
            .firestoreUnavailable,
            .requestTimeout,
            .intermittentFailure
        ]

        for error in errors {
            XCTAssertTrue(
                error.errorDescription?.contains("[INJECTED]") ?? false,
                "\(error) description should contain [INJECTED]"
            )
        }
    }
}

// MARK: - FailureInjectionService Tests

@MainActor
final class FailureInjectionServiceTests: XCTestCase {

    private var service: FailureInjectionService!

    override func setUp() {
        super.setUp()
        service = FailureInjectionService.shared
        service.reset()
        service.clearLog()
    }

    override func tearDown() {
        service.reset()
        service.clearLog()
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertEqual(service.currentMode, .none)
        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.injectedCount, 0)
        XCTAssertEqual(service.passedCount, 0)
        XCTAssertTrue(service.failureLog.isEmpty)
    }

    // MARK: - Mode Setting

    func testSetModeEnablesInjection() {
        service.setMode(.noNetwork)
        XCTAssertEqual(service.currentMode, .noNetwork)
        XCTAssertTrue(service.isEnabled)
    }

    func testSetNoneModeDisables() {
        service.setMode(.noNetwork)
        XCTAssertTrue(service.isEnabled)

        service.setMode(.none)
        XCTAssertFalse(service.isEnabled)
    }

    func testReset() {
        service.setMode(.noNetwork)
        _ = service.shouldFail(for: "test")

        service.reset()

        XCTAssertEqual(service.currentMode, .none)
        XCTAssertFalse(service.isEnabled)
        XCTAssertEqual(service.injectedCount, 0)
        XCTAssertEqual(service.passedCount, 0)
    }

    func testClearLog() {
        service.setMode(.noNetwork)
        _ = service.shouldFail(for: "test1")
        _ = service.shouldFail(for: "test2")

        XCTAssertFalse(service.failureLog.isEmpty)

        service.clearLog()

        XCTAssertTrue(service.failureLog.isEmpty)
        XCTAssertEqual(service.injectedCount, 0)
        XCTAssertEqual(service.passedCount, 0)
    }

    // MARK: - shouldFail Tests

    func testShouldFailDisabledReturnsNoFail() {
        service.setMode(.none)

        let result = service.shouldFail(for: "anyOperation")
        XCTAssertFalse(result)
    }

    func testNoNetworkAlwaysFails() {
        service.setMode(.noNetwork)

        for _ in 0..<10 {
            XCTAssertTrue(service.shouldFail(for: "fetchData"))
        }
    }

    func testSlowNetworkNeverFails() {
        service.setMode(.slowNetwork)

        for _ in 0..<10 {
            XCTAssertFalse(service.shouldFail(for: "fetchData"))
        }
    }

    func testAuthFailureOnlyFailsAuthOps() {
        service.setMode(.authFailure)

        XCTAssertTrue(service.shouldFail(for: "signInAnonymously"))
        XCTAssertTrue(service.shouldFail(for: "authRefresh"))
        XCTAssertFalse(service.shouldFail(for: "loadGroups"))
        XCTAssertFalse(service.shouldFail(for: "sendMessage"))
    }

    func testFirestoreFailureOnlyFailsFirestoreOps() {
        service.setMode(.firestoreFailure)

        XCTAssertTrue(service.shouldFail(for: "fetchGroups"))
        XCTAssertTrue(service.shouldFail(for: "createGroup"))
        XCTAssertTrue(service.shouldFail(for: "updatePresence"))
        XCTAssertTrue(service.shouldFail(for: "deleteGroup"))
        XCTAssertTrue(service.shouldFail(for: "firestoreQuery"))
        XCTAssertFalse(service.shouldFail(for: "signIn"))
    }

    func testTimeoutAlwaysFails() {
        service.setMode(.timeout)

        for _ in 0..<5 {
            XCTAssertTrue(service.shouldFail(for: "anyOperation"))
        }
    }

    func testIntermittentHasMixedResults() {
        service.setMode(.intermittent)

        var failCount = 0
        var passCount = 0
        let iterations = 100

        for _ in 0..<iterations {
            if service.shouldFail(for: "test") {
                failCount += 1
            } else {
                passCount += 1
            }
        }

        // With 50% probability over 100 iterations, we should have some of each
        // (statistically, the chance of all 100 being the same is negligible)
        XCTAssertGreaterThan(failCount, 0, "Should have some failures")
        XCTAssertGreaterThan(passCount, 0, "Should have some passes")
    }

    // MARK: - Counter Tests

    func testInjectedCountIncrements() {
        service.setMode(.noNetwork)

        _ = service.shouldFail(for: "op1")
        _ = service.shouldFail(for: "op2")
        _ = service.shouldFail(for: "op3")

        XCTAssertEqual(service.injectedCount, 3)
    }

    func testPassedCountIncrements() {
        service.setMode(.slowNetwork)

        _ = service.shouldFail(for: "op1")
        _ = service.shouldFail(for: "op2")

        XCTAssertEqual(service.passedCount, 2)
    }

    // MARK: - Failure Rate

    func testFailureRateWithNoOps() {
        XCTAssertEqual(service.failureRate, 0)
    }

    func testFailureRateAllFailed() {
        service.setMode(.noNetwork)

        _ = service.shouldFail(for: "op1")
        _ = service.shouldFail(for: "op2")

        XCTAssertEqual(service.failureRate, 100.0)
    }

    func testFailureRateNoneFailed() {
        service.setMode(.slowNetwork)

        _ = service.shouldFail(for: "op1")
        _ = service.shouldFail(for: "op2")

        XCTAssertEqual(service.failureRate, 0)
    }

    // MARK: - Error Tests

    func testGetInjectedErrorForModes() {
        service.setMode(.noNetwork)
        XCTAssertTrue(service.getInjectedError() is InjectionError)

        service.setMode(.authFailure)
        let authError = service.getInjectedError() as? InjectionError
        XCTAssertEqual(authError, .authenticationFailed)

        service.setMode(.firestoreFailure)
        let fsError = service.getInjectedError() as? InjectionError
        XCTAssertEqual(fsError, .firestoreUnavailable)

        service.setMode(.timeout)
        let timeoutError = service.getInjectedError() as? InjectionError
        XCTAssertEqual(timeoutError, .requestTimeout)
    }

    // MARK: - Log Tests

    func testLogRecordsEvents() {
        service.setMode(.noNetwork)

        _ = service.shouldFail(for: "fetchGroups")

        XCTAssertEqual(service.failureLog.count, 2) // mode_change + operation
        let opEvent = service.failureLog.first!
        XCTAssertEqual(opEvent.operation, "fetchGroups")
        XCTAssertTrue(opEvent.didFail)
    }

    func testLogBehavior() {
        service.logBehavior("testOp", behavior: "Showed error dialog")

        XCTAssertEqual(service.failureLog.count, 1)
        XCTAssertEqual(service.failureLog.first?.operation, "testOp")
        XCTAssertEqual(service.failureLog.first?.appBehavior, "Showed error dialog")
        XCTAssertFalse(service.failureLog.first?.didFail ?? true)
    }

    func testLogTrimming() {
        service.setMode(.noNetwork)

        // Generate more than maxLogEntries
        for i in 0..<120 {
            _ = service.shouldFail(for: "op_\(i)")
        }

        // Should be trimmed to 100 (maxLogEntries)
        XCTAssertLessThanOrEqual(service.failureLog.count, 100)
    }

    // MARK: - FailuresByOperation

    func testFailuresByOperation() {
        service.setMode(.noNetwork)

        _ = service.shouldFail(for: "fetchGroups")
        _ = service.shouldFail(for: "fetchGroups")
        _ = service.shouldFail(for: "fetchGroups")
        _ = service.shouldFail(for: "signIn")
        _ = service.shouldFail(for: "signIn")

        let byOp = service.failuresByOperation
        XCTAssertEqual(byOp["fetchGroups"], 3)
        XCTAssertEqual(byOp["signIn"], 2)
    }

    func testFailuresByOperationEmpty() {
        XCTAssertTrue(service.failuresByOperation.isEmpty)
    }

    // MARK: - withInjection Tests

    func testWithInjectionDisabled() async throws {
        service.reset()

        let result = try await service.withInjection(operation: "test") {
            return 42
        }

        XCTAssertEqual(result, 42)
    }

    func testWithInjectionNoNetworkThrows() async {
        service.setMode(.noNetwork)

        do {
            _ = try await service.withInjection(operation: "fetchData") {
                return "data"
            }
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is InjectionError)
        }
    }

    func testWithInjectionAuthFailureOnlyAffectsAuth() async throws {
        service.setMode(.authFailure)

        // Non-auth operation should pass
        let result = try await service.withInjection(operation: "loadGroups") {
            return "groups"
        }
        XCTAssertEqual(result, "groups")

        // Auth operation should fail
        do {
            _ = try await service.withInjection(operation: "signIn") {
                return "token"
            }
            XCTFail("Should have thrown for auth operation")
        } catch {
            XCTAssertTrue(error is InjectionError)
        }
    }
}
