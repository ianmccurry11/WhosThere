//
//  Achievement.swift
//  WhosThereios
//
//  Created by Claude on 1/16/26.
//

import Foundation
import FirebaseFirestore

/// Represents a badge/achievement that can be earned
enum AchievementType: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    // Check-in achievements
    case firstCheckIn = "first_check_in"
    case tenCheckIns = "ten_check_ins"
    case fiftyCheckIns = "fifty_check_ins"
    case hundredCheckIns = "hundred_check_ins"

    // Early bird achievements
    case earlyBird = "early_bird"           // First to arrive 1 time
    case earlyBirdBronze = "early_bird_bronze"  // First to arrive 5 times
    case earlyBirdSilver = "early_bird_silver"  // First to arrive 10 times
    case earlyBirdGold = "early_bird_gold"      // First to arrive 25 times

    // Group achievements
    case groupCreator = "group_creator"      // Create first group
    case communityBuilder = "community_builder" // Create group with 5+ members
    case socialHub = "social_hub"            // Create group with 10+ members

    // Explorer achievements
    case explorer = "explorer"               // Join 3 groups
    case adventurer = "adventurer"           // Join 5 groups
    case globetrotter = "globetrotter"       // Join 10 groups

    // Social achievements
    case socialButterfly = "social_butterfly" // Be present with 5 different people
    case partyStarter = "party_starter"       // Be present with 10 different people
    case connector = "connector"              // Be present with 25 different people

    // Streak achievements
    case weekWarrior = "week_warrior"         // 7-day check-in streak
    case dedicated = "dedicated"              // 14-day check-in streak
    case unstoppable = "unstoppable"          // 30-day check-in streak

    // Special achievements
    case nightOwl = "night_owl"               // Check in after 10 PM
    case weekendWarrior = "weekend_warrior"   // Check in on both Saturday and Sunday

    var displayName: String {
        switch self {
        case .firstCheckIn: return "First Steps"
        case .tenCheckIns: return "Getting Started"
        case .fiftyCheckIns: return "Regular"
        case .hundredCheckIns: return "Veteran"

        case .earlyBird: return "Early Bird"
        case .earlyBirdBronze: return "Early Bird Bronze"
        case .earlyBirdSilver: return "Early Bird Silver"
        case .earlyBirdGold: return "Early Bird Gold"

        case .groupCreator: return "Group Creator"
        case .communityBuilder: return "Community Builder"
        case .socialHub: return "Social Hub"

        case .explorer: return "Explorer"
        case .adventurer: return "Adventurer"
        case .globetrotter: return "Globetrotter"

        case .socialButterfly: return "Social Butterfly"
        case .partyStarter: return "Party Starter"
        case .connector: return "Connector"

        case .weekWarrior: return "Week Warrior"
        case .dedicated: return "Dedicated"
        case .unstoppable: return "Unstoppable"

        case .nightOwl: return "Night Owl"
        case .weekendWarrior: return "Weekend Warrior"
        }
    }

    var description: String {
        switch self {
        case .firstCheckIn: return "Complete your first check-in"
        case .tenCheckIns: return "Check in 10 times"
        case .fiftyCheckIns: return "Check in 50 times"
        case .hundredCheckIns: return "Check in 100 times"

        case .earlyBird: return "Be the first to arrive at a location"
        case .earlyBirdBronze: return "Be the first to arrive 5 times"
        case .earlyBirdSilver: return "Be the first to arrive 10 times"
        case .earlyBirdGold: return "Be the first to arrive 25 times"

        case .groupCreator: return "Create your first group"
        case .communityBuilder: return "Have 5 members join your group"
        case .socialHub: return "Have 10 members join your group"

        case .explorer: return "Join 3 different groups"
        case .adventurer: return "Join 5 different groups"
        case .globetrotter: return "Join 10 different groups"

        case .socialButterfly: return "Be present with 5 different people"
        case .partyStarter: return "Be present with 10 different people"
        case .connector: return "Be present with 25 different people"

        case .weekWarrior: return "Check in 7 days in a row"
        case .dedicated: return "Check in 14 days in a row"
        case .unstoppable: return "Check in 30 days in a row"

        case .nightOwl: return "Check in after 10 PM"
        case .weekendWarrior: return "Check in on both Saturday and Sunday"
        }
    }

    var emoji: String {
        switch self {
        case .firstCheckIn: return "👣"
        case .tenCheckIns: return "🎯"
        case .fiftyCheckIns: return "⭐"
        case .hundredCheckIns: return "🏆"

        case .earlyBird: return "🐦"
        case .earlyBirdBronze: return "🥉"
        case .earlyBirdSilver: return "🥈"
        case .earlyBirdGold: return "🥇"

        case .groupCreator: return "🏠"
        case .communityBuilder: return "👥"
        case .socialHub: return "🌟"

        case .explorer: return "🗺️"
        case .adventurer: return "🧭"
        case .globetrotter: return "🌍"

        case .socialButterfly: return "🦋"
        case .partyStarter: return "🎉"
        case .connector: return "🤝"

        case .weekWarrior: return "📅"
        case .dedicated: return "💪"
        case .unstoppable: return "🔥"

        case .nightOwl: return "🦉"
        case .weekendWarrior: return "🎊"
        }
    }

    var category: AchievementCategory {
        switch self {
        case .firstCheckIn, .tenCheckIns, .fiftyCheckIns, .hundredCheckIns:
            return .checkIns
        case .earlyBird, .earlyBirdBronze, .earlyBirdSilver, .earlyBirdGold:
            return .earlyBird
        case .groupCreator, .communityBuilder, .socialHub:
            return .groups
        case .explorer, .adventurer, .globetrotter:
            return .explorer
        case .socialButterfly, .partyStarter, .connector:
            return .social
        case .weekWarrior, .dedicated, .unstoppable:
            return .streaks
        case .nightOwl, .weekendWarrior:
            return .special
        }
    }

    var points: Int {
        switch self {
        case .firstCheckIn: return 10
        case .tenCheckIns: return 25
        case .fiftyCheckIns: return 50
        case .hundredCheckIns: return 100

        case .earlyBird: return 15
        case .earlyBirdBronze: return 30
        case .earlyBirdSilver: return 50
        case .earlyBirdGold: return 100

        case .groupCreator: return 20
        case .communityBuilder: return 40
        case .socialHub: return 75

        case .explorer: return 15
        case .adventurer: return 30
        case .globetrotter: return 60

        case .socialButterfly: return 20
        case .partyStarter: return 40
        case .connector: return 80

        case .weekWarrior: return 35
        case .dedicated: return 70
        case .unstoppable: return 150

        case .nightOwl: return 15
        case .weekendWarrior: return 20
        }
    }
}

