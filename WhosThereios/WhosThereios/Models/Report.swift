//
//  Report.swift
//  WhosThereios
//
//  User content report model for moderation.
//

import Foundation
import FirebaseFirestore

struct Report: Identifiable, Codable {
    @DocumentID var id: String?
    var reporterId: String          // Who filed the report
    var reportedUserId: String      // Who is being reported
    var reportedDisplayName: String  // Snapshot of the reported user's name at time of report
    var reason: ReportReason        // Category of the report
    var context: ReportContext      // Where the report originated
    var details: String?            // Optional free-text details from reporter
    var groupId: String?            // Group where the issue occurred (if applicable)
    var messageId: String?          // Specific message (if reporting a chat message)
    var messageText: String?        // Snapshot of the message text (if applicable)
    var status: ReportStatus        // Current status of the report
    var createdAt: Date
}

enum ReportReason: String, Codable, CaseIterable {
    case inappropriateName = "inappropriate_name"
    case harassmentOrBullying = "harassment_or_bullying"
    case spam = "spam"
    case inappropriateMessages = "inappropriate_messages"
    case other = "other"

    var displayName: String {
        switch self {
        case .inappropriateName: return "Inappropriate Name"
        case .harassmentOrBullying: return "Harassment or Bullying"
        case .spam: return "Spam"
        case .inappropriateMessages: return "Inappropriate Messages"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .inappropriateName: return "textformat.abc.dottedunderline"
        case .harassmentOrBullying: return "hand.raised"
        case .spam: return "exclamationmark.bubble"
        case .inappropriateMessages: return "bubble.left.and.exclamationmark.bubble.right"
        case .other: return "flag"
        }
    }
}

enum ReportContext: String, Codable {
    case presence = "presence"     // From "Who's Here" member list
    case chat = "chat"             // From a chat message
    case friendRequest = "friend_request"
    case friendList = "friend_list"
}

enum ReportStatus: String, Codable {
    case pending = "pending"
    case reviewed = "reviewed"
    case resolved = "resolved"
    case dismissed = "dismissed"
}
