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
    private var levelService: LevelService { LevelService.shared }

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
                    LevelService.shared.reset()
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

        // Initialize level service with current stats
        levelService.loadFromStats(userStats, achievementPoints: totalPoints)
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
            AppLogger.debug("Error loading achievements: \(error)")
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
            AppLogger.debug("Error loading user stats: \(error)")
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
    func recordCheckIn(groupId: String, presentMembers: [Presence], friendIds: [String] = []) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // Update stats
        userStats.totalCheckIns += 1

        // Per-group check-in count
        userStats.groupCheckInCounts[groupId, default: 0] += 1

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

        // Time-of-day checks
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let isNightOwl = hour >= 22 || hour < 5

        // Check for weekend warrior
        let weekday = calendar.component(.weekday, from: now)
        checkWeekendWarrior(weekday: weekday)

        // Update habit tracker for Creature of Habit
        updateHabitTracker(groupId: groupId, hour: hour)

        // Count friends present for Crew Up
        let friendsPresent = presentMembers.filter { presence in
            presence.userId != userId && friendIds.contains(presence.userId)
        }

        // Save stats
        try? await saveUserStats()

        // Check and award achievements
        await checkCheckInAchievements()
        await checkEarlyBirdAchievements()
        await checkSocialAchievements()
        await checkStreakAchievements()
        await checkPerGroupAchievements(groupId: groupId)
        await checkTimeBasedAchievements(hour: hour)
        await checkSeasonalAchievements(date: now)
        await checkHabitAchievements()

        if isNightOwl {
            await tryUnlock(.nightOwl)
        }

        // Crew Up: 3+ friends checked in together
        if friendsPresent.count >= 3 {
            await tryUnlock(.crewUp)
        }
    }

    /// Call after leaderboard update to check if user is now #1 visitor
    func checkTopVisitor(groupId: String) async {
        guard let topEntry = await FirestoreService.shared.fetchTopVisitor(groupId: groupId),
              topEntry.userId == Auth.auth().currentUser?.uid else { return }
        // Only unlock if they have at least 3 check-ins this month (meaningful lead)
        if topEntry.effectiveMonthlyCheckIns >= 3 {
            await tryUnlock(.topVisitor)
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

        // Popular Kid: 5+ groups
        if userStats.groupsJoined >= 5 {
            await tryUnlock(.popularKid)
        }
    }

    /// Call when a group's member count changes (for group owner)
    func recordGroupMemberCountChanged(memberCount: Int) async {
        await checkCommunityAchievements(memberCount: memberCount)
    }

    /// Call when user checks out of a location
    func recordCheckOut(groupId: String, remainingMembers: Int, sessionDurationMinutes: Int) async {
        // Marathon: 4+ hours
        if sessionDurationMinutes >= 240 {
            userStats.longestSessionMinutes = max(userStats.longestSessionMinutes, sessionDurationMinutes)
            try? await saveUserStats()
            await tryUnlock(.marathonSession)
        }

        // Last One Standing: no other users remain
        if remainingMembers == 0 {
            userStats.wasLastToLeaveCount += 1
            try? await saveUserStats()
            await tryUnlock(.lastOneStanding)
        }
    }

    /// Call when friend count changes
    func recordFriendCountChanged(friendCount: Int) async {
        userStats.friendCount = friendCount
        try? await saveUserStats()

        if friendCount >= 1 {
            await tryUnlock(.firstFriend)
        }
        if friendCount >= 10 {
            await tryUnlock(.friendCollector)
        }
    }

    /// Call when user sends a friend request
    func recordFriendRequestSent() async {
        userStats.hasSentFriendRequest = true
        try? await saveUserStats()
        await tryUnlock(.friendlyFace)
    }

    /// Call when user accepts a friend request
    func recordFriendRequestAccepted() async {
        userStats.hasAcceptedFriendRequest = true
        try? await saveUserStats()
        await tryUnlock(.welcomeCommittee)
    }

    /// Call when user sets their display name
    func recordDisplayNameSet() async {
        userStats.hasSetDisplayName = true
        try? await saveUserStats()
        await tryUnlock(.identitySet)
    }

    /// Call when user views group settings
    func recordGroupSettingsViewed() async {
        userStats.hasViewedGroupSettings = true
        try? await saveUserStats()
        await tryUnlock(.settingsExplorer)
    }

    /// Call when user favorites/unfavorites a group
    func recordFavoriteCountChanged(count: Int) async {
        userStats.favoriteGroupCount = count
        try? await saveUserStats()
        if count >= 4 {
            await tryUnlock(.favoritesFan)
        }
    }

    /// Call when user shares a group invite link
    func recordGroupShared() async {
        userStats.hasSharedGroupLink = true
        try? await saveUserStats()
        await tryUnlock(.shareTheLove)
    }

    /// Call when user shares the app
    func recordAppShared() async {
        userStats.hasSharedApp = true
        try? await saveUserStats()
        await tryUnlock(.appAmbassador)
    }

    /// Call when user joins a private group via invite code
    func recordPrivateGroupJoined() async {
        userStats.hasJoinedPrivateGroup = true
        try? await saveUserStats()
        await tryUnlock(.privateEntry)
    }

    /// Call when user sends a chat message
    func recordMessageSent(groupId: String, isFirstMessageInGroup: Bool) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Reset daily count if new day
        if let lastDate = userStats.lastMessageDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if today != lastDay {
                userStats.messagesToday = 0
            }
        }

        userStats.totalMessagesSent += 1
        userStats.messagesToday += 1
        userStats.lastMessageDate = Date()

        if isFirstMessageInGroup && !userStats.groupsWithFirstMessage.contains(groupId) {
            userStats.groupsWithFirstMessage.append(groupId)
        }

        try? await saveUserStats()

        // Conversation Starter
        if isFirstMessageInGroup {
            await tryUnlock(.conversationStarter)
        }

        // Chatterbox: 50 total messages
        if userStats.totalMessagesSent >= 50 {
            await tryUnlock(.chatterbox)
        }

        // Prolific Messenger: 10 messages in one day
        if userStats.messagesToday >= 10 {
            await tryUnlock(.prolificMessenger)
        }

        // First Message: send any message
        if userStats.totalMessagesSent >= 1 {
            await tryUnlock(.firstMessage)
        }
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
        if userStats.groupsCreated >= 3 {
            await tryUnlock(.tripleBuilder)
        }
    }

    private func checkCommunityAchievements(memberCount: Int) async {
        if memberCount >= 5 {
            await tryUnlock(.communityBuilder)
        }
        if memberCount >= 10 {
            await tryUnlock(.socialHub)
            await tryUnlock(.landlord)
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
        if userStats.currentStreak >= 3 {
            await tryUnlock(.onARoll)
        }
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

    // MARK: - New Achievement Checks

    private func checkPerGroupAchievements(groupId: String) async {
        let count = userStats.groupCheckInCounts[groupId] ?? 0
        if count >= 20 {
            await tryUnlock(.homebody)
        }
        if count >= 30 {
            await tryUnlock(.loyalMember)
        }
    }

    private func checkTimeBasedAchievements(hour: Int) async {
        if hour < 7 {
            await tryUnlock(.earlyRiser)
        }
        if hour >= 23 {
            await tryUnlock(.lateNightOwl)
        }
        if hour == 0 {
            await tryUnlock(.midnightCrew)
        }
    }

    private func checkSeasonalAchievements(date: Date) async {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        // New Year's Day
        if month == 1 && day == 1 {
            await tryUnlock(.newYearCheckIn)
        }

        // Major holidays
        if isMajorHoliday(month: month, day: day) {
            await tryUnlock(.holidaySpirit)
        }
    }

    private func checkHabitAchievements() async {
        for (_, entry) in userStats.habitTracker {
            if entry.consecutiveDays >= 5 {
                await tryUnlock(.creatureOfHabit)
                return
            }
        }
    }

    private func isMajorHoliday(month: Int, day: Int) -> Bool {
        let holidays: [(Int, Int)] = [
            (1, 1),   // New Year's Day
            (2, 14),  // Valentine's Day
            (7, 4),   // Independence Day
            (10, 31), // Halloween
            (12, 25), // Christmas
            (12, 31), // New Year's Eve
        ]
        return holidays.contains { $0.0 == month && $0.1 == day }
    }

    private func updateHabitTracker(groupId: String, hour: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if var entry = userStats.habitTracker[groupId] {
            // Check if same hour (within 1 hour tolerance)
            let sameHour = abs(entry.lastCheckInHour - hour) <= 1

            if let lastDate = entry.lastCheckInDate {
                let lastDay = calendar.startOfDay(for: lastDate)
                let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

                if daysDiff == 1 && sameHour {
                    // Consecutive day, same hour
                    entry.consecutiveDays += 1
                } else if daysDiff == 0 {
                    // Same day, don't update
                    return
                } else {
                    // Streak broken or different hour
                    entry.consecutiveDays = 1
                }
            } else {
                entry.consecutiveDays = 1
            }

            entry.lastCheckInHour = hour
            entry.lastCheckInDate = Date()
            userStats.habitTracker[groupId] = entry
        } else {
            // First time at this group
            userStats.habitTracker[groupId] = HabitEntry(
                lastCheckInHour: hour,
                consecutiveDays: 1,
                lastCheckInDate: Date()
            )
        }
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

            // Award XP for achievement
            await levelService.awardAchievementXP(points: achievement.points)

            // Haptic feedback for achievement unlock
            HapticManager.success()

            // Track analytics
            analyticsService.trackAchievementUnlocked(
                achievementType: achievement.rawValue,
                points: achievement.points
            )

            AppLogger.debug("Achievement unlocked: \(achievement.displayName)")

            // Clear the notification after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.newlyUnlockedAchievement == achievement {
                    self?.newlyUnlockedAchievement = nil
                }
            }
        } catch {
            AppLogger.debug("Error saving achievement: \(error)")
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
            AppLogger.debug("[AchievementService] Error checking first arrival for group \(groupId): \(error.localizedDescription)")
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
        case .tripleBuilder:
            return (min(userStats.groupsCreated, 3), 3)

        case .explorer:
            return (min(userStats.groupsJoined, 3), 3)
        case .adventurer:
            return (min(userStats.groupsJoined, 5), 5)
        case .globetrotter:
            return (min(userStats.groupsJoined, 10), 10)
        case .popularKid:
            return (min(userStats.groupsJoined, 5), 5)

        case .socialButterfly:
            return (min(userStats.uniquePeopleMetCount, 5), 5)
        case .partyStarter:
            return (min(userStats.uniquePeopleMetCount, 10), 10)
        case .connector:
            return (min(userStats.uniquePeopleMetCount, 25), 25)

        case .onARoll:
            return (min(userStats.currentStreak, 3), 3)
        case .weekWarrior:
            return (min(userStats.currentStreak, 7), 7)
        case .dedicated:
            return (min(userStats.currentStreak, 14), 14)
        case .unstoppable:
            return (min(userStats.currentStreak, 30), 30)

        case .firstFriend:
            return (min(userStats.friendCount, 1), 1)
        case .friendCollector:
            return (min(userStats.friendCount, 10), 10)

        case .chatterbox:
            return (min(userStats.totalMessagesSent, 50), 50)
        case .prolificMessenger:
            return (min(userStats.messagesToday, 10), 10)

        case .homebody:
            let maxCount = userStats.groupCheckInCounts.values.max() ?? 0
            return (min(maxCount, 20), 20)
        case .loyalMember:
            let maxCount = userStats.groupCheckInCounts.values.max() ?? 0
            return (min(maxCount, 30), 30)

        case .creatureOfHabit:
            let maxConsecutive = userStats.habitTracker.values.map(\.consecutiveDays).max() ?? 0
            return (min(maxConsecutive, 5), 5)

        case .favoritesFan:
            return (min(userStats.favoriteGroupCount, 4), 4)

        // One-time trigger achievements (no meaningful progress bar)
        case .nightOwl, .weekendWarrior, .earlyRiser, .lateNightOwl,
             .lastOneStanding, .marathonSession, .crewUp,
             .conversationStarter, .midnightCrew, .holidaySpirit,
             .newYearCheckIn, .communityBuilder, .socialHub, .landlord,
             .friendlyFace, .welcomeCommittee, .identitySet, .settingsExplorer,
             .shareTheLove, .appAmbassador, .privateEntry, .firstMessage,
             .topVisitor:
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
