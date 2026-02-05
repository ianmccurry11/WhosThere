//
//  FirestoreService.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import Combine
import CoreLocation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FirestoreService: ObservableObject {
    static let shared = FirestoreService()

    private let db = Firestore.firestore()

    @Published var currentUser: User?
    @Published var joinedGroups: [LocationGroup] = []
    @Published var publicGroups: [LocationGroup] = []
    @Published var nearbyGroups: [LocationGroup] = []
    @Published var lastError: AppError?

    private var groupsListener: ListenerRegistration?
    private var presenceListeners: [String: ListenerRegistration] = [:]
    private var achievementService: AchievementService { AchievementService.shared }
    private var analyticsService: AnalyticsService { AnalyticsService.shared }
    private var networkInspector: NetworkInspector { NetworkInspector.shared }

    // MARK: - Error Handling

    private func handleError(_ error: AppError) {
        lastError = error
        if error.shouldLog {
            print("[FirestoreService] Error: \(error.errorDescription ?? "Unknown")")
        }
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - User Operations

    /// Creates a user document if it doesn't exist
    /// - Returns: true if a new user was created, false if user already existed
    @discardableResult
    func createUserIfNeeded(userId: String, displayName: String, email: String?) async -> Bool {
        let userRef = db.collection("users").document(userId)

        do {
            let document = try await userRef.getDocument()
            if !document.exists {
                // Generate a unique discriminator
                let discriminator = await generateUniqueDiscriminator(for: displayName)
                let usernameTag = "\(displayName.lowercased())#\(discriminator)"

                let newUser = User(
                    id: userId,
                    displayName: displayName,
                    email: email,
                    joinedGroupIds: [],
                    createdAt: Date(),
                    discriminator: discriminator,
                    usernameTag: usernameTag
                )
                try userRef.setData(from: newUser)
                self.currentUser = newUser
                return true
            } else {
                self.currentUser = try document.data(as: User.self)

                // Migrate existing users without discriminator
                if self.currentUser?.needsDiscriminatorMigration == true {
                    await migrateUserDiscriminator()
                }
                return false
            }
        } catch {
            print("Error creating user: \(error)")
            return false
        }
    }

    // MARK: - Sequential Discriminator Generation

    /// Gets the next sequential discriminator (0000, 0001, 0002, etc.)
    /// Uses a Firestore counter document for atomic increment
    private func getNextSequentialDiscriminator() async -> String {
        let counterRef = db.collection("counters").document("userDiscriminator")

        do {
            // Use transaction to atomically increment counter
            let newValue = try await db.runTransaction { transaction, errorPointer -> Int? in
                let counterDoc: DocumentSnapshot
                do {
                    counterDoc = try transaction.getDocument(counterRef)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                var currentValue = 0
                if counterDoc.exists, let value = counterDoc.data()?["value"] as? Int {
                    currentValue = value
                }

                let nextValue = currentValue + 1
                transaction.setData(["value": nextValue], forDocument: counterRef)

                return currentValue  // Return the value before increment (so first user gets 0000)
            }

            if let value = newValue as? Int {
                return String(format: "%04d", value % 10000)  // Wrap at 10000
            }
        } catch {
            print("Error getting sequential discriminator: \(error)")
        }

        // Fallback: use timestamp-based discriminator
        let timestamp = Int(Date().timeIntervalSince1970) % 10000
        return String(format: "%04d", timestamp)
    }

    private func generateUniqueDiscriminator(for displayName: String) async -> String {
        // Use sequential discriminator
        return await getNextSequentialDiscriminator()
    }

    private func migrateUserDiscriminator() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let displayName = currentUser?.displayName else { return }

        let discriminator = await getNextSequentialDiscriminator()
        let usernameTag = "\(displayName.lowercased())#\(discriminator)"

        do {
            try await db.collection("users").document(userId).setData([
                "discriminator": discriminator,
                "usernameTag": usernameTag
            ], merge: true)

            self.currentUser?.discriminator = discriminator
            self.currentUser?.usernameTag = usernameTag
            print("Migrated user discriminator: \(usernameTag)")
        } catch {
            print("Error migrating user discriminator: \(error)")
        }
    }

    func fetchCurrentUser() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("fetchCurrentUser: No user ID")
            return
        }

        print("fetchCurrentUser: Fetching user \(userId)")

        let startTime = Date()
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logDocumentRead(collection: "users", documentId: userId, durationMs: duration, success: true)

            if document.exists {
                self.currentUser = try document.data(as: User.self)
                print("fetchCurrentUser: Fetched user with \(self.currentUser?.joinedGroupIds.count ?? 0) groups")
            } else {
                print("fetchCurrentUser: User document does not exist, creating one")
                // Create user document if it doesn't exist (for returning anonymous users)
                await createUserIfNeeded(
                    userId: userId,
                    displayName: "Player \(String(userId.prefix(4)))",
                    email: nil
                )
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logDocumentRead(collection: "users", documentId: userId, durationMs: duration, success: false, error: error)
            print("Error fetching user: \(error)")
        }
    }

    func updateDisplayName(_ name: String) async -> AppResult<Void> {
        guard let userId = Auth.auth().currentUser?.uid else {
            let error = AppError.notAuthenticated
            handleError(error)
            return .failure(error)
        }

        // Validate and sanitize the name
        let sanitizedName = Validation.sanitizeDisplayName(name)
        let validation = Validation.validateDisplayName(sanitizedName)
        if !validation.isValid, let error = validation.error {
            handleError(error)
            return .failure(error)
        }

        // Keep existing discriminator or generate new one
        let discriminator: String
        if let existingDiscriminator = currentUser?.discriminator {
            discriminator = existingDiscriminator
        } else {
            discriminator = await getNextSequentialDiscriminator()
        }
        let usernameTag = "\(sanitizedName.lowercased())#\(discriminator)"

        do {
            try await db.collection("users").document(userId).setData([
                "displayName": sanitizedName,
                "usernameTag": usernameTag
            ], merge: true)
            self.currentUser?.displayName = sanitizedName
            self.currentUser?.usernameTag = usernameTag
            return .success(())
        } catch {
            let appError = AppError.userUpdateFailed(underlying: error)
            handleError(appError)
            return .failure(appError)
        }
    }

    // MARK: - User Search

    func searchUserByExactTag(_ tag: String) async -> User? {
        let lowercaseTag = tag.lowercased()

        do {
            let snapshot = try await db.collection("users")
                .whereField("usernameTag", isEqualTo: lowercaseTag)
                .limit(to: 1)
                .getDocuments()

            return snapshot.documents.first.flatMap { try? $0.data(as: User.self) }
        } catch {
            print("Error searching user by tag: \(error)")
            return nil
        }
    }

    func searchUsersByName(_ query: String) async -> [User] {
        let lowercaseQuery = query.lowercased()

        do {
            // Search by usernameTag prefix
            let snapshot = try await db.collection("users")
                .whereField("usernameTag", isGreaterThanOrEqualTo: lowercaseQuery)
                .whereField("usernameTag", isLessThan: lowercaseQuery + "\u{f8ff}")
                .limit(to: 20)
                .getDocuments()

            return snapshot.documents.compactMap { doc in
                try? doc.data(as: User.self)
            }.filter { $0.id != Auth.auth().currentUser?.uid }  // Exclude self
        } catch {
            print("Error searching users: \(error)")
            return []
        }
    }

    func fetchUserById(_ userId: String) async -> User? {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            return try? document.data(as: User.self)
        } catch {
            print("Error fetching user by ID: \(error)")
            return nil
        }
    }

    func updateAutoCheckOutMinutes(_ minutes: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Error updating auto check-out time: No user ID")
            return
        }

        do {
            try await db.collection("users").document(userId).setData([
                "autoCheckOutMinutes": minutes
            ], merge: true)
            self.currentUser?.autoCheckOutMinutes = minutes
            print("Auto check-out time updated to \(minutes) minutes")
        } catch {
            print("Error updating auto check-out time: \(error)")
        }
    }

    // MARK: - Group Operations

    func createGroup(_ group: LocationGroup) async -> AppResult<String> {
        guard let userId = Auth.auth().currentUser?.uid else {
            let error = AppError.notAuthenticated
            handleError(error)
            return .failure(error)
        }

        // Validate group data
        let validation = Validation.validateGroupData(
            name: group.name,
            boundary: group.boundary,
            centerLatitude: group.centerLatitude,
            centerLongitude: group.centerLongitude
        )
        if !validation.isValid, let error = validation.error {
            handleError(error)
            return .failure(error)
        }

        // Sanitize the group name
        var validatedGroup = group
        validatedGroup.name = Validation.sanitizeGroupName(group.name)

        let startTime = Date()
        do {
            let newDocRef = db.collection("groups").document()
            let groupId = newDocRef.documentID

            let encoder = Firestore.Encoder()
            let groupData = try encoder.encode(validatedGroup)

            print("[FirestoreService] Creating group with ID: \(groupId)")
            try await newDocRef.setData(groupData)
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logDocumentWrite(collection: "groups", documentId: groupId, durationMs: duration, success: true)
            print("[FirestoreService] Group document created successfully")

            // Update user's joinedGroupIds - do this in a separate try/catch so group creation still succeeds
            let userRef = db.collection("users").document(userId)
            do {
                try await userRef.setData([
                    "joinedGroupIds": FieldValue.arrayUnion([groupId])
                ], merge: true)
                print("[FirestoreService] User joinedGroupIds updated successfully")
            } catch {
                // Log but don't fail - the group was created, we can recover by fetching
                print("[FirestoreService] Warning: Failed to update user joinedGroupIds: \(error)")
            }

            // Always update local state
            if self.currentUser != nil {
                self.currentUser?.joinedGroupIds.append(groupId)
            }

            // Add the new group to joinedGroups immediately so it shows up in the UI
            var createdGroup = validatedGroup
            createdGroup.id = groupId
            self.joinedGroups.append(createdGroup)
            print("[FirestoreService] Added group to local joinedGroups array")

            // Track achievement for creating a group
            await achievementService.recordGroupCreated()

            // Track analytics
            analyticsService.trackGroupCreated(
                groupId: groupId,
                hasBoundary: !validatedGroup.boundary.isEmpty,
                isPublic: validatedGroup.isPublic
            )

            print("[FirestoreService] Group creation complete, returning success")
            return .success(groupId)
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logDocumentWrite(collection: "groups", documentId: nil, durationMs: duration, success: false, error: error)
            print("[FirestoreService] Group creation failed with error: \(error)")
            let appError = AppError.groupCreationFailed(underlying: error)
            handleError(appError)
            analyticsService.trackError(errorType: "group_creation_failed", context: "FirestoreService.createGroup", message: error.localizedDescription)
            return .failure(appError)
        }
    }

    func fetchJoinedGroups() async {
        print("fetchJoinedGroups() called")

        guard let userId = Auth.auth().currentUser?.uid else {
            print("No current user, clearing joined groups")
            joinedGroups = []
            return
        }

        // Query groups where the user is in memberIds
        // This is more reliable than tracking joinedGroupIds on the user document
        let startTime = Date()
        do {
            let snapshot = try await db.collection("groups")
                .whereField("memberIds", arrayContains: userId)
                .getDocuments()

            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "groups", durationMs: duration, resultCount: snapshot.documents.count, success: true)

            print("Fetched \(snapshot.documents.count) group documents where user is member")

            self.joinedGroups = snapshot.documents.compactMap { doc in
                do {
                    let group = try doc.data(as: LocationGroup.self)
                    print("Decoded group: \(group.name)")
                    return group
                } catch {
                    print("Error decoding group \(doc.documentID): \(error)")
                    return nil
                }
            }

            print("joinedGroups now has \(joinedGroups.count) groups")

            // Also update the currentUser's joinedGroupIds locally to stay in sync
            if self.currentUser != nil {
                self.currentUser?.joinedGroupIds = self.joinedGroups.compactMap { $0.id }
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "groups", durationMs: duration, resultCount: 0, success: false, error: error)
            print("Error fetching joined groups: \(error)")
        }
    }

    func fetchPublicGroups() async {
        print("fetchPublicGroups() called")
        let startTime = Date()
        do {
            let snapshot = try await db.collection("groups")
                .whereField("isPublic", isEqualTo: true)
                .limit(to: 50)
                .getDocuments()

            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "groups", durationMs: duration, resultCount: snapshot.documents.count, success: true)

            print("Fetched \(snapshot.documents.count) public group documents")

            self.publicGroups = snapshot.documents.compactMap { doc in
                try? doc.data(as: LocationGroup.self)
            }

            print("publicGroups now has \(publicGroups.count) groups")
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "groups", durationMs: duration, resultCount: 0, success: false, error: error)
            print("Error fetching public groups: \(error)")
        }
    }

    func fetchNearbyGroups(center: CLLocationCoordinate2D, radiusKm: Double = 50) async {
        // Fetch both public groups and user's joined groups
        await fetchPublicGroups()
        await fetchJoinedGroups()

        // Combine and filter by distance
        var allGroups = Set<String>()
        var combined: [LocationGroup] = []

        for group in joinedGroups {
            if let id = group.id, !allGroups.contains(id) {
                allGroups.insert(id)
                combined.append(group)
            }
        }

        for group in publicGroups {
            if let id = group.id, !allGroups.contains(id) {
                allGroups.insert(id)
                combined.append(group)
            }
        }

        // Sort by distance
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        self.nearbyGroups = combined.sorted { g1, g2 in
            let loc1 = CLLocation(latitude: g1.centerLatitude, longitude: g1.centerLongitude)
            let loc2 = CLLocation(latitude: g2.centerLatitude, longitude: g2.centerLongitude)
            return centerLocation.distance(from: loc1) < centerLocation.distance(from: loc2)
        }
    }

    func joinGroup(groupId: String) async -> AppResult<Void> {
        guard let userId = Auth.auth().currentUser?.uid else {
            let error = AppError.notAuthenticated
            handleError(error)
            return .failure(error)
        }

        // Check if already a member
        if currentUser?.joinedGroupIds.contains(groupId) == true {
            let error = AppError.alreadyGroupMember
            handleError(error)
            return .failure(error)
        }

        do {
            // Primary operation: add user to group's memberIds
            try await db.collection("groups").document(groupId).updateData([
                "memberIds": FieldValue.arrayUnion([userId])
            ])

            // Secondary operation: update user's joinedGroupIds (non-critical)
            // This may fail if user doc doesn't exist, but group membership is the source of truth
            do {
                try await db.collection("users").document(userId).setData([
                    "joinedGroupIds": FieldValue.arrayUnion([groupId])
                ], merge: true)
            } catch {
                print("[FirestoreService] Warning: Failed to update user joinedGroupIds: \(error)")
            }

            // Update local state immediately
            if self.currentUser != nil && !self.currentUser!.joinedGroupIds.contains(groupId) {
                self.currentUser?.joinedGroupIds.append(groupId)
            }

            // Fetch updated data
            await fetchJoinedGroups()

            // Track achievement for joining a group
            await achievementService.recordGroupJoined()

            // Track analytics
            analyticsService.trackGroupJoined(groupId: groupId, joinMethod: "direct")

            return .success(())
        } catch {
            let appError = AppError.groupUpdateFailed(underlying: error)
            handleError(appError)
            analyticsService.trackError(errorType: "group_join_failed", context: "FirestoreService.joinGroup", message: error.localizedDescription)
            return .failure(appError)
        }
    }

    func leaveGroup(groupId: String) async -> AppResult<Void> {
        guard let userId = Auth.auth().currentUser?.uid else {
            let error = AppError.notAuthenticated
            handleError(error)
            return .failure(error)
        }

        // Check if user is a member
        if currentUser?.joinedGroupIds.contains(groupId) != true {
            let error = AppError.notGroupMember
            handleError(error)
            return .failure(error)
        }

        do {
            // Primary operation: remove user from group's memberIds
            try await db.collection("groups").document(groupId).updateData([
                "memberIds": FieldValue.arrayRemove([userId])
            ])

            // Secondary operation: update user's joinedGroupIds (non-critical)
            do {
                try await db.collection("users").document(userId).setData([
                    "joinedGroupIds": FieldValue.arrayRemove([groupId])
                ], merge: true)
            } catch {
                print("[FirestoreService] Warning: Failed to update user joinedGroupIds: \(error)")
            }

            // Clean up presence (non-critical)
            try? await db.collection("presence").document(groupId)
                .collection("members").document(userId).delete()

            // Update local state immediately
            self.currentUser?.joinedGroupIds.removeAll { $0 == groupId }

            // Fetch updated data
            await fetchJoinedGroups()

            // Track analytics
            analyticsService.trackGroupLeft(groupId: groupId, wasOwner: false)

            return .success(())
        } catch {
            let appError = AppError.groupUpdateFailed(underlying: error)
            handleError(appError)
            analyticsService.trackError(errorType: "group_leave_failed", context: "FirestoreService.leaveGroup", message: error.localizedDescription)
            return .failure(appError)
        }
    }

    func deleteGroup(groupId: String) async -> AppResult<Void> {
        guard let userId = Auth.auth().currentUser?.uid else {
            let error = AppError.notAuthenticated
            handleError(error)
            return .failure(error)
        }

        do {
            let groupDoc = try await db.collection("groups").document(groupId).getDocument()

            guard groupDoc.exists else {
                let error = AppError.groupNotFound
                handleError(error)
                return .failure(error)
            }

            guard let group = try? groupDoc.data(as: LocationGroup.self) else {
                let error = AppError.groupNotFound
                handleError(error)
                return .failure(error)
            }

            guard group.ownerId == userId else {
                let error = AppError.notGroupOwner
                handleError(error)
                return .failure(error)
            }

            // Delete presence subcollection
            let presenceDocs = try await db.collection("presence").document(groupId)
                .collection("members").getDocuments()
            for doc in presenceDocs.documents {
                try? await doc.reference.delete()
            }

            // Remove group from all members' joined groups
            for memberId in group.memberIds {
                try? await db.collection("users").document(memberId).setData([
                    "joinedGroupIds": FieldValue.arrayRemove([groupId])
                ], merge: true)
            }

            // Delete the group
            try await db.collection("groups").document(groupId).delete()

            await fetchJoinedGroups()
            await fetchPublicGroups()

            // Track analytics
            analyticsService.trackGroupDeleted(groupId: groupId, memberCount: group.memberIds.count)

            return .success(())
        } catch {
            let appError = AppError.groupDeletionFailed(underlying: error)
            handleError(appError)
            analyticsService.trackError(errorType: "group_deletion_failed", context: "FirestoreService.deleteGroup", message: error.localizedDescription)
            return .failure(appError)
        }
    }

    func updateGroupSettings(groupId: String, name: String, emoji: String, presenceMode: PresenceDisplayMode) async {
        do {
            try await db.collection("groups").document(groupId).updateData([
                "name": name,
                "emoji": emoji,
                "presenceDisplayMode": presenceMode.rawValue
            ])
        } catch {
            print("Error updating group settings: \(error)")
        }
    }

    func updateGroupBoundary(groupId: String, boundary: [Coordinate]) async {
        // Validate boundary before saving
        let validationResult = Validation.validateBoundary(boundary)
        guard validationResult.isValid else {
            print("Invalid boundary: \(validationResult.error?.userMessage ?? "Unknown error")")
            return
        }

        // Calculate new center coordinates
        let latitudes = boundary.map { $0.latitude }
        let longitudes = boundary.map { $0.longitude }
        let centerLat = (latitudes.min()! + latitudes.max()!) / 2
        let centerLon = (longitudes.min()! + longitudes.max()!) / 2

        // Convert boundary to Firestore format
        let boundaryData = boundary.map { ["latitude": $0.latitude, "longitude": $0.longitude] }

        do {
            try await db.collection("groups").document(groupId).updateData([
                "boundary": boundaryData,
                "centerLatitude": centerLat,
                "centerLongitude": centerLon
            ])

            // Update geofencing for this group
            await updateGeofenceForGroup(groupId: groupId, boundary: boundary)

            print("Group boundary updated successfully")
        } catch {
            print("Error updating group boundary: \(error)")
        }
    }

    private func updateGeofenceForGroup(groupId: String, boundary: [Coordinate]) async {
        // Notify LocationService to update geofencing
        let coordinates = boundary.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        await LocationService.shared.updateGeofenceForGroup(groupId: groupId, coordinates: coordinates)
    }

    func findGroupByInviteCode(_ code: String) async -> LocationGroup? {
        do {
            let snapshot = try await db.collection("groups")
                .whereField("inviteCode", isEqualTo: code)
                .limit(to: 1)
                .getDocuments()

            return snapshot.documents.first.flatMap { try? $0.data(as: LocationGroup.self) }
        } catch {
            print("Error finding group by invite code: \(error)")
            return nil
        }
    }

    // MARK: - Presence Operations

    func updatePresence(groupId: String, isPresent: Bool, isManual: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let presence = Presence(
            userId: userId,
            groupId: groupId,
            isPresent: isPresent,
            isManual: isManual,
            lastUpdated: Date(),
            displayName: currentUser?.displayName
        )

        do {
            try db.collection("presence").document(groupId)
                .collection("members").document(userId).setData(from: presence)
        } catch {
            print("Error updating presence: \(error)")
        }
    }

    func fetchPresenceForGroup(groupId: String) async -> [Presence] {
        let startTime = Date()
        do {
            let snapshot = try await db.collection("presence").document(groupId)
                .collection("members")
                .whereField("isPresent", isEqualTo: true)
                .getDocuments()

            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "presence/\(groupId)/members", durationMs: duration, resultCount: snapshot.documents.count, success: true)

            return snapshot.documents.compactMap { doc in
                try? doc.data(as: Presence.self)
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "presence/\(groupId)/members", durationMs: duration, resultCount: 0, success: false, error: error)
            print("Error fetching presence: \(error)")
            return []
        }
    }

    func listenToPresence(groupId: String, completion: @escaping ([Presence]) -> Void) -> ListenerRegistration {
        return db.collection("presence").document(groupId)
            .collection("members")
            .whereField("isPresent", isEqualTo: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let presences = documents.compactMap { doc in
                    try? doc.data(as: Presence.self)
                }
                completion(presences)
            }
    }

    func clearAllPresence() async {
        guard let user = currentUser else { return }

        for groupId in user.joinedGroupIds {
            await updatePresence(groupId: groupId, isPresent: false, isManual: true)
        }
    }

    // MARK: - Invite Code

    func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}
