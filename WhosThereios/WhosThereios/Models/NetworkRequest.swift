//
//  NetworkRequest.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import Foundation

// MARK: - Network Request Model

/// Represents a logged network request for inspection
struct NetworkRequest: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let operation: NetworkOperation
    let collection: String
    let documentId: String?
    let method: NetworkMethod
    let status: NetworkStatus
    let durationMs: Double
    let payloadSize: Int?
    let errorMessage: String?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
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
        self.id = id
        self.timestamp = timestamp
        self.operation = operation
        self.collection = collection
        self.documentId = documentId
        self.method = method
        self.status = status
        self.durationMs = durationMs
        self.payloadSize = payloadSize
        self.errorMessage = errorMessage
        self.metadata = metadata
    }
}

// MARK: - Network Operation Types

enum NetworkOperation: String, Codable, CaseIterable {
    case read = "READ"
    case write = "WRITE"
    case update = "UPDATE"
    case delete = "DELETE"
    case query = "QUERY"
    case listen = "LISTEN"
    case batch = "BATCH"
    case auth = "AUTH"

    var emoji: String {
        switch self {
        case .read: return "📖"
        case .write: return "✏️"
        case .update: return "🔄"
        case .delete: return "🗑️"
        case .query: return "🔍"
        case .listen: return "👂"
        case .batch: return "📦"
        case .auth: return "🔐"
        }
    }
}

// MARK: - Network Method

enum NetworkMethod: String, Codable {
    case get = "GET"
    case set = "SET"
    case add = "ADD"
    case update = "UPDATE"
    case delete = "DELETE"
    case query = "QUERY"
    case snapshot = "SNAPSHOT"
    case signIn = "SIGN_IN"
    case signOut = "SIGN_OUT"
}

// MARK: - Network Status

enum NetworkStatus: String, Codable {
    case pending = "PENDING"
    case success = "SUCCESS"
    case failure = "FAILURE"
    case cached = "CACHED"
    case timeout = "TIMEOUT"

    var color: String {
        switch self {
        case .pending: return "orange"
        case .success: return "green"
        case .failure: return "red"
        case .cached: return "blue"
        case .timeout: return "yellow"
        }
    }
}

// MARK: - Network Statistics

struct NetworkStatistics {
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var averageLatencyMs: Double = 0
    var totalPayloadBytes: Int = 0
    var requestsByOperation: [NetworkOperation: Int] = [:]
    var requestsByCollection: [String: Int] = [:]

    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests) * 100
    }

    var failureRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(failedRequests) / Double(totalRequests) * 100
    }
}

// MARK: - Request Filter

struct NetworkRequestFilter {
    var operations: Set<NetworkOperation> = Set(NetworkOperation.allCases)
    var statuses: Set<NetworkStatus> = [.success, .failure, .timeout]
    var collections: Set<String>? = nil
    var minDurationMs: Double? = nil
    var searchText: String = ""
    var showOnlyErrors: Bool = false

    func matches(_ request: NetworkRequest) -> Bool {
        // Filter by operation
        guard operations.contains(request.operation) else { return false }

        // Filter by status
        guard statuses.contains(request.status) else { return false }

        // Filter by collection if specified
        if let collections = collections, !collections.isEmpty {
            guard collections.contains(request.collection) else { return false }
        }

        // Filter by minimum duration
        if let minDuration = minDurationMs {
            guard request.durationMs >= minDuration else { return false }
        }

        // Filter by error only
        if showOnlyErrors {
            guard request.status == .failure else { return false }
        }

        // Filter by search text
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let matchesCollection = request.collection.lowercased().contains(searchLower)
            let matchesDocument = request.documentId?.lowercased().contains(searchLower) ?? false
            let matchesError = request.errorMessage?.lowercased().contains(searchLower) ?? false
            guard matchesCollection || matchesDocument || matchesError else { return false }
        }

        return true
    }
}

// MARK: - Slow Request Threshold

struct SlowRequestThreshold {
    static let warning: Double = 500  // 500ms
    static let critical: Double = 2000 // 2 seconds

    static func severity(for durationMs: Double) -> SlowRequestSeverity {
        if durationMs >= critical {
            return .critical
        } else if durationMs >= warning {
            return .warning
        }
        return .normal
    }
}

enum SlowRequestSeverity {
    case normal
    case warning
    case critical

    var color: String {
        switch self {
        case .normal: return "primary"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}
