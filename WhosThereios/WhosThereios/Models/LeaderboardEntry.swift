//
//  LeaderboardEntry.swift
//  WhosThereios
//
//  Created by Claude on 3/19/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Leaderboard Entry

/// Tracks per-user visit stats for a group, stored at groups/{groupId}/leaderboard/{userId}
struct LeaderboardEntry: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var displayName: String
    var level: Int
    var profileEmoji: String?
    var allTimeCheckIns: Int
    var monthlyCheckIns: Int
    var currentMonthKey: String  // e.g. "2026-03"
    var lastCheckInAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case displayName
        case level
        case profileEmoji
        case allTimeCheckIns
        case monthlyCheckIns
        case currentMonthKey
        case lastCheckInAt
    }
}

// MARK: - Leaderboard Timeframe

enum LeaderboardTimeframe: String, CaseIterable {
    case monthly = "This Month"
    case allTime = "All Time"
}

// MARK: - Helpers

extension LeaderboardEntry {
    /// The current month key in "yyyy-MM" format
    static var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    /// Returns the effective monthly check-in count, resetting if the month has changed
    var effectiveMonthlyCheckIns: Int {
        currentMonthKey == Self.currentMonthKey ? monthlyCheckIns : 0
    }
}
