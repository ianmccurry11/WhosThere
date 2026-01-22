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
    var displayName: String?

    init(
        id: String? = nil,
        userId: String,
        groupId: String,
        isPresent: Bool,
        isManual: Bool = false,
        lastUpdated: Date = Date(),
        displayName: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.groupId = groupId
        self.isPresent = isPresent
        self.isManual = isManual
        self.lastUpdated = lastUpdated
        self.displayName = displayName
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
