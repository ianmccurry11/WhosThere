//
//  FriendService.swift
//  WhosThereios
//
//  Created by Claude on 1/20/26.
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FriendService: ObservableObject {
    static let shared = FriendService()

    private let db = Firestore.firestore()
    private var firestoreService: FirestoreService { FirestoreService.shared }
    private var presenceService: PresenceService { PresenceService.shared }

    @Published var friends: [Friend] = []
    @Published var pendingRequests: [FriendRequest] = []
    @Published var sentRequests: [FriendRequest] = []
    @Published var friendPresences: [String: FriendPresenceInfo] = [:]

    private var requestsListener: ListenerRegistration?
    private var friendsListener: ListenerRegistration?

    init() {
        // Start listening when service is created
        Task {
            await loadFriends()
            listenForRequests()
        }
    }

    deinit {
        requestsListener?.remove()
        friendsListener?.remove()
    }

    // MARK: - Load Friends

    func loadFriends() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("friends")
                .getDocuments()

            var loadedFriends: [Friend] = []

            for doc in snapshot.documents {
                var friend = try doc.data(as: Friend.self)

                // Fetch friend's user data to populate display info
                if let friendId = friend.id,
                   let friendUser = await firestoreService.fetchUserById(friendId) {
                    friend.displayName = friendUser.displayName
                    friend.usernameTag = friendUser.usernameTag
                    friend.discriminator = friendUser.discriminator
                }

                loadedFriends.append(friend)
            }

            self.friends = loadedFriends
            print("Loaded \(friends.count) friends")

            // Fetch presence for all friends
            await fetchFriendsPresence()
        } catch {
            print("Error loading friends: \(error)")
        }
    }

    // MARK: - Friend Requests

    func sendFriendRequest(toUserId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let currentUser = firestoreService.currentUser else {
            throw FriendError.notAuthenticated
        }

        // Check if already friends
        if friends.contains(where: { $0.id == toUserId }) {
            throw FriendError.alreadyFriends
        }

        // Check if request already sent
        if sentRequests.contains(where: { $0.receiverId == toUserId && $0.status == .pending }) {
            throw FriendError.requestAlreadySent
        }

        // Check if they already sent us a request
        if let existingRequest = pendingRequests.first(where: { $0.senderId == toUserId }) {
            // Auto-accept their request instead
            try await acceptRequest(existingRequest)
            return
        }

        let request = FriendRequest(
            senderId: userId,
            receiverId: toUserId,
            senderName: currentUser.displayName,
            senderTag: currentUser.usernameTag
        )

        do {
            try db.collection("friendRequests").addDocument(from: request)
            print("Friend request sent to \(toUserId)")
        } catch {
            throw FriendError.requestFailed(error)
        }
    }

    func acceptRequest(_ request: FriendRequest) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let requestId = request.id else {
            throw FriendError.notAuthenticated
        }

        let batch = db.batch()

        // Update request status
        let requestRef = db.collection("friendRequests").document(requestId)
        batch.updateData(["status": FriendRequest.RequestStatus.accepted.rawValue], forDocument: requestRef)

        // Add to my friends list
        let myFriendRef = db.collection("users").document(userId)
            .collection("friends").document(request.senderId)
        let myFriend = Friend(id: request.senderId)
        try batch.setData(from: myFriend, forDocument: myFriendRef)

        // Add me to their friends list
        let theirFriendRef = db.collection("users").document(request.senderId)
            .collection("friends").document(userId)
        let theirFriend = Friend(id: userId)
        try batch.setData(from: theirFriend, forDocument: theirFriendRef)

        do {
            try await batch.commit()
            print("Friend request accepted from \(request.senderId)")

            // Reload friends
            await loadFriends()
        } catch {
            throw FriendError.requestFailed(error)
        }
    }

    func declineRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else {
            throw FriendError.invalidRequest
        }

        do {
            try await db.collection("friendRequests").document(requestId).updateData([
                "status": FriendRequest.RequestStatus.declined.rawValue
            ])
            print("Friend request declined from \(request.senderId)")
        } catch {
            throw FriendError.requestFailed(error)
        }
    }

    func cancelRequest(_ request: FriendRequest) async throws {
        guard let requestId = request.id else {
            throw FriendError.invalidRequest
        }

        do {
            try await db.collection("friendRequests").document(requestId).delete()
            print("Friend request cancelled to \(request.receiverId)")
        } catch {
            throw FriendError.requestFailed(error)
        }
    }

    func removeFriend(_ friendId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FriendError.notAuthenticated
        }

        let batch = db.batch()

        // Remove from my friends
        let myFriendRef = db.collection("users").document(userId)
            .collection("friends").document(friendId)
        batch.deleteDocument(myFriendRef)

        // Remove me from their friends
        let theirFriendRef = db.collection("users").document(friendId)
            .collection("friends").document(userId)
        batch.deleteDocument(theirFriendRef)

        do {
            try await batch.commit()
            friends.removeAll { $0.id == friendId }
            friendPresences.removeValue(forKey: friendId)
            print("Removed friend \(friendId)")
        } catch {
            throw FriendError.removeFailed(error)
        }
    }

    // MARK: - Listen for Requests

    func listenForRequests() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Listen for incoming requests
        requestsListener = db.collection("friendRequests")
            .whereField("receiverId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequest.RequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }

                self?.pendingRequests = documents.compactMap { doc in
                    try? doc.data(as: FriendRequest.self)
                }

                print("Updated pending requests: \(self?.pendingRequests.count ?? 0)")
            }

        // Also listen for sent requests
        db.collection("friendRequests")
            .whereField("senderId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendRequest.RequestStatus.pending.rawValue)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else { return }

                self?.sentRequests = documents.compactMap { doc in
                    try? doc.data(as: FriendRequest.self)
                }
            }
    }

    // MARK: - Friend Presence

    func fetchFriendsPresence() async {
        guard !friends.isEmpty else { return }

        var presences: [String: FriendPresenceInfo] = [:]

        // Get all groups the user is in
        let joinedGroups = firestoreService.joinedGroups

        for friend in friends {
            guard let friendId = friend.id else { continue }

            var groupPresences: [FriendPresenceInfo.GroupPresence] = []

            // Check each group for friend's presence
            for group in joinedGroups {
                guard let groupId = group.id else { continue }

                // Check if friend is a member of this group
                if group.memberIds.contains(friendId) {
                    // Check their presence
                    if let presence = presenceService.getPresenceSummary(for: groupId),
                       presence.presentMembers.contains(where: { $0.userId == friendId }) {

                        let groupPresence = FriendPresenceInfo.GroupPresence(
                            groupId: groupId,
                            groupName: group.name,
                            groupEmoji: group.displayEmoji,
                            arrivedAt: presence.presentMembers.first { $0.userId == friendId }?.lastUpdated ?? Date()
                        )
                        groupPresences.append(groupPresence)
                    }
                }
            }

            if !groupPresences.isEmpty || true {  // Always create presence info for friends
                presences[friendId] = FriendPresenceInfo(
                    friendId: friendId,
                    displayName: friend.displayName ?? "Unknown",
                    usernameTag: friend.usernameTag ?? "",
                    currentGroups: groupPresences
                )
            }
        }

        self.friendPresences = presences
    }

    // MARK: - Notification Settings

    func updateFriendNotification(friendId: String, notifyOnArrival: Bool) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw FriendError.notAuthenticated
        }

        do {
            try await db.collection("users").document(userId)
                .collection("friends").document(friendId)
                .updateData(["notifyOnArrival": notifyOnArrival])

            if let index = friends.firstIndex(where: { $0.id == friendId }) {
                friends[index].notifyOnArrival = notifyOnArrival
            }
        } catch {
            throw FriendError.updateFailed(error)
        }
    }

    // MARK: - Helpers

    var friendsAtLocation: [FriendPresenceInfo] {
        friendPresences.values.filter { $0.isAtLocation }.sorted { $0.displayName < $1.displayName }
    }

    var friendsNotAtLocation: [Friend] {
        friends.filter { friend in
            guard let id = friend.id else { return true }
            return !(friendPresences[id]?.isAtLocation ?? false)
        }.sorted { ($0.displayName ?? "") < ($1.displayName ?? "") }
    }
}

// MARK: - Friend Errors

enum FriendError: LocalizedError {
    case notAuthenticated
    case alreadyFriends
    case requestAlreadySent
    case requestFailed(Error)
    case removeFailed(Error)
    case updateFailed(Error)
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to manage friends"
        case .alreadyFriends:
            return "You're already friends with this user"
        case .requestAlreadySent:
            return "Friend request already sent"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .removeFailed(let error):
            return "Failed to remove friend: \(error.localizedDescription)"
        case .updateFailed(let error):
            return "Failed to update: \(error.localizedDescription)"
        case .invalidRequest:
            return "Invalid request"
        }
    }
}
