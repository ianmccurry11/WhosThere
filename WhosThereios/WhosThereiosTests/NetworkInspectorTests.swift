//
//  NetworkInspectorTests.swift
//  WhosThereiosTests
//
//  Created by Claude on 2/4/26.
//

import XCTest
@testable import WhosThereios

// MARK: - NetworkRequest Tests

final class NetworkRequestTests: XCTestCase {

    func testRequestInitialization() {
        let request = NetworkRequest(
            operation: .read,
            collection: "users",
            documentId: "user123",
            method: .get,
            status: .success,
            durationMs: 150.5,
            payloadSize: 1024,
            metadata: ["key": "value"]
        )

        XCTAssertEqual(request.operation, .read)
        XCTAssertEqual(request.collection, "users")
        XCTAssertEqual(request.documentId, "user123")
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.status, .success)
        XCTAssertEqual(request.durationMs, 150.5)
        XCTAssertEqual(request.payloadSize, 1024)
        XCTAssertEqual(request.metadata["key"], "value")
        XCTAssertNotNil(request.id)
        XCTAssertNotNil(request.timestamp)
    }

    func testRequestWithoutOptionalFields() {
        let request = NetworkRequest(
            operation: .query,
            collection: "groups",
            method: .query,
            status: .success,
            durationMs: 50
        )

        XCTAssertNil(request.documentId)
        XCTAssertNil(request.payloadSize)
        XCTAssertNil(request.errorMessage)
        XCTAssertTrue(request.metadata.isEmpty)
    }

    func testRequestWithError() {
        let request = NetworkRequest(
            operation: .write,
            collection: "messages",
            method: .add,
            status: .failure,
            durationMs: 200,
            errorMessage: "Permission denied"
        )

        XCTAssertEqual(request.status, .failure)
        XCTAssertEqual(request.errorMessage, "Permission denied")
    }

    func testRequestUniqueIds() {
        let request1 = NetworkRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 0)
        let request2 = NetworkRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 0)

        XCTAssertNotEqual(request1.id, request2.id)
    }
}

// MARK: - NetworkOperation Tests

final class NetworkOperationTests: XCTestCase {

    func testOperationRawValues() {
        XCTAssertEqual(NetworkOperation.read.rawValue, "READ")
        XCTAssertEqual(NetworkOperation.write.rawValue, "WRITE")
        XCTAssertEqual(NetworkOperation.update.rawValue, "UPDATE")
        XCTAssertEqual(NetworkOperation.delete.rawValue, "DELETE")
        XCTAssertEqual(NetworkOperation.query.rawValue, "QUERY")
        XCTAssertEqual(NetworkOperation.listen.rawValue, "LISTEN")
        XCTAssertEqual(NetworkOperation.batch.rawValue, "BATCH")
        XCTAssertEqual(NetworkOperation.auth.rawValue, "AUTH")
    }

    func testOperationEmojis() {
        XCTAssertFalse(NetworkOperation.read.emoji.isEmpty)
        XCTAssertFalse(NetworkOperation.write.emoji.isEmpty)
        XCTAssertFalse(NetworkOperation.query.emoji.isEmpty)
    }
}

// MARK: - NetworkStatus Tests

final class NetworkStatusTests: XCTestCase {

    func testStatusRawValues() {
        XCTAssertEqual(NetworkStatus.pending.rawValue, "PENDING")
        XCTAssertEqual(NetworkStatus.success.rawValue, "SUCCESS")
        XCTAssertEqual(NetworkStatus.failure.rawValue, "FAILURE")
        XCTAssertEqual(NetworkStatus.cached.rawValue, "CACHED")
        XCTAssertEqual(NetworkStatus.timeout.rawValue, "TIMEOUT")
    }

    func testStatusColors() {
        XCTAssertEqual(NetworkStatus.pending.color, "orange")
        XCTAssertEqual(NetworkStatus.success.color, "green")
        XCTAssertEqual(NetworkStatus.failure.color, "red")
        XCTAssertEqual(NetworkStatus.cached.color, "blue")
        XCTAssertEqual(NetworkStatus.timeout.color, "yellow")
    }
}

