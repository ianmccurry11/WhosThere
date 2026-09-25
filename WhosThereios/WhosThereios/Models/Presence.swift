//
//  Presence.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import FirebaseFirestore

struct Presence: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var groupId: String
    var isPresent: Bool
    var isManual: Bool
    var lastUpdated: Date
    var expiresAt: Date?  // When this presence should auto-expire (nil = no expiration set)
    var displayName: String?
    var isPremium: Bool?
    var profileEmoji: String?
    var level: Int?

    init(
        id: String? = nil,
        userId: String,
        groupId: String,
        isPresent: Bool,
        isManual: Bool = false,
        lastUpdated: Date = Date(),
        expiresAt: Date? = nil,
        displayName: String? = nil,
        isPremium: Bool? = nil,
        profileEmoji: String? = nil,
        level: Int? = nil
    ) {
        self.id = id
        self.userId = userId
        self.groupId = groupId
        self.isPresent = isPresent
        self.isManual = isManual
        self.lastUpdated = lastUpdated
        self.expiresAt = expiresAt
        self.displayName = displayName
        self.isPremium = isPremium
        self.profileEmoji = profileEmoji
        self.level = level
    }

    /// Whether this presence has passed its expiration time
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return Date() >= expiresAt
    }

    /// Hard cap on how long a check-in counts without being refreshed (5 hours).
    /// Also covers legacy records written before `expiresAt` existed.
    static let maxAge: TimeInterval = 5 * 60 * 60

    /// The single rule every screen uses to decide whether someone is "here".
    /// Map bubbles, lists, the group detail sheet, widgets and the watch all go
    /// through this, so they can never disagree.
    func isActive(at now: Date = Date()) -> Bool {
        guard isPresent else { return false }
        if let expiresAt, now >= expiresAt { return false }
        return now.timeIntervalSince(lastUpdated) <= Self.maxAge
    }
}

struct GroupPresenceSummary {
    var groupId: String
    var presentCount: Int
    var presentMembers: [Presence]

    var isEmpty: Bool {
        presentCount == 0
    }
}
