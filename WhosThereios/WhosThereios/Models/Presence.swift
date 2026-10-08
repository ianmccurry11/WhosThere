//
//  Presence.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import FirebaseFirestore
import CoreLocation

/// Timing rules for automatic presence, shared by the app and (mirrored in)
/// the presenceSweep Cloud Function. Tune them here.
enum PresencePolicy {
    /// Confirmed within this long shows as plainly "here"
    static let freshWindow: TimeInterval = 30 * 60
    /// An automatic check-in lasts this long past its last confirmation.
    /// Every background wake that finds you still there pushes it forward.
    static let autoExpiry: TimeInterval = 3 * 60 * 60
    /// A location fix counts as "at the group" within this distance of the
    /// boundary, or within the fix's own accuracy if that's larger
    static let confirmMargin: CLLocationDistance = 30
    /// Fixes less accurate than this can't confirm anything
    static let maxUsableAccuracy: CLLocationDistance = 100
    /// Don't re-confirm more often than this from background wakes
    static let minConfirmInterval: TimeInterval = 5 * 60
    /// Don't ask other members' phones to re-check more often than this per group
    static let recheckRequestInterval: TimeInterval = 5 * 60
}

struct Presence: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var groupId: String
    var isPresent: Bool
    var isManual: Bool
    var lastUpdated: Date
    var expiresAt: Date?  // When this presence should auto-expire (nil = no expiration set)
    var source: String?  // What wrote this: "manual", "geofence", "recheck", "server_expiry"…
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
        source: String? = nil,
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
        self.source = source
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

    /// Automatic check-in whose phone hasn't confirmed it recently.
    /// Still counts as here, but shown as "confirmed 1h ago" and faded.
    func isFading(at now: Date = Date()) -> Bool {
        !isManual && now.timeIntervalSince(lastUpdated) > PresencePolicy.freshWindow
    }

    /// "confirmed 45m ago" / "confirmed 2h ago", or nil while fresh
    func confirmationLabel(at now: Date = Date()) -> String? {
        guard isFading(at: now) else { return nil }
        let minutes = Int(now.timeIntervalSince(lastUpdated) / 60)
        if minutes < 60 {
            return "confirmed \(minutes)m ago"
        }
        return "confirmed \(minutes / 60)h ago"
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
