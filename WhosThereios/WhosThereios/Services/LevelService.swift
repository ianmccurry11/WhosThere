//
//  LevelService.swift
//  WhosThereios
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

/// Manages the 100-level XP progression system.
/// XP sources: achievements, check-ins (+10), daily login (+15).
@MainActor
class LevelService: ObservableObject {
    static let shared = LevelService()

    private let db = Firestore.firestore()
    private var firestoreService: FirestoreService { FirestoreService.shared }
    private var achievementService: AchievementService { AchievementService.shared }

    // MARK: - Published State

    @Published var currentLevel: UserLevel = UserLevel.calculate(from: 0)
    @Published var totalXP: Int = 0
    @Published var newlyReachedLevel: Int?

    // MARK: - XP Constants

    static let checkInXP = 10
    static let dailyLoginXP = 15

    // MARK: - Init

    init() {}

    // MARK: - Load

    /// Load XP from UserStats. Called after AchievementService loads.
    /// Handles migration for existing users who have achievement points but no stored XP.
    func loadFromStats(_ stats: UserStats, achievementPoints: Int) {
        if stats.totalXP == 0 && achievementPoints > 0 {
            // Migration: seed XP with existing achievement points
            totalXP = achievementPoints
            currentLevel = UserLevel.calculate(from: totalXP)
            Task { await persistXP() }
        } else {
            totalXP = stats.totalXP
            currentLevel = UserLevel.calculate(from: totalXP)
        }
    }

    /// Reset state when user signs out
    func reset() {
        totalXP = 0
        currentLevel = UserLevel.calculate(from: 0)
        newlyReachedLevel = nil
    }

    // MARK: - Award XP

    /// Award XP and persist. Returns true if the user leveled up.
    @discardableResult
    func awardXP(_ amount: Int, reason: String) async -> Bool {
        guard amount > 0 else { return false }
        guard Auth.auth().currentUser?.uid != nil else { return false }

        let previousLevel = currentLevel.level
        totalXP += amount
        currentLevel = UserLevel.calculate(from: totalXP)
        let newLevel = currentLevel.level

        // Persist XP
        await persistXP()

        // Sync to AchievementService stats
        achievementService.userStats.totalXP = totalXP

        // Check for level-up
        if newLevel > previousLevel {
            newlyReachedLevel = newLevel
            HapticManager.success()

            AppLogger.debug("[LevelService] Level up! \(previousLevel) -> \(newLevel) (reason: \(reason))")

            // Auto-dismiss after 4 seconds
            let capturedLevel = newLevel
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                if self?.newlyReachedLevel == capturedLevel {
                    self?.newlyReachedLevel = nil
                }
            }

            return true
        }

        return false
    }

    // MARK: - XP Sources

    /// Award XP for a check-in (+10 XP)
    func awardCheckInXP() async {
        await awardXP(Self.checkInXP, reason: "check_in")
    }

    /// Award XP for an achievement unlock
    func awardAchievementXP(points: Int) async {
        await awardXP(points, reason: "achievement")
    }

    /// Awards daily login XP (+15 XP) if not already awarded today.
    /// Call this on app launch / data initialization.
    func checkAndAwardDailyLoginXP() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let stats = achievementService.userStats
        if let lastLogin = stats.lastDailyLoginDate {
            let lastLoginDay = calendar.startOfDay(for: lastLogin)
            if lastLoginDay >= today {
                // Already awarded today
                return
            }
        }

        // Update last daily login date
        achievementService.userStats.lastDailyLoginDate = Date()

        // Award daily login XP
        await awardXP(Self.dailyLoginXP, reason: "daily_login")
    }

    // MARK: - Persistence

    private func persistXP() async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let level = currentLevel.level

        // 1. Save to UserStats subcollection
        do {
            try db.collection("users").document(userId)
                .collection("stats").document("current")
                .setData(from: achievementService.userStats)
        } catch {
            AppLogger.debug("[LevelService] Error saving stats XP: \(error)")
        }

        // 2. Denormalize to User document
        do {
            try await db.collection("users").document(userId).setData([
                "totalXP": totalXP,
                "level": level
            ], merge: true)
            firestoreService.currentUser?.totalXP = totalXP
            firestoreService.currentUser?.level = level
        } catch {
            AppLogger.debug("[LevelService] Error updating user level: \(error)")
        }
    }
}
