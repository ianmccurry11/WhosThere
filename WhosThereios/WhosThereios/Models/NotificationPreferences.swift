//
//  NotificationPreferences.swift
//  WhosThereios
//
//  Created by Claude on 1/27/26.
//

import Foundation
import FirebaseFirestore

/// Per-group notification preferences for a user
struct NotificationPreferences: Codable {
    @DocumentID var id: String?  // This will be the groupId

    /// Whether to receive notifications when someone arrives at this group
    var arrivals: Bool

    /// Whether to receive notifications when someone leaves this group
    var departures: Bool

    /// Whether to receive notifications for new messages in this group
    var messages: Bool

    /// Whether all notifications for this group are muted
    var muted: Bool

    enum CodingKeys: String, CodingKey {
        case id, arrivals, departures, messages, muted
    }

    init(
        id: String? = nil,
        arrivals: Bool = true,
        departures: Bool = false,
        messages: Bool = true,
        muted: Bool = false
    ) {
        self.id = id
        self.arrivals = arrivals
        self.departures = departures
        self.messages = messages
        self.muted = muted
    }

    /// Default preferences for new groups
    static var defaultPreferences: NotificationPreferences {
        NotificationPreferences(
            arrivals: true,
            departures: false,
            messages: true,
            muted: false
        )
    }

    /// Check if any notifications are enabled (and not muted)
    var hasAnyEnabled: Bool {
        !muted && (arrivals || departures || messages)
    }
}
