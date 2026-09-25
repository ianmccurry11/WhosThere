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

/// Central Firestore data access layer. All database operations go through this service.
/// Collections: users, groups, presence, friendRequests, counters, reports
/// See FIRESTORE_SCHEMA.md for the complete data contract.
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

    // MARK: - Cached Display Name

    private static let cachedDisplayNameKey = "cachedUserDisplayName"
    private static let cachedUserLevelKey = "cachedUserLevel"

    /// Returns the locally cached displayName, available even before Firestore loads.
    var cachedDisplayName: String? {
        UserDefaults.standard.string(forKey: Self.cachedDisplayNameKey)
    }

    var cachedUserLevel: Int {
        let level = UserDefaults.standard.integer(forKey: Self.cachedUserLevelKey)
        return level > 0 ? level : 1
    }

    /// Persists the current user's displayName and level to UserDefaults.
    private func cacheUserInfo() {
        if let name = currentUser?.displayName {
            UserDefaults.standard.set(name, forKey: Self.cachedDisplayNameKey)
        }
        UserDefaults.standard.set(currentUser?.level ?? 1, forKey: Self.cachedUserLevelKey)
    }

    /// Clears cached user info (call on sign-out / account deletion).
    private func clearCachedUserInfo() {
        UserDefaults.standard.removeObject(forKey: Self.cachedDisplayNameKey)
        UserDefaults.standard.removeObject(forKey: Self.cachedUserLevelKey)
    }

    // MARK: - Error Handling

    private func handleError(_ error: AppError) {
        lastError = error
        if error.shouldLog {
            AppLogger.debug("[FirestoreService] Error: \(error.errorDescription ?? "Unknown")")
        }
    }

    func clearError() {
        lastError = nil
    }

    // MARK: - User Operations (users collection)

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
                cacheUserInfo()
                return true
            } else {
                self.currentUser = try document.data(as: User.self)
                cacheUserInfo()

                // Migrate existing users without discriminator
                if self.currentUser?.needsDiscriminatorMigration == true {
                    await migrateUserDiscriminator()
                }
                return false
            }
        } catch {
            AppLogger.debug("Error creating user: \(error)")
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
            AppLogger.debug("Error getting sequential discriminator: \(error)")
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
            AppLogger.debug("Migrated user discriminator: \(usernameTag)")
        } catch {
            AppLogger.debug("Error migrating user discriminator: \(error)")
        }
    }

    func fetchCurrentUser() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            AppLogger.debug("fetchCurrentUser: No user ID")
            return
        }

        AppLogger.debug("fetchCurrentUser: Fetching user \(userId)")

        let startTime = Date()
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logDocumentRead(collection: "users", documentId: userId, durationMs: duration, success: true)

            if document.exists {
                self.currentUser = try document.data(as: User.self)
                cacheUserInfo()
                AppLogger.debug("fetchCurrentUser: Fetched user with \(self.currentUser?.joinedGroupIds.count ?? 0) groups")

                // Re-patch any active presences that were written with a nil displayName
                await repatchPresencesIfNeeded()
            } else {
                AppLogger.debug("fetchCurrentUser: User document does not exist, creating one")
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
            AppLogger.debug("Error fetching user: \(error)")
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
            cacheUserInfo()

            // Also persist to Firebase Auth profile — available immediately on app launch
            // from Keychain, even before any Firestore fetch. This is the strongest
            // safeguard against the "Unknown" name issue on background geofence wakes.
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = sanitizedName
            try? await changeRequest?.commitChanges()

            await achievementService.recordDisplayNameSet()
            return .success(())
        } catch {
            let appError = AppError.userUpdateFailed(underlying: error)
            handleError(appError)
            return .failure(appError)
        }
    }

    // MARK: - Favorite Groups

    func isGroupFavorited(groupId: String) -> Bool {
        currentUser?.favoriteGroupIds.contains(groupId) ?? false
    }

    func toggleFavoriteGroup(groupId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let isFavorited = isGroupFavorited(groupId: groupId)

        do {
            if isFavorited {
                try await db.collection("users").document(userId).updateData([
                    "favoriteGroupIds": FieldValue.arrayRemove([groupId])
                ])
                currentUser?.favoriteGroupIds.removeAll { $0 == groupId }
            } else {
                try await db.collection("users").document(userId).updateData([
                    "favoriteGroupIds": FieldValue.arrayUnion([groupId])
                ])
                currentUser?.favoriteGroupIds.append(groupId)
            }

            // Sync updated favorites to widget
            WidgetDataService.shared.syncToWidget()

            // Track achievement for favorites count
            let favoriteCount = currentUser?.favoriteGroupIds.count ?? 0
            await achievementService.recordFavoriteCountChanged(count: favoriteCount)
        } catch {
            AppLogger.debug("Error toggling favorite: \(error)")
        }
    }

    // MARK: - Fetch Group by ID

    func fetchGroupById(_ groupId: String) async -> LocationGroup? {
        do {
            let doc = try await db.collection("groups").document(groupId).getDocument()
            return try doc.data(as: LocationGroup.self)
        } catch {
            AppLogger.debug("Error fetching group by ID: \(error)")
            return nil
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
            AppLogger.debug("Error searching user by tag: \(error)")
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
            AppLogger.debug("Error searching users: \(error)")
            return []
        }
    }

    func fetchUserById(_ userId: String) async -> User? {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            return try? document.data(as: User.self)
        } catch {
            AppLogger.debug("Error fetching user by ID: \(error)")
            return nil
        }
    }

    // MARK: - Achievement Operations (users/{userId}/achievements subcollection)

    /// Fetches the earned achievements for any user (used for public profile display).
    /// Requires Firestore rules to allow reads on users/{userId}/achievements for authenticated users.
    func fetchUserAchievements(userId: String) async -> [UserAchievement] {
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("achievements")
                .order(by: "earnedAt", descending: true)
                .getDocuments()
            return snapshot.documents.compactMap { try? $0.data(as: UserAchievement.self) }
        } catch {
            AppLogger.debug("[FirestoreService] Error fetching achievements for \(userId): \(error)")
            return []
        }
    }

    /// Fetches public-facing stats for any user (used for public profile display).
    /// Returns nil if the stats document doesn't exist or can't be read.
    func fetchUserStats(userId: String) async -> UserStats? {
        do {
            let doc = try await db.collection("users").document(userId)
                .collection("stats").document("current")
                .getDocument()
            return try? doc.data(as: UserStats.self)
        } catch {
            AppLogger.debug("[FirestoreService] Error fetching stats for \(userId): \(error)")
            return nil
        }
    }

    func updateAutoCheckOutMinutes(_ minutes: Int) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            AppLogger.debug("Error updating auto check-out time: No user ID")
            return
        }

        do {
            try await db.collection("users").document(userId).setData([
                "autoCheckOutMinutes": minutes
            ], merge: true)
            self.currentUser?.autoCheckOutMinutes = minutes
            AppLogger.debug("Auto check-out time updated to \(minutes) minutes")
        } catch {
            AppLogger.debug("Error updating auto check-out time: \(error)")
        }
    }

    // MARK: - Group Operations (groups collection)

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

            AppLogger.debug("[FirestoreService] Creating group with ID: \(groupId)")
            try await newDocRef.setData(groupData)
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logDocumentWrite(collection: "groups", documentId: groupId, durationMs: duration, success: true)
            AppLogger.debug("[FirestoreService] Group document created successfully")

            // Update user's joinedGroupIds - do this in a separate try/catch so group creation still succeeds
            let userRef = db.collection("users").document(userId)
            do {
                try await userRef.setData([
                    "joinedGroupIds": FieldValue.arrayUnion([groupId])
                ], merge: true)
                AppLogger.debug("[FirestoreService] User joinedGroupIds updated successfully")
            } catch {
                // Log but don't fail - the group was created, we can recover by fetching
                AppLogger.debug("[FirestoreService] Warning: Failed to update user joinedGroupIds: \(error)")
            }

            // Always update local state
            if self.currentUser != nil {
                self.currentUser?.joinedGroupIds.append(groupId)
            }

            // Add the new group to joinedGroups immediately so it shows up in the UI
            var createdGroup = validatedGroup
            createdGroup.id = groupId
            self.joinedGroups.append(createdGroup)
            AppLogger.debug("[FirestoreService] Added group to local joinedGroups array")

            // Track achievement for creating a group
            await achievementService.recordGroupCreated()

            // Track analytics
            analyticsService.trackGroupCreated(
                groupId: groupId,
                hasBoundary: !validatedGroup.boundary.isEmpty,
                isPublic: validatedGroup.isPublic
            )

            AppLogger.debug("[FirestoreService] Group creation complete, returning success")
            return .success(groupId)
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logDocumentWrite(collection: "groups", documentId: nil, durationMs: duration, success: false, error: error)
            AppLogger.debug("[FirestoreService] Group creation failed with error: \(error)")
            let appError = AppError.groupCreationFailed(underlying: error)
            handleError(appError)
            analyticsService.trackError(errorType: "group_creation_failed", context: "FirestoreService.createGroup", message: error.localizedDescription)
            return .failure(appError)
        }
    }

    func fetchJoinedGroups() async {
        AppLogger.debug("fetchJoinedGroups() called")

        guard let userId = Auth.auth().currentUser?.uid else {
            AppLogger.debug("No current user, clearing joined groups")
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

            AppLogger.debug("Fetched \(snapshot.documents.count) group documents where user is member")

            self.joinedGroups = snapshot.documents.compactMap { doc in
                do {
                    let group = try doc.data(as: LocationGroup.self)
                    AppLogger.debug("Decoded group: \(group.name)")
                    return group
                } catch {
                    AppLogger.debug("Error decoding group \(doc.documentID): \(error)")
                    return nil
                }
            }

            AppLogger.debug("joinedGroups now has \(joinedGroups.count) groups")

            // Also update the currentUser's joinedGroupIds locally to stay in sync
            if self.currentUser != nil {
                self.currentUser?.joinedGroupIds = self.joinedGroups.compactMap { $0.id }
            }

            // Sync updated groups to widget
            WidgetDataService.shared.syncToWidget()
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "groups", durationMs: duration, resultCount: 0, success: false, error: error)
            AppLogger.debug("Error fetching joined groups: \(error)")
        }
    }

    func fetchPublicGroups() async {
        AppLogger.debug("fetchPublicGroups() called")
        let startTime = Date()
        do {
            let snapshot = try await db.collection("groups")
                .whereField("isPublic", isEqualTo: true)
                .limit(to: 50)
                .getDocuments()

            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "groups", durationMs: duration, resultCount: snapshot.documents.count, success: true)

            AppLogger.debug("Fetched \(snapshot.documents.count) public group documents")

            self.publicGroups = snapshot.documents.compactMap { doc in
                try? doc.data(as: LocationGroup.self)
            }

            AppLogger.debug("publicGroups now has \(publicGroups.count) groups")
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logQuery(collection: "groups", durationMs: duration, resultCount: 0, success: false, error: error)
            AppLogger.debug("Error fetching public groups: \(error)")
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
                AppLogger.debug("[FirestoreService] Warning: Failed to update user joinedGroupIds: \(error)")
            }

            // Update local state immediately
            if self.currentUser != nil && !self.currentUser!.joinedGroupIds.contains(groupId) {
                self.currentUser?.joinedGroupIds.append(groupId)
            }

            // Fetch updated data
            await fetchJoinedGroups()

            // Track achievement for joining a group
            await achievementService.recordGroupJoined()

            // Track private group achievement
            if let joinedGroup = joinedGroups.first(where: { $0.id == groupId }), !joinedGroup.isPublic {
                await achievementService.recordPrivateGroupJoined()
            }

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
                AppLogger.debug("[FirestoreService] Warning: Failed to update user joinedGroupIds: \(error)")
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
            AppLogger.debug("Error updating group settings: \(error)")
        }
    }

    func updateGroupBoundary(groupId: String, boundary: [Coordinate]) async {
        // Validate boundary before saving
        let validationResult = Validation.validateBoundary(boundary)
        guard validationResult.isValid else {
            AppLogger.debug("Invalid boundary: \(validationResult.error?.userMessage ?? "Unknown error")")
            return
        }

        // Calculate new center coordinates
        let latitudes = boundary.map { $0.latitude }
        let longitudes = boundary.map { $0.longitude }
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else {
            AppLogger.debug("Cannot calculate center: empty boundary coordinates")
            return
        }
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

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

            AppLogger.debug("Group boundary updated successfully")
        } catch {
            AppLogger.debug("Error updating group boundary: \(error)")
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
            AppLogger.debug("Error finding group by invite code: \(error)")
            return nil
        }
    }

    // MARK: - Presence Operations (presence/{groupId}/members collection)

    func updatePresence(groupId: String, isPresent: Bool, isManual: Bool, expiresAt: Date? = nil) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Use currentUser if available, then UserDefaults cache, then Firebase Auth profile.
        // Auth profile is restored from Keychain on launch — no network needed.
        // If none are available (background launch race), fetch the user doc next.
        var displayName = currentUser?.displayName ?? cachedDisplayName ?? Auth.auth().currentUser?.displayName
        var level = currentUser?.level ?? cachedUserLevel

        if displayName == nil && isPresent {
            // Background launch: currentUser not loaded yet and no cache.
            // Fetch the user doc inline so we don't write "Unknown".
            await fetchCurrentUser()
            displayName = currentUser?.displayName ?? cachedDisplayName
            level = currentUser?.level ?? cachedUserLevel
        }

        // Final fallback: never write nil displayName for a check-in.
        // This covers the case where fetchCurrentUser() fails (network error, etc.)
        let finalDisplayName: String? = isPresent
            ? (displayName ?? "Player \(String(userId.prefix(4)))")
            : displayName

        let presence = Presence(
            userId: userId,
            groupId: groupId,
            isPresent: isPresent,
            isManual: isManual,
            lastUpdated: Date(),
            expiresAt: isPresent ? expiresAt : nil,  // Only set expiration when checking in
            displayName: finalDisplayName,
            level: level
        )

        do {
            try db.collection("presence").document(groupId)
                .collection("members").document(userId).setData(from: presence)
        } catch {
            AppLogger.debug("Error updating presence: \(error)")
        }
    }

    /// Re-patches any active presence documents that have a nil displayName.
    /// Called after currentUser loads so we can fix presences written during the race window.
    private func repatchPresencesIfNeeded() async {
        guard let userId = Auth.auth().currentUser?.uid,
              let displayName = currentUser?.displayName else { return }
        let level = currentUser?.level ?? 1

        for groupId in currentUser?.joinedGroupIds ?? [] {
            do {
                let docRef = db.collection("presence").document(groupId)
                    .collection("members").document(userId)
                let doc = try await docRef.getDocument()

                guard doc.exists else { continue }

                let data = doc.data() ?? [:]
                let isPresent = data["isPresent"] as? Bool ?? false
                let existingName = data["displayName"] as? String

                // Patch if checked in and displayName is missing, empty, or "Unknown"
                let needsPatch = existingName == nil || existingName?.isEmpty == true
                    || existingName == "Unknown"
                    || existingName?.hasPrefix("Player ") == true
                if isPresent && needsPatch {
                    try await docRef.setData([
                        "displayName": displayName,
                        "level": level
                    ], merge: true)
                    AppLogger.debug("Re-patched presence displayName for group \(groupId)")
                }
            } catch {
                AppLogger.debug("Error re-patching presence for group \(groupId): \(error)")
            }
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
            AppLogger.debug("Error fetching presence: \(error)")
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

    // MARK: - Account Deletion

    /// Deletes all user data from Firestore. Called during account deletion.
    func deleteAllUserData(userId: String) async {
        // 1. Remove user from all groups they're a member of
        for group in joinedGroups {
            guard let groupId = group.id else { continue }

            // Remove from group memberIds
            try? await db.collection("groups").document(groupId).updateData([
                "memberIds": FieldValue.arrayRemove([userId])
            ])

            // Delete presence
            try? await db.collection("presence").document(groupId)
                .collection("members").document(userId).delete()
        }

        // 2. Delete groups owned by user
        do {
            let ownedGroups = try await db.collection("groups")
                .whereField("ownerId", isEqualTo: userId)
                .getDocuments()

            for doc in ownedGroups.documents {
                // Delete presence subcollection
                let presenceDocs = try? await db.collection("presence").document(doc.documentID)
                    .collection("members").getDocuments()
                for presenceDoc in presenceDocs?.documents ?? [] {
                    try? await presenceDoc.reference.delete()
                }
                // Delete messages subcollection
                let messageDocs = try? await db.collection("groups").document(doc.documentID)
                    .collection("messages").getDocuments()
                for messageDoc in messageDocs?.documents ?? [] {
                    try? await messageDoc.reference.delete()
                }
                // Delete the group
                try? await doc.reference.delete()
            }
        } catch { }

        // 3. Delete friend requests (sent and received)
        do {
            let sentRequests = try await db.collection("friendRequests")
                .whereField("senderId", isEqualTo: userId).getDocuments()
            for doc in sentRequests.documents {
                try? await doc.reference.delete()
            }

            let receivedRequests = try await db.collection("friendRequests")
                .whereField("receiverId", isEqualTo: userId).getDocuments()
            for doc in receivedRequests.documents {
                try? await doc.reference.delete()
            }
        } catch { }

        // 4. Delete friends subcollection and remove from others' friend lists
        do {
            let friendsDocs = try await db.collection("users").document(userId)
                .collection("friends").getDocuments()
            for doc in friendsDocs.documents {
                let friendId = doc.documentID
                // Remove me from their friends
                try? await db.collection("users").document(friendId)
                    .collection("friends").document(userId).delete()
                // Delete my friend entry
                try? await doc.reference.delete()
            }
        } catch { }

        // 5. Delete user subcollections (achievements, stats, notificationPreferences)
        for subcollection in ["achievements", "stats", "notificationPreferences"] {
            do {
                let docs = try await db.collection("users").document(userId)
                    .collection(subcollection).getDocuments()
                for doc in docs.documents {
                    try? await doc.reference.delete()
                }
            } catch { }
        }

        // 6. Delete the user document itself
        try? await db.collection("users").document(userId).delete()

        // 7. Clear local state
        currentUser = nil
        joinedGroups = []
        publicGroups = []
        nearbyGroups = []
        clearCachedUserInfo()
    }

    // MARK: - Invite Code

    func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    // MARK: - Report Operations (reports collection)

    /// Submits a user content report to Firestore
    func submitReport(_ report: Report) async -> AppResult<Void> {
        guard Auth.auth().currentUser?.uid != nil else {
            return .failure(.notAuthenticated)
        }

        do {
            try db.collection("reports").addDocument(from: report)
            AppLogger.debug("[FirestoreService] Report submitted for user: \(report.reportedUserId)")
            return .success(())
        } catch {
            AppLogger.debug("[FirestoreService] Error submitting report: \(error)")
            return .failure(.serverError(underlying: error))
        }
    }

    /// Checks if the current user has already reported a specific user recently (within 24 hours)
    /// to prevent spam reports
    func hasRecentReport(reportedUserId: String) async -> Bool {
        guard let reporterId = Auth.auth().currentUser?.uid else { return false }

        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)  // 24 hours ago

        do {
            let snapshot = try await db.collection("reports")
                .whereField("reporterId", isEqualTo: reporterId)
                .whereField("reportedUserId", isEqualTo: reportedUserId)
                .whereField("createdAt", isGreaterThan: cutoff)
                .limit(to: 1)
                .getDocuments()

            return !snapshot.documents.isEmpty
        } catch {
            AppLogger.debug("[FirestoreService] Error checking recent reports: \(error)")
            return false
        }
    }

    // MARK: - Leaderboard Operations (groups/{groupId}/leaderboard subcollection)

    /// Updates the current user's leaderboard entry for a group on check-in.
    /// Uses lazy monthly reset: if the stored month key differs from the current month,
    /// resets monthlyCheckIns to 1 instead of incrementing.
    func updateLeaderboardEntry(groupId: String) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let ref = db.collection("groups").document(groupId)
            .collection("leaderboard").document(userId)

        let currentMonth = LeaderboardEntry.currentMonthKey
        let displayName = currentUser?.displayName ?? cachedDisplayName ?? Auth.auth().currentUser?.displayName ?? "Unknown"
        let level = currentUser?.level ?? cachedUserLevel
        let emoji = currentUser?.profileEmoji

        do {
            let doc = try await ref.getDocument()

            if doc.exists, var entry = try? doc.data(as: LeaderboardEntry.self) {
                // Existing entry — increment or reset monthly
                entry.allTimeCheckIns += 1
                if entry.currentMonthKey == currentMonth {
                    entry.monthlyCheckIns += 1
                } else {
                    entry.monthlyCheckIns = 1
                    entry.currentMonthKey = currentMonth
                }
                entry.lastCheckInAt = Date()
                entry.displayName = displayName
                entry.level = level
                entry.profileEmoji = emoji

                try ref.setData(from: entry, merge: true)
            } else {
                // New entry
                let entry = LeaderboardEntry(
                    userId: userId,
                    displayName: displayName,
                    level: level,
                    profileEmoji: emoji,
                    allTimeCheckIns: 1,
                    monthlyCheckIns: 1,
                    currentMonthKey: currentMonth,
                    lastCheckInAt: Date()
                )
                try ref.setData(from: entry)
            }
        } catch {
            AppLogger.debug("[FirestoreService] Error updating leaderboard: \(error)")
        }
    }

    /// Fetches the leaderboard for a group, ordered by the given timeframe.
    func fetchLeaderboard(groupId: String, timeframe: LeaderboardTimeframe) async -> [LeaderboardEntry] {
        let orderField: String
        switch timeframe {
        case .monthly:
            orderField = "monthlyCheckIns"
        case .allTime:
            orderField = "allTimeCheckIns"
        }

        do {
            let snapshot = try await db.collection("groups").document(groupId)
                .collection("leaderboard")
                .order(by: orderField, descending: true)
                .limit(to: 50)
                .getDocuments()

            var entries = snapshot.documents.compactMap { try? $0.data(as: LeaderboardEntry.self) }

            // For monthly: filter out stale entries where month doesn't match
            if timeframe == .monthly {
                let currentMonth = LeaderboardEntry.currentMonthKey
                entries = entries.filter { $0.currentMonthKey == currentMonth }
            }

            return entries
        } catch {
            AppLogger.debug("[FirestoreService] Error fetching leaderboard: \(error)")
            return []
        }
    }

    /// Fetches the top visitor this month for a group. Returns nil if no check-ins this month.
    func fetchTopVisitor(groupId: String) async -> LeaderboardEntry? {
        let entries = await fetchLeaderboard(groupId: groupId, timeframe: .monthly)
        return entries.first
    }

    // MARK: - Batch User Fetch

    /// Fetches multiple users by their IDs in batches of 10 (Firestore `in` query limit).
    func fetchUsersByIds(_ ids: [String]) async -> [User] {
        guard !ids.isEmpty else { return [] }

        var allUsers: [User] = []
        let batches = stride(from: 0, to: ids.count, by: 10).map {
            Array(ids[$0..<min($0 + 10, ids.count)])
        }

        for batch in batches {
            do {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batch)
                    .getDocuments()

                let users = snapshot.documents.compactMap { try? $0.data(as: User.self) }
                allUsers.append(contentsOf: users)
            } catch {
                AppLogger.debug("[FirestoreService] Error batch fetching users: \(error)")
            }
        }

        return allUsers
    }
}
