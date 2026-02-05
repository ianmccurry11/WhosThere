//
//  NetworkInspector.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import Foundation
import Combine

/// Service for logging and inspecting network requests
/// Provides visibility into Firestore operations for debugging and QA validation
@MainActor
final class NetworkInspector: ObservableObject {
    static let shared = NetworkInspector()

    // MARK: - Published Properties

    /// Recent network requests (last 200)
    @Published var requests: [NetworkRequest] = []

    /// Current filter for displaying requests
    @Published var filter = NetworkRequestFilter()

    /// Whether logging is enabled
    @Published var isLoggingEnabled = true

    /// Statistics computed from all requests
    @Published var statistics = NetworkStatistics()

    // MARK: - Private Properties

    private let maxRequests = 200
    private var pendingRequests: [UUID: (startTime: Date, request: NetworkRequest)] = [:]

    // MARK: - Initialization

    private init() {}

    // MARK: - Request Logging

    /// Start tracking a request (call when request begins)
    /// Returns a request ID to use when completing the request
    func startRequest(
        operation: NetworkOperation,
        collection: String,
        documentId: String? = nil,
        method: NetworkMethod,
        metadata: [String: String] = [:]
    ) -> UUID {
        guard isLoggingEnabled else { return UUID() }

        let request = NetworkRequest(
            operation: operation,
            collection: collection,
            documentId: documentId,
            method: method,
            status: .pending,
            durationMs: 0,
            metadata: metadata
        )

        pendingRequests[request.id] = (startTime: Date(), request: request)

        #if DEBUG
        print("[NetworkInspector] Started: \(operation.rawValue) \(collection)\(documentId.map { "/\($0)" } ?? "")")
        #endif

        return request.id
    }

    /// Complete a request with success
    func completeRequest(
        id: UUID,
        payloadSize: Int? = nil,
        additionalMetadata: [String: String] = [:]
    ) {
        guard isLoggingEnabled else { return }
        finalizeRequest(id: id, status: .success, payloadSize: payloadSize, additionalMetadata: additionalMetadata)
    }

    /// Complete a request with failure
    func failRequest(
        id: UUID,
        error: Error,
        additionalMetadata: [String: String] = [:]
    ) {
        guard isLoggingEnabled else { return }
        finalizeRequest(
            id: id,
            status: .failure,
            errorMessage: error.localizedDescription,
            additionalMetadata: additionalMetadata
        )
    }

    /// Complete a request with cached data
    func completeFromCache(
        id: UUID,
        payloadSize: Int? = nil
    ) {
        guard isLoggingEnabled else { return }
        finalizeRequest(id: id, status: .cached, payloadSize: payloadSize)
    }

    /// Complete a request with timeout
    func timeoutRequest(id: UUID) {
        guard isLoggingEnabled else { return }
        finalizeRequest(id: id, status: .timeout, errorMessage: "Request timed out")
    }

    /// Log a quick request (start and complete in one call)
    func logRequest(
        operation: NetworkOperation,
        collection: String,
        documentId: String? = nil,
        method: NetworkMethod,
        status: NetworkStatus,
        durationMs: Double,
        payloadSize: Int? = nil,
        errorMessage: String? = nil,
        metadata: [String: String] = [:]
    ) {
        guard isLoggingEnabled else { return }

        let request = NetworkRequest(
            operation: operation,
            collection: collection,
            documentId: documentId,
            method: method,
            status: status,
            durationMs: durationMs,
            payloadSize: payloadSize,
            errorMessage: errorMessage,
            metadata: metadata
        )

        addRequest(request)
    }

    // MARK: - Private Methods

    private func finalizeRequest(
        id: UUID,
        status: NetworkStatus,
        payloadSize: Int? = nil,
        errorMessage: String? = nil,
        additionalMetadata: [String: String] = [:]
    ) {
        guard let pending = pendingRequests.removeValue(forKey: id) else { return }

        let duration = Date().timeIntervalSince(pending.startTime) * 1000 // Convert to ms
        var metadata = pending.request.metadata
        for (key, value) in additionalMetadata {
            metadata[key] = value
        }

        let completedRequest = NetworkRequest(
            id: id,
            timestamp: pending.request.timestamp,
            operation: pending.request.operation,
            collection: pending.request.collection,
            documentId: pending.request.documentId,
            method: pending.request.method,
            status: status,
            durationMs: duration,
            payloadSize: payloadSize,
            errorMessage: errorMessage,
            metadata: metadata
        )

        addRequest(completedRequest)

        #if DEBUG
        let statusEmoji = status == .success ? "✅" : (status == .failure ? "❌" : "⏱️")
        print("[NetworkInspector] \(statusEmoji) \(pending.request.operation.rawValue) \(pending.request.collection) - \(String(format: "%.0f", duration))ms")
        #endif
    }

    private func addRequest(_ request: NetworkRequest) {
        requests.insert(request, at: 0)
        if requests.count > maxRequests {
            requests.removeLast()
        }

        updateStatistics(with: request)
    }

