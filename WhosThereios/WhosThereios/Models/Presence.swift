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
    /// Don't ask other members' phones to re-check more often than this per group
    static let recheckRequestInterval: TimeInterval = 5 * 60

    // MARK: Detection

    /// Clearly gone: farther than this (plus the fix's accuracy) from the boundary.
    /// Between `confirmMargin` and this nothing changes, so people don't flicker.
    static let exitMargin: CLLocationDistance = 75
    /// Without a geofence exit or visit departure, need to be clearly gone for
    /// this long (two readings) before checking out
    static let exitConfirmDelay: TimeInterval = 2 * 60
    /// While inside, rewrite the check-in at most this often to keep it fresh
    static let refreshInterval: TimeInterval = 10 * 60
    /// While the app is open, evaluate the location stream at most this often
    static let foregroundEvaluationInterval: TimeInterval = 15
    /// Only evaluate groups within this distance (plus ones you're checked in to)
    static let candidateDistance: CLLocationDistance = 2_000
    /// iOS geofences smaller than this are unreliable
    static let minRegionRadius: CLLocationDistance = 150
    /// Radius of the "you moved, refresh the nearest geofences" ring
    static let refreshRingRadius: CLLocationDistance = 1_500
}

/// Where a location fix puts the user relative to a group's boundary
enum ZoneReading: Equatable {
    /// Within the margin: counts as there
    case inside
    /// Just outside the margin but not clearly gone: keep whatever state we have
    case nearby
    /// Clearly away from the group
    case outside
    /// The fix is too inaccurate to tell
    case unknown
}

/// What to do with the user's automatic presence at one group
enum AutoPresenceAction: Equatable {
    case checkIn
    case refresh
    case checkOut
    /// They manually checked out and have now left: allow auto check-in again
    case clearSuppression
    case none
}

/// The user's own state at one group, as far as detection is concerned
struct AutoPresenceState {
    var isAutoCheckedIn = false
    var isManuallyCheckedIn = false
    /// Manually checked out here; no auto check-in until they leave
    var isSuppressed = false
    /// When their presence doc was last written
    var lastWrite: Date?
    /// When readings first said "clearly outside" (reset by any other reading)
    var outsideSince: Date?
}

enum AutoPresenceDecider {
    /// The whole check-in/check-out rule in one place.
    /// - Parameter hasExitSignal: iOS independently reported leaving (geofence
    ///   exit or visit departure), so one "outside" reading is enough.
    static func decide(
        reading: ZoneReading,
        state: AutoPresenceState,
        hasExitSignal: Bool,
        now: Date = Date()
    ) -> AutoPresenceAction {
        switch reading {
        case .unknown, .nearby:
            return .none

        case .inside:
            if state.isSuppressed { return .none }
            if !state.isAutoCheckedIn { return .checkIn }
            if let lastWrite = state.lastWrite,
               now.timeIntervalSince(lastWrite) < PresencePolicy.refreshInterval {
                return .none
            }
            return .refresh

        case .outside:
            if state.isSuppressed { return .clearSuppression }
            guard state.isAutoCheckedIn, !state.isManuallyCheckedIn else { return .none }
            if hasExitSignal { return .checkOut }
            if let outsideSince = state.outsideSince,
               now.timeIntervalSince(outsideSince) >= PresencePolicy.exitConfirmDelay {
                return .checkOut
            }
            return .none
        }
    }
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
