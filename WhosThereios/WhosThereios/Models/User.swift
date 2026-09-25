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
    var favoriteGroupIds: [String]
    var createdAt: Date
    var autoCheckOutMinutes: Int  // Timer duration in minutes (default 60)

    // Discord-style username system
    var discriminator: String  // 4-digit number (e.g., "5363")
    var usernameTag: String    // Lowercase searchable (e.g., "ian#5363")

    // Push notifications
    var fcmToken: String?

    // Premium
    var isPremium: Bool
    var profileEmoji: String?       // Custom emoji avatar (replaces initials)
    var profileColor: String?       // Hex color string for profile accent

    // XP / Level system
    var totalXP: Int
    var level: Int

    // Computed property for display
    var fullUsername: String {
        "\(displayName)#\(discriminator)"
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, email, joinedGroupIds, favoriteGroupIds, createdAt, autoCheckOutMinutes
        case discriminator, usernameTag, fcmToken
        case isPremium, profileEmoji, profileColor
        case totalXP, level
    }

    init(id: String? = nil, displayName: String, email: String? = nil, joinedGroupIds: [String] = [], favoriteGroupIds: [String] = [], createdAt: Date = Date(), autoCheckOutMinutes: Int = 60, discriminator: String = "0000", usernameTag: String? = nil, fcmToken: String? = nil, isPremium: Bool = false, profileEmoji: String? = nil, profileColor: String? = nil, totalXP: Int = 0, level: Int = 1) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.joinedGroupIds = joinedGroupIds
        self.favoriteGroupIds = favoriteGroupIds
        self.createdAt = createdAt
        self.autoCheckOutMinutes = autoCheckOutMinutes
        self.discriminator = discriminator
        self.usernameTag = usernameTag ?? "\(displayName.lowercased())#\(discriminator)"
        self.fcmToken = fcmToken
        self.isPremium = isPremium
        self.profileEmoji = profileEmoji
        self.profileColor = profileColor
        self.totalXP = totalXP
        self.level = level
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        joinedGroupIds = try container.decodeIfPresent([String].self, forKey: .joinedGroupIds) ?? []
        favoriteGroupIds = try container.decodeIfPresent([String].self, forKey: .favoriteGroupIds) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        autoCheckOutMinutes = try container.decodeIfPresent(Int.self, forKey: .autoCheckOutMinutes) ?? 60

        // Discord-style username - use "XXXX" marker for users needing migration
        discriminator = try container.decodeIfPresent(String.self, forKey: .discriminator) ?? "XXXX"
        let defaultTag = "\(displayName.lowercased())#\(discriminator)"
        usernameTag = try container.decodeIfPresent(String.self, forKey: .usernameTag) ?? defaultTag
        fcmToken = try container.decodeIfPresent(String.self, forKey: .fcmToken)
        isPremium = try container.decodeIfPresent(Bool.self, forKey: .isPremium) ?? false
        profileEmoji = try container.decodeIfPresent(String.self, forKey: .profileEmoji)
        profileColor = try container.decodeIfPresent(String.self, forKey: .profileColor)
        totalXP = try container.decodeIfPresent(Int.self, forKey: .totalXP) ?? 0
        level = try container.decodeIfPresent(Int.self, forKey: .level) ?? 1
    }

    /// Check if this user needs discriminator migration
    var needsDiscriminatorMigration: Bool {
        discriminator == "XXXX" || discriminator == "0000" || usernameTag.isEmpty
    }

    /// Check if the display name looks like an auto-generated default
    var hasDefaultName: Bool {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        // "Player XXXX" from anonymous sign-in
        if name.hasPrefix("Player ") && name.count <= 11 { return true }
        // "User XXXX" from Apple sign-in fallback
        if name.hasPrefix("User ") && name.count <= 9 { return true }
        // Just "User"
        if name == "User" { return true }
        // Too short to be a real name
        if name.count < 2 { return true }
        return false
    }
}