    private func updateStatistics(with request: NetworkRequest) {
        statistics.totalRequests += 1

        if request.status == .success || request.status == .cached {
            statistics.successfulRequests += 1
        } else if request.status == .failure || request.status == .timeout {
            statistics.failedRequests += 1
        }

        // Update average latency
        let totalLatency = statistics.averageLatencyMs * Double(statistics.totalRequests - 1) + request.durationMs
        statistics.averageLatencyMs = totalLatency / Double(statistics.totalRequests)

        // Update payload size
        if let size = request.payloadSize {
            statistics.totalPayloadBytes += size
        }

        // Update by operation
        statistics.requestsByOperation[request.operation, default: 0] += 1

        // Update by collection
        statistics.requestsByCollection[request.collection, default: 0] += 1
    }

    // MARK: - Query Methods

    /// Get requests filtered by current filter
    var filteredRequests: [NetworkRequest] {
        requests.filter { filter.matches($0) }
    }

    /// Get only failed requests
    var failedRequests: [NetworkRequest] {
        requests.filter { $0.status == .failure || $0.status == .timeout }
    }

    /// Get slow requests (above warning threshold)
    var slowRequests: [NetworkRequest] {
        requests.filter { $0.durationMs >= SlowRequestThreshold.warning }
    }

    /// Get requests for a specific collection
    func requests(for collection: String) -> [NetworkRequest] {
        requests.filter { $0.collection == collection }
    }

    /// Get requests since a specific date
    func requestsSince(_ date: Date) -> [NetworkRequest] {
        requests.filter { $0.timestamp >= date }
    }

    /// Get unique collections that have been accessed
    var accessedCollections: [String] {
        Array(Set(requests.map { $0.collection })).sorted()
    }

    // MARK: - Actions

    /// Clear all logged requests
    func clearRequests() {
        requests.removeAll()
        pendingRequests.removeAll()
        statistics = NetworkStatistics()
    }

    /// Export requests as JSON
    func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let data = try encoder.encode(requests)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "Error encoding requests: \(error.localizedDescription)"
        }
    }

    /// Toggle logging on/off
    func toggleLogging() {
        isLoggingEnabled.toggle()
    }
}

// MARK: - Convenience Extensions for Firestore

extension NetworkInspector {
    /// Log a Firestore document read
    func logDocumentRead(collection: String, documentId: String, durationMs: Double, success: Bool, error: Error? = nil) {
        logRequest(
            operation: .read,
            collection: collection,
            documentId: documentId,
            method: .get,
            status: success ? .success : .failure,
            durationMs: durationMs,
            errorMessage: error?.localizedDescription
        )
    }

    /// Log a Firestore document write
    func logDocumentWrite(collection: String, documentId: String?, durationMs: Double, success: Bool, error: Error? = nil) {
        logRequest(
            operation: .write,
            collection: collection,
            documentId: documentId,
            method: documentId == nil ? .add : .set,
            status: success ? .success : .failure,
            durationMs: durationMs,
            errorMessage: error?.localizedDescription
        )
    }

    /// Log a Firestore document update
    func logDocumentUpdate(collection: String, documentId: String, durationMs: Double, success: Bool, error: Error? = nil) {
        logRequest(
            operation: .update,
            collection: collection,
            documentId: documentId,
            method: .update,
            status: success ? .success : .failure,
            durationMs: durationMs,
            errorMessage: error?.localizedDescription
        )
    }

    /// Log a Firestore document delete
    func logDocumentDelete(collection: String, documentId: String, durationMs: Double, success: Bool, error: Error? = nil) {
        logRequest(
            operation: .delete,
            collection: collection,
            documentId: documentId,
            method: .delete,
            status: success ? .success : .failure,
            durationMs: durationMs,
            errorMessage: error?.localizedDescription
        )
    }

    /// Log a Firestore query
    func logQuery(collection: String, durationMs: Double, resultCount: Int, success: Bool, error: Error? = nil) {
        logRequest(
            operation: .query,
            collection: collection,
            method: .query,
            status: success ? .success : .failure,
            durationMs: durationMs,
            errorMessage: error?.localizedDescription,
            metadata: ["result_count": "\(resultCount)"]
        )
    }

    /// Log a Firestore snapshot listener event
    func logSnapshotUpdate(collection: String, documentCount: Int) {
        logRequest(
            operation: .listen,
            collection: collection,
            method: .snapshot,
            status: .success,
            durationMs: 0,
            metadata: ["document_count": "\(documentCount)"]
        )
    }

    /// Log an auth operation
    func logAuthOperation(method: String, durationMs: Double, success: Bool, error: Error? = nil) {
        logRequest(
            operation: .auth,
            collection: "auth",
            method: method == "signIn" ? .signIn : .signOut,
            status: success ? .success : .failure,
            durationMs: durationMs,
            errorMessage: error?.localizedDescription
        )
    }
}
