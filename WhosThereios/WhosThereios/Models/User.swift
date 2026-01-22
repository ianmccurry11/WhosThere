//
//  User.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var displayName: String
    var email: String?
    var joinedGroupIds: [String]
    var createdAt: Date
    var autoCheckOutMinutes: Int  // Timer duration in minutes (default 60)

    // Discord-style username system
    var discriminator: String  // 4-digit number (e.g., "5363")
    var usernameTag: String    // Lowercase searchable (e.g., "ian#5363")

    // Push notifications
    var fcmToken: String?

    // Computed property for display
    var fullUsername: String {
        "\(displayName)#\(discriminator)"
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, email, joinedGroupIds, createdAt, autoCheckOutMinutes
        case discriminator, usernameTag, fcmToken
    }

    init(id: String? = nil, displayName: String, email: String? = nil, joinedGroupIds: [String] = [], createdAt: Date = Date(), autoCheckOutMinutes: Int = 60, discriminator: String = "0000", usernameTag: String? = nil, fcmToken: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.joinedGroupIds = joinedGroupIds
        self.createdAt = createdAt
        self.autoCheckOutMinutes = autoCheckOutMinutes
        self.discriminator = discriminator
        self.usernameTag = usernameTag ?? "\(displayName.lowercased())#\(discriminator)"
        self.fcmToken = fcmToken
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        joinedGroupIds = try container.decodeIfPresent([String].self, forKey: .joinedGroupIds) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        autoCheckOutMinutes = try container.decodeIfPresent(Int.self, forKey: .autoCheckOutMinutes) ?? 60

        // Discord-style username - use "XXXX" marker for users needing migration
        discriminator = try container.decodeIfPresent(String.self, forKey: .discriminator) ?? "XXXX"
        let defaultTag = "\(displayName.lowercased())#\(discriminator)"
        usernameTag = try container.decodeIfPresent(String.self, forKey: .usernameTag) ?? defaultTag
        fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
    }

    /// Check if this user needs discriminator migration
    var needsDiscriminatorMigration: Bool {
        discriminator == "XXXX" || discriminator == "0000" || usernameTag.isEmpty
    }
}
