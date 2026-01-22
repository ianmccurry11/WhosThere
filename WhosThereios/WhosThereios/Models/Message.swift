//
//  Message.swift
//  WhosThereios
//
//  Created by Claude on 1/16/26.
//

import Foundation
import FirebaseFirestore

/// Represents a chat message in a group
struct Message: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    let groupId: String
    let senderId: String
    let senderName: String
    let text: String
    let createdAt: Date

    /// Messages older than this will be auto-deleted
    static let maxAgeInDays: Int = 7

    /// Maximum messages to keep per group
    static let maxMessagesPerGroup: Int = 100

    /// Maximum message length
    static let maxMessageLength: Int = 500

    /// Minimum time between messages from same user (seconds)
    static let rateLimitSeconds: TimeInterval = 2

    init(groupId: String, senderId: String, senderName: String, text: String) {
        self.groupId = groupId
        self.senderId = senderId
        self.senderName = senderName
        self.text = String(text.prefix(Message.maxMessageLength))
        self.createdAt = Date()
    }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id
    }
}

/// Represents the metadata for a group's chat
struct ChatMetadata: Codable {
    let lastMessageAt: Date?
    let lastMessagePreview: String?
    let lastSenderName: String?
    let unreadCount: Int

    init(lastMessageAt: Date? = nil, lastMessagePreview: String? = nil, lastSenderName: String? = nil, unreadCount: Int = 0) {
        self.lastMessageAt = lastMessageAt
        self.lastMessagePreview = lastMessagePreview
        self.lastSenderName = lastSenderName
        self.unreadCount = unreadCount
    }
}
