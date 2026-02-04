//
//  ChatService.swift
//  WhosThereios
//
//  Created by Claude on 1/16/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class ChatService: ObservableObject {
    private let db = Firestore.firestore()
    private var messageListener: ListenerRegistration?
    private var lastMessageTime: Date?
    private var analyticsService: AnalyticsService { AnalyticsService.shared }

    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var error: String?

    private let groupId: String

    init(groupId: String) {
        self.groupId = groupId
    }

    deinit {
        // Remove listener directly without calling actor-isolated method
        messageListener?.remove()
    }

    // MARK: - Real-time Listening

    func startListening() {
        isLoading = true

        // Listen to messages ordered by creation time, limited to max messages
        messageListener = db.collection("groups")
            .document(groupId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .limit(toLast: Message.maxMessagesPerGroup)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                self.isLoading = false

                if let error = error {
                    self.error = "Failed to load messages: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else {
                    self.messages = []
                    return
                }

                self.messages = documents.compactMap { doc in
                    try? doc.data(as: Message.self)
                }
            }
    }

    func stopListening() {
        messageListener?.remove()
        messageListener = nil
    }

    // MARK: - Send Message

    func sendMessage(_ text: String) async -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate message
        guard !trimmedText.isEmpty else {
            error = "Message cannot be empty"
            return false
        }

        guard trimmedText.count <= Message.maxMessageLength else {
            error = "Message is too long (max \(Message.maxMessageLength) characters)"
            return false
        }

        // Rate limiting
        if let lastTime = lastMessageTime,
           Date().timeIntervalSince(lastTime) < Message.rateLimitSeconds {
            error = "Please wait before sending another message"
            return false
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            error = "Not authenticated"
            return false
        }

        // Get sender name
        let senderName = await getSenderName(userId: userId)

        let message = Message(
            groupId: groupId,
            senderId: userId,
            senderName: senderName,
            text: trimmedText
        )

        do {
            let encoder = Firestore.Encoder()
            let messageData = try encoder.encode(message)

            try await db.collection("groups")
                .document(groupId)
                .collection("messages")
                .addDocument(data: messageData)

            lastMessageTime = Date()
            error = nil

            // Track analytics
            analyticsService.trackMessageSent(groupId: groupId, messageLength: trimmedText.count)

            // Cleanup old messages in background
            Task {
                await cleanupOldMessages()
            }

            return true
        } catch {
            self.error = "Failed to send message: \(error.localizedDescription)"
            analyticsService.trackError(errorType: "message_send_failed", context: "ChatService.sendMessage", message: error.localizedDescription)
            return false
        }
    }

    // MARK: - Helpers

    private func getSenderName(userId: String) async -> String {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            if let data = userDoc.data(),
               let name = data["displayName"] as? String {
                return name
            }
        } catch {
            print("Error fetching sender name: \(error)")
        }
        return "Unknown"
    }

    // MARK: - Cleanup

    /// Removes messages older than maxAgeInDays
    private func cleanupOldMessages() async {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -Message.maxAgeInDays,
            to: Date()
        ) ?? Date()

        do {
            let oldMessages = try await db.collection("groups")
                .document(groupId)
                .collection("messages")
                .whereField("createdAt", isLessThan: Timestamp(date: cutoffDate))
                .getDocuments()

            for doc in oldMessages.documents {
                try? await doc.reference.delete()
            }

            if !oldMessages.documents.isEmpty {
                print("Cleaned up \(oldMessages.documents.count) old messages")
            }
        } catch {
            print("Error cleaning up old messages: \(error)")
        }
    }

    /// Prunes messages if count exceeds limit (keeps newest)
    func pruneExcessMessages() async {
        do {
            let allMessages = try await db.collection("groups")
                .document(groupId)
                .collection("messages")
                .order(by: "createdAt", descending: false)
                .getDocuments()

            let excessCount = allMessages.documents.count - Message.maxMessagesPerGroup
            if excessCount > 0 {
                // Delete oldest messages
                let toDelete = allMessages.documents.prefix(excessCount)
                for doc in toDelete {
                    try? await doc.reference.delete()
                }
                print("Pruned \(excessCount) excess messages")
            }
        } catch {
            print("Error pruning messages: \(error)")
        }
    }
}

// MARK: - Unread Count Helper

extension ChatService {
    /// Gets unread message count since a given date
    static func getUnreadCount(groupId: String, since: Date) async -> Int {
        let db = Firestore.firestore()

        do {
            let snapshot = try await db.collection("groups")
                .document(groupId)
                .collection("messages")
                .whereField("createdAt", isGreaterThan: Timestamp(date: since))
                .getDocuments()

            return snapshot.documents.count
        } catch {
            print("Error getting unread count: \(error)")
            return 0
        }
    }
}
