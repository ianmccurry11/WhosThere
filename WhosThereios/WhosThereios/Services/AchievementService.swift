//
//  AchievementService.swift
//  WhosThereios
//
//  Created by Claude on 1/16/26.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class AchievementService: ObservableObject {
    static let shared = AchievementService()

    private let db = Firestore.firestore()
    private var firestoreService: FirestoreService { FirestoreService.shared }
    private var analyticsService: AnalyticsService { AnalyticsService.shared }

    @Published var earnedAchievements: [UserAchievement] = []
    @Published var userStats: UserStats = UserStats()
    @Published var newlyUnlockedAchievement: AchievementType?
    @Published var totalPoints: Int = 0

    private var achievementsListener: ListenerRegistration?

    init() {
        setupAuthListener()
    }

    private func setupAuthListener() {
        _ = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if user != nil {
                    await self?.loadUserData()
                } else {
                    self?.earnedAchievements = []
                    self?.userStats = UserStats()
                    self?.totalPoints = 0
                }
            }
        }
    }

    // MARK: - Data Loading

    func loadUserData() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        await loadEarnedAchievements(userId: userId)
        await loadUserStats(userId: userId)
        calculateTotalPoints()
    }

    private func loadEarnedAchievements(userId: String) async {
        do {
            let snapshot = try await db.collection("users").document(userId)
                .collection("achievements")
                .order(by: "earnedAt", descending: true)
                .getDocuments()

            earnedAchievements = snapshot.documents.compactMap { doc in
                try? doc.data(as: UserAchievement.self)
            }
        } catch {
            print("Error loading achievements: \(error)")
        }
    }

    private func loadUserStats(userId: String) async {
        do {
            let doc = try await db.collection("users").document(userId)
                .collection("stats").document("current")
                .getDocument()

            if doc.exists, let stats = try? doc.data(as: UserStats.self) {
                userStats = stats
            } else {
                // Initialize stats if they don't exist
                userStats = UserStats()
                try? await saveUserStats()
            }
        } catch {
            print("Error loading user stats: \(error)")
        }
    }

    private func saveUserStats() async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        try db.collection("users").document(userId)
            .collection("stats").document("current")
            .setData(from: userStats)
    }

    private func calculateTotalPoints() {
        totalPoints = earnedAchievements.reduce(0) { $0 + $1.achievementType.points }
    }

    // MARK: - Achievement Checking

    func hasEarned(_ achievement: AchievementType) -> Bool {
        earnedAchievements.contains { $0.achievementType == achievement }
    }

    // MARK: - Event Triggers

    /// Call when user checks in to a location
    func recordCheckIn(groupId: String, presentMembers: [Presence]) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Update stats
        userStats.totalCheckIns += 1

        // Check if first to arrive TODAY (early bird) - must be first person of the day at this location
        let isFirstToday = await checkIfFirstArrivalToday(groupId: groupId, userId: userId)
        if isFirstToday {
            userStats.earlyBirdCount += 1
        }

        // Track unique people met
        for presence in presentMembers where presence.userId != userId {
            if !userStats.uniquePeopleMet.contains(presence.userId) {
                userStats.uniquePeopleMet.append(presence.userId)
                userStats.uniquePeopleMetCount = userStats.uniquePeopleMet.count
            }
        }

        // Update streak
        updateStreak()

        // Check for night owl (after 10 PM)
        let hour = Calendar.current.component(.hour, from: Date())
        let isNightOwl = hour >= 22 || hour < 5

        // Check for weekend warrior
        let weekday = Calendar.current.component(.weekday, from: Date())
        checkWeekendWarrior(weekday: weekday)

        // Save stats
        try? await saveUserStats()

        // Check and award achievements
        await checkCheckInAchievements()
        await checkEarlyBirdAchievements()
        await checkSocialAchievements()
        await checkStreakAchievements()

        if isNightOwl {
            await tryUnlock(.nightOwl)
        }
    }

    /// Call when user creates a group
    func recordGroupCreated() async {
        userStats.groupsCreated += 1
        try? await saveUserStats()
        await checkGroupAchievements()
    }

    /// Call when user joins a group
    func recordGroupJoined() async {
        userStats.groupsJoined += 1
        try? await saveUserStats()
        await checkExplorerAchievements()
    }

    /// Call when a group's member count changes (for group owner)
    func recordGroupMemberCountChanged(memberCount: Int) async {
        await checkCommunityAchievements(memberCount: memberCount)
    }

    // MARK: - Achievement Checks

    private func checkCheckInAchievements() async {
        if userStats.totalCheckIns >= 1 {
            await tryUnlock(.firstCheckIn)
        }
        if userStats.totalCheckIns >= 10 {
            await tryUnlock(.tenCheckIns)
        }
        if userStats.totalCheckIns >= 50 {
            await tryUnlock(.fiftyCheckIns)
        }
        if userStats.totalCheckIns >= 100 {
            await tryUnlock(.hundredCheckIns)
        }
    }

    private func checkEarlyBirdAchievements() async {
        if userStats.earlyBirdCount >= 1 {
            await tryUnlock(.earlyBird)
        }
        if userStats.earlyBirdCount >= 5 {
            await tryUnlock(.earlyBirdBronze)
        }
        if userStats.earlyBirdCount >= 10 {
            await tryUnlock(.earlyBirdSilver)
        }
        if userStats.earlyBirdCount >= 25 {
            await tryUnlock(.earlyBirdGold)
        }
    }

    private func checkGroupAchievements() async {
        if userStats.groupsCreated >= 1 {
            await tryUnlock(.groupCreator)
        }
    }

    private func checkCommunityAchievements(memberCount: Int) async {
        if memberCount >= 5 {
            await tryUnlock(.communityBuilder)
        }
        if memberCount >= 10 {
            await tryUnlock(.socialHub)
        }
    }

    private func checkExplorerAchievements() async {
        if userStats.groupsJoined >= 3 {
            await tryUnlock(.explorer)
        }
        if userStats.groupsJoined >= 5 {
            await tryUnlock(.adventurer)
        }
        if userStats.groupsJoined >= 10 {
            await tryUnlock(.globetrotter)
        }
    }

    private func checkSocialAchievements() async {
        if userStats.uniquePeopleMetCount >= 5 {
            await tryUnlock(.socialButterfly)
        }
        if userStats.uniquePeopleMetCount >= 10 {
            await tryUnlock(.partyStarter)
        }
        if userStats.uniquePeopleMetCount >= 25 {
            await tryUnlock(.connector)
        }
    }

    private func checkStreakAchievements() async {
        if userStats.currentStreak >= 7 {
            await tryUnlock(.weekWarrior)
        }
        if userStats.currentStreak >= 14 {
            await tryUnlock(.dedicated)
        }
        if userStats.currentStreak >= 30 {
            await tryUnlock(.unstoppable)
        }
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastCheckIn = userStats.lastCheckInDate {
            let lastCheckInDay = calendar.startOfDay(for: lastCheckIn)
            let daysDiff = calendar.dateComponents([.day], from: lastCheckInDay, to: today).day ?? 0

            if daysDiff == 0 {
                // Same day, streak continues but don't increment
            } else if daysDiff == 1 {
                // Consecutive day, increment streak
                userStats.currentStreak += 1
            } else {
                // Streak broken, reset to 1
                userStats.currentStreak = 1
            }
        } else {
            // First check-in ever
            userStats.currentStreak = 1
        }

        userStats.lastCheckInDate = Date()
        userStats.longestStreak = max(userStats.longestStreak, userStats.currentStreak)
    }

    private func checkWeekendWarrior(weekday: Int) {
        let calendar = Calendar.current

        // Reset weekend tracking on Monday
        if weekday == 2 { // Monday
            if let lastReset = userStats.lastWeekendReset {
                let daysSinceReset = calendar.dateComponents([.day], from: lastReset, to: Date()).day ?? 0
                if daysSinceReset >= 7 {
                    userStats.checkedInOnSaturday = false
                    userStats.checkedInOnSunday = false
                    userStats.lastWeekendReset = Date()
                }
            } else {
                userStats.lastWeekendReset = Date()
            }
        }

        if weekday == 7 { // Saturday
            userStats.checkedInOnSaturday = true
        }
        if weekday == 1 { // Sunday
            userStats.checkedInOnSunday = true
        }

        if userStats.checkedInOnSaturday && userStats.checkedInOnSunday {
            Task {
                await tryUnlock(.weekendWarrior)
            }
        }
    }

    // MARK: - Unlock Achievement

    private func tryUnlock(_ achievement: AchievementType) async {
        guard !hasEarned(achievement) else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let userAchievement = UserAchievement(
            achievementType: achievement,
            earnedAt: Date(),
            userId: userId
        )

        do {
            try db.collection("users").document(userId)
                .collection("achievements")
                .document(achievement.rawValue)
                .setData(from: userAchievement)

            // Update local state
            earnedAchievements.insert(userAchievement, at: 0)
            newlyUnlockedAchievement = achievement
            calculateTotalPoints()

            // Haptic feedback for achievement unlock
            HapticManager.success()

            // Track analytics
            analyticsService.trackAchievementUnlocked(
                achievementType: achievement.rawValue,
                points: achievement.points
            )

            print("Achievement unlocked: \(achievement.displayName)")

            // Clear the notification after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.newlyUnlockedAchievement == achievement {
                    self?.newlyUnlockedAchievement = nil
                }
            }
        } catch {
            print("Error saving achievement: \(error)")
        }
    }

    // MARK: - Early Bird Check

    /// Checks if the user is the first person to arrive at this location TODAY
    /// Uses a daily_first_arrival subcollection to track who was first each day
    private func checkIfFirstArrivalToday(groupId: String, userId: String) async -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dateString = ISO8601DateFormatter().string(from: today).prefix(10) // "2026-01-16" format

        let firstArrivalRef = db.collection("groups").document(groupId)
            .collection("daily_first_arrival").document(String(dateString))

        do {
            // Try to atomically claim "first arrival" for today
            // This uses a transaction to prevent race conditions
            let result = try await db.runTransaction { transaction, errorPointer in
                let doc: DocumentSnapshot
                do {
                    doc = try transaction.getDocument(firstArrivalRef)
                } catch let error as NSError {
                    errorPointer?.pointee = error
                    return false
                }

                if doc.exists {
                    // Someone already claimed first arrival today
                    return false
                } else {
                    // This user is first! Claim it
                    transaction.setData([
                        "userId": userId,
                        "claimedAt": FieldValue.serverTimestamp(),
                        "date": String(dateString)
                    ], forDocument: firstArrivalRef)
                    return true
                }
            }

            return result as? Bool ?? false
        } catch {
            // Permission errors usually mean user is not recognized as a group member yet
            // This can happen due to timing/caching issues - just skip the achievement check
            print("[AchievementService] Error checking first arrival for group \(groupId): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Helpers

    func getProgress(for achievement: AchievementType) -> (current: Int, target: Int)? {
        switch achievement {
        case .firstCheckIn:
            return (min(userStats.totalCheckIns, 1), 1)
        case .tenCheckIns:
            return (min(userStats.totalCheckIns, 10), 10)
        case .fiftyCheckIns:
            return (min(userStats.totalCheckIns, 50), 50)
        case .hundredCheckIns:
            return (min(userStats.totalCheckIns, 100), 100)

        case .earlyBird:
            return (min(userStats.earlyBirdCount, 1), 1)
        case .earlyBirdBronze:
            return (min(userStats.earlyBirdCount, 5), 5)
        case .earlyBirdSilver:
            return (min(userStats.earlyBirdCount, 10), 10)
        case .earlyBirdGold:
            return (min(userStats.earlyBirdCount, 25), 25)

        case .groupCreator:
            return (min(userStats.groupsCreated, 1), 1)

        case .explorer:
            return (min(userStats.groupsJoined, 3), 3)
        case .adventurer:
            return (min(userStats.groupsJoined, 5), 5)
        case .globetrotter:
            return (min(userStats.groupsJoined, 10), 10)

        case .socialButterfly:
            return (min(userStats.uniquePeopleMetCount, 5), 5)
        case .partyStarter:
            return (min(userStats.uniquePeopleMetCount, 10), 10)
        case .connector:
            return (min(userStats.uniquePeopleMetCount, 25), 25)

        case .weekWarrior:
            return (min(userStats.currentStreak, 7), 7)
        case .dedicated:
            return (min(userStats.currentStreak, 14), 14)
        case .unstoppable:
            return (min(userStats.currentStreak, 30), 30)

        default:
            return nil
        }
    }

    func achievementsByCategory() -> [AchievementCategory: [AchievementType]] {
        var result: [AchievementCategory: [AchievementType]] = [:]
        for category in AchievementCategory.allCases {
            result[category] = AchievementType.allCases.filter { $0.category == category }
        }
        return result
    }
}
