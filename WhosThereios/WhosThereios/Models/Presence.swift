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
}

struct GroupPresenceSummary {
    var groupId: String
    var presentCount: Int
    var presentMembers: [Presence]

    var isEmpty: Bool {
        presentCount == 0
    }
}