enum AchievementCategory: String, Codable, CaseIterable {
    case checkIns = "check_ins"
    case earlyBird = "early_bird"
    case groups = "groups"
    case explorer = "explorer"
    case social = "social"
    case streaks = "streaks"
    case special = "special"

    var displayName: String {
        switch self {
        case .checkIns: return "Check-Ins"
        case .earlyBird: return "Early Bird"
        case .groups: return "Groups"
        case .explorer: return "Explorer"
        case .social: return "Social"
        case .streaks: return "Streaks"
        case .special: return "Special"
        }
    }
}

/// Represents a user's earned achievement
struct UserAchievement: Codable, Identifiable {
    @DocumentID var id: String?
    let achievementType: AchievementType
    let earnedAt: Date
    let userId: String

    var achievement: AchievementType { achievementType }
}

/// Tracks user's progress toward achievements
struct UserStats: Codable {
    var totalCheckIns: Int = 0
    var earlyBirdCount: Int = 0
    var groupsCreated: Int = 0
    var groupsJoined: Int = 0
    var uniquePeopleMetCount: Int = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastCheckInDate: Date?
    var uniquePeopleMet: [String] = []  // User IDs of people met
    var checkedInOnSaturday: Bool = false
    var checkedInOnSunday: Bool = false
    var lastWeekendReset: Date?

    init() {}
}