// MARK: - NetworkStatistics Tests

final class NetworkStatisticsTests: XCTestCase {

    func testDefaultStatistics() {
        let stats = NetworkStatistics()

        XCTAssertEqual(stats.totalRequests, 0)
        XCTAssertEqual(stats.successfulRequests, 0)
        XCTAssertEqual(stats.failedRequests, 0)
        XCTAssertEqual(stats.averageLatencyMs, 0)
        XCTAssertEqual(stats.totalPayloadBytes, 0)
    }

    func testSuccessRate() {
        var stats = NetworkStatistics()
        stats.totalRequests = 10
        stats.successfulRequests = 8
        stats.failedRequests = 2

        XCTAssertEqual(stats.successRate, 80.0)
        XCTAssertEqual(stats.failureRate, 20.0)
    }

    func testZeroRequestsRate() {
        let stats = NetworkStatistics()

        XCTAssertEqual(stats.successRate, 0)
        XCTAssertEqual(stats.failureRate, 0)
    }
}

// MARK: - NetworkRequestFilter Tests

final class NetworkRequestFilterTests: XCTestCase {

    func testDefaultFilterMatchesAll() {
        let filter = NetworkRequestFilter()
        let request = NetworkRequest(
            operation: .read,
            collection: "users",
            method: .get,
            status: .success,
            durationMs: 100
        )

        XCTAssertTrue(filter.matches(request))
    }

    func testFilterByOperation() {
        var filter = NetworkRequestFilter()
        filter.operations = [.write]

        let readRequest = NetworkRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 0)
        let writeRequest = NetworkRequest(operation: .write, collection: "a", method: .set, status: .success, durationMs: 0)

        XCTAssertFalse(filter.matches(readRequest))
        XCTAssertTrue(filter.matches(writeRequest))
    }

    func testFilterByStatus() {
        var filter = NetworkRequestFilter()
        filter.statuses = [.failure]

        let successRequest = NetworkRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 0)
        let failureRequest = NetworkRequest(operation: .read, collection: "a", method: .get, status: .failure, durationMs: 0)

        XCTAssertFalse(filter.matches(successRequest))
        XCTAssertTrue(filter.matches(failureRequest))
    }

    func testFilterByMinDuration() {
        var filter = NetworkRequestFilter()
        filter.minDurationMs = 500

        let fastRequest = NetworkRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 100)
        let slowRequest = NetworkRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 600)

        XCTAssertFalse(filter.matches(fastRequest))
        XCTAssertTrue(filter.matches(slowRequest))
    }

    func testFilterBySearchText() {
        var filter = NetworkRequestFilter()
        filter.searchText = "users"

        let usersRequest = NetworkRequest(operation: .read, collection: "users", method: .get, status: .success, durationMs: 0)
        let groupsRequest = NetworkRequest(operation: .read, collection: "groups", method: .get, status: .success, durationMs: 0)

        XCTAssertTrue(filter.matches(usersRequest))
        XCTAssertFalse(filter.matches(groupsRequest))
    }

    func testFilterShowOnlyErrors() {
        var filter = NetworkRequestFilter()
        filter.showOnlyErrors = true

        let successRequest = NetworkRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 0)
        let failureRequest = NetworkRequest(operation: .read, collection: "a", method: .get, status: .failure, durationMs: 0)

        XCTAssertFalse(filter.matches(successRequest))
        XCTAssertTrue(filter.matches(failureRequest))
    }
}

// MARK: - SlowRequestThreshold Tests

final class SlowRequestThresholdTests: XCTestCase {

    func testThresholdValues() {
        XCTAssertEqual(SlowRequestThreshold.warning, 500)
        XCTAssertEqual(SlowRequestThreshold.critical, 2000)
    }

    func testSeverityNormal() {
        let severity = SlowRequestThreshold.severity(for: 100)
        XCTAssertEqual(severity, .normal)
    }

