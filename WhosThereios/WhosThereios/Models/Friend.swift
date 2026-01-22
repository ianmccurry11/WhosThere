//
//  Friend.swift
//  WhosThereios
//
//  Created by Claude on 1/20/26.
//

import Foundation
import FirebaseFirestore

// MARK: - Friend

struct Friend: Identifiable, Codable {
    @DocumentID var id: String?  // Same as friendId
    var addedAt: Date
    var notifyOnArrival: Bool

    // Populated from user lookup (not stored in Firestore)
    var displayName: String?
    var usernameTag: String?
    var discriminator: String?

    var fullUsername: String? {
        guard let name = displayName, let disc = discriminator else { return nil }
        return "\(name)#\(disc)"
    }

    enum CodingKeys: String, CodingKey {
        case id, addedAt, notifyOnArrival
        case displayName, usernameTag, discriminator
    }

    init(id: String? = nil, addedAt: Date = Date(), notifyOnArrival: Bool = true) {
        self.id = id
        self.addedAt = addedAt
        self.notifyOnArrival = notifyOnArrival
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        notifyOnArrival = try container.decodeIfPresent(Bool.self, forKey: .notifyOnArrival) ?? true
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        usernameTag = try container.decodeIfPresent(String.self, forKey: .usernameTag)
        discriminator = try container.decodeIfPresent(String.self, forKey: .discriminator)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Only encode the fields we store in Firestore
        try container.encode(addedAt, forKey: .addedAt)
        try container.encode(notifyOnArrival, forKey: .notifyOnArrival)
    }
}

// MARK: - Friend Request

struct FriendRequest: Identifiable, Codable {
    @DocumentID var id: String?
    var senderId: String
    var receiverId: String
    var senderName: String
    var senderTag: String
    var status: RequestStatus
    var createdAt: Date

    enum RequestStatus: String, Codable {
        case pending
        case accepted
        case declined
    }

    enum CodingKeys: String, CodingKey {
        case id, senderId, receiverId, senderName, senderTag, status, createdAt
    }

    init(senderId: String, receiverId: String, senderName: String, senderTag: String) {
        self.senderId = senderId
        self.receiverId = receiverId
        self.senderName = senderName
        self.senderTag = senderTag
        self.status = .pending
        self.createdAt = Date()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        senderId = try container.decode(String.self, forKey: .senderId)
        receiverId = try container.decode(String.self, forKey: .receiverId)
        senderName = try container.decode(String.self, forKey: .senderName)
        senderTag = try container.decode(String.self, forKey: .senderTag)
        status = try container.decodeIfPresent(RequestStatus.self, forKey: .status) ?? .pending
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// MARK: - Friend Presence Info

struct FriendPresenceInfo: Identifiable {
    var id: String { friendId }
    var friendId: String
    var displayName: String
    var usernameTag: String
    var currentGroups: [GroupPresence]

    var isAtLocation: Bool {
        !currentGroups.isEmpty
    }

    struct GroupPresence: Identifiable {
        var id: String { groupId }
        var groupId: String
        var groupName: String
        var groupEmoji: String
        var arrivedAt: Date
    }
}