    func testSeverityWarning() {
        let severity = SlowRequestThreshold.severity(for: 750)
        XCTAssertEqual(severity, .warning)
    }

    func testSeverityCritical() {
        let severity = SlowRequestThreshold.severity(for: 3000)
        XCTAssertEqual(severity, .critical)
    }

    func testSeverityAtBoundary() {
        XCTAssertEqual(SlowRequestThreshold.severity(for: 500), .warning)
        XCTAssertEqual(SlowRequestThreshold.severity(for: 2000), .critical)
    }
}

// MARK: - NetworkInspector Tests

@MainActor
final class NetworkInspectorTests: XCTestCase {

    var inspector: NetworkInspector!

    override func setUp() async throws {
        inspector = NetworkInspector.shared
        inspector.clearRequests()
        inspector.isLoggingEnabled = true
    }

    override func tearDown() async throws {
        inspector.clearRequests()
    }

    func testInspectorIsSingleton() {
        let inspector1 = NetworkInspector.shared
        let inspector2 = NetworkInspector.shared

        XCTAssertTrue(inspector1 === inspector2)
    }

    func testLogRequest() {
        inspector.logRequest(
            operation: .read,
            collection: "users",
            documentId: "user123",
            method: .get,
            status: .success,
            durationMs: 150
        )

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.collection, "users")
        XCTAssertEqual(inspector.requests.first?.documentId, "user123")
    }

    func testStartAndCompleteRequest() {
        let requestId = inspector.startRequest(
            operation: .write,
            collection: "groups",
            method: .add
        )

        // Simulate some work
        Thread.sleep(forTimeInterval: 0.01)

        inspector.completeRequest(id: requestId)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.status, .success)
        XCTAssertGreaterThan(inspector.requests.first?.durationMs ?? 0, 0)
    }

    func testFailRequest() {
        let requestId = inspector.startRequest(
            operation: .read,
            collection: "users",
            method: .get
        )

        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        inspector.failRequest(id: requestId, error: testError)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.status, .failure)
        XCTAssertEqual(inspector.requests.first?.errorMessage, "Test error")
    }

    func testCompleteFromCache() {
        let requestId = inspector.startRequest(
            operation: .read,
            collection: "users",
            method: .get
        )

        inspector.completeFromCache(id: requestId, payloadSize: 512)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.status, .cached)
        XCTAssertEqual(inspector.requests.first?.payloadSize, 512)
    }

    func testTimeoutRequest() {
        let requestId = inspector.startRequest(
            operation: .query,
            collection: "groups",
            method: .query
        )

        inspector.timeoutRequest(id: requestId)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.status, .timeout)
    }

    func testStatisticsUpdate() {
        inspector.logRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 100)
        inspector.logRequest(operation: .write, collection: "b", method: .set, status: .success, durationMs: 200)
        inspector.logRequest(operation: .read, collection: "a", method: .get, status: .failure, durationMs: 300)

        XCTAssertEqual(inspector.statistics.totalRequests, 3)
        XCTAssertEqual(inspector.statistics.successfulRequests, 2)
        XCTAssertEqual(inspector.statistics.failedRequests, 1)
        XCTAssertEqual(inspector.statistics.averageLatencyMs, 200)
    }

    func testFilteredRequests() {
        inspector.logRequest(operation: .read, collection: "users", method: .get, status: .success, durationMs: 100)
        inspector.logRequest(operation: .write, collection: "groups", method: .add, status: .success, durationMs: 200)

        inspector.filter.operations = [.read]

        let filtered = inspector.filteredRequests
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.operation, .read)
    }

    func testFailedRequests() {
        inspector.logRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 100)
        inspector.logRequest(operation: .read, collection: "b", method: .get, status: .failure, durationMs: 200)
        inspector.logRequest(operation: .read, collection: "c", method: .get, status: .timeout, durationMs: 300)

        XCTAssertEqual(inspector.failedRequests.count, 2)
    }

    func testSlowRequests() {
        inspector.logRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 100)
        inspector.logRequest(operation: .read, collection: "b", method: .get, status: .success, durationMs: 600)
        inspector.logRequest(operation: .read, collection: "c", method: .get, status: .success, durationMs: 2500)

        XCTAssertEqual(inspector.slowRequests.count, 2)
    }

    func testAccessedCollections() {
        inspector.logRequest(operation: .read, collection: "users", method: .get, status: .success, durationMs: 100)
        inspector.logRequest(operation: .read, collection: "groups", method: .get, status: .success, durationMs: 100)
        inspector.logRequest(operation: .read, collection: "users", method: .get, status: .success, durationMs: 100)

        let collections = inspector.accessedCollections
        XCTAssertEqual(collections.count, 2)
        XCTAssertTrue(collections.contains("users"))
        XCTAssertTrue(collections.contains("groups"))
    }

    func testClearRequests() {
        inspector.logRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 100)
        inspector.logRequest(operation: .read, collection: "b", method: .get, status: .success, durationMs: 100)

        XCTAssertEqual(inspector.requests.count, 2)

        inspector.clearRequests()

        XCTAssertEqual(inspector.requests.count, 0)
        XCTAssertEqual(inspector.statistics.totalRequests, 0)
    }

    func testLoggingDisabled() {
        inspector.isLoggingEnabled = false

        inspector.logRequest(operation: .read, collection: "a", method: .get, status: .success, durationMs: 100)

        XCTAssertEqual(inspector.requests.count, 0)
    }

    func testToggleLogging() {
        XCTAssertTrue(inspector.isLoggingEnabled)

        inspector.toggleLogging()

        XCTAssertFalse(inspector.isLoggingEnabled)

        inspector.toggleLogging()

        XCTAssertTrue(inspector.isLoggingEnabled)
    }

    func testExportAsJSON() {
        inspector.logRequest(operation: .read, collection: "users", method: .get, status: .success, durationMs: 100)

        let json = inspector.exportAsJSON()

        XCTAssertTrue(json.contains("users"))
        XCTAssertTrue(json.contains("READ"))
        XCTAssertTrue(json.contains("SUCCESS"))
    }

    func testMaxRequestsLimit() {
        // Log more than max requests
        for i in 0..<250 {
            inspector.logRequest(operation: .read, collection: "test_\(i)", method: .get, status: .success, durationMs: 10)
        }

        XCTAssertEqual(inspector.requests.count, 200)
        // Most recent should be first
        XCTAssertEqual(inspector.requests.first?.collection, "test_249")
    }

    // MARK: - Convenience Method Tests

    func testLogDocumentRead() {
        inspector.logDocumentRead(collection: "users", documentId: "user123", durationMs: 150, success: true)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.operation, .read)
        XCTAssertEqual(inspector.requests.first?.collection, "users")
        XCTAssertEqual(inspector.requests.first?.documentId, "user123")
    }

    func testLogDocumentWrite() {
        inspector.logDocumentWrite(collection: "groups", documentId: "group456", durationMs: 200, success: true)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.operation, .write)
        XCTAssertEqual(inspector.requests.first?.method, .set)
    }

    func testLogDocumentWriteWithoutId() {
        inspector.logDocumentWrite(collection: "messages", documentId: nil, durationMs: 180, success: true)

        XCTAssertEqual(inspector.requests.first?.method, .add)
    }

    func testLogQuery() {
        inspector.logQuery(collection: "groups", durationMs: 300, resultCount: 15, success: true)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.operation, .query)
        XCTAssertEqual(inspector.requests.first?.metadata["result_count"], "15")
    }

    func testLogSnapshotUpdate() {
        inspector.logSnapshotUpdate(collection: "presence", documentCount: 5)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.operation, .listen)
        XCTAssertEqual(inspector.requests.first?.metadata["document_count"], "5")
    }

    func testLogAuthOperation() {
        inspector.logAuthOperation(method: "signIn", durationMs: 500, success: true)

        XCTAssertEqual(inspector.requests.count, 1)
        XCTAssertEqual(inspector.requests.first?.operation, .auth)
        XCTAssertEqual(inspector.requests.first?.method, .signIn)
    }
}
