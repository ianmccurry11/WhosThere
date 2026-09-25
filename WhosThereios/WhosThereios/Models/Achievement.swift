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
    case earlyRiser = "early_riser"           // Check in before 7 AM
    case lateNightOwl = "late_night_owl"      // Check in after 11 PM
    case lastOneStanding = "last_one_standing" // Be the last person to leave
    case marathonSession = "marathon_session"  // Stay checked in 4+ hours

    // Friends achievements
    case firstFriend = "first_friend"          // Add your first friend
    case friendCollector = "friend_collector"  // Have 10+ friends
    case popularKid = "popular_kid"            // Be in 5+ groups at once
    case crewUp = "crew_up"                    // Be checked in with 3+ friends

    // Chat achievements
    case chatterbox = "chatterbox"             // Send 50 messages total
    case conversationStarter = "conversation_starter" // Send first message in a group chat
    case prolificMessenger = "prolific_messenger"     // Send 10 messages in one day

    // Seasonal achievements
    case midnightCrew = "midnight_crew"        // Check in between midnight and 1 AM
    case holidaySpirit = "holiday_spirit"      // Check in on a major holiday
    case newYearCheckIn = "new_year_check_in"  // Check in on January 1st

    // Additional group achievements
    case tripleBuilder = "triple_builder"      // Create 3 groups
    case homebody = "homebody"                 // Check in to same group 20 times
    case loyalMember = "loyal_member"          // Check in to same group 30 times
    case landlord = "landlord"                 // Own a group with 10+ members

    // Additional streak achievements
    case onARoll = "on_a_roll"                 // 3-day check-in streak
    case creatureOfHabit = "creature_of_habit" // Same group, same hour, 5 days in a row

    // App exploration achievements
    case friendlyFace = "friendly_face"         // Send a friend request
    case welcomeCommittee = "welcome_committee" // Accept a friend request
    case identitySet = "identity_set"           // Set your display name
    case settingsExplorer = "settings_explorer" // View group settings
    case favoritesFan = "favorites_fan"         // Favorite 4 groups
    case shareTheLove = "share_the_love"        // Share a group invite link
    case appAmbassador = "app_ambassador"       // Share the app
    case privateEntry = "private_entry"         // Join a private group via invite code
    case firstMessage = "first_message"         // Send your first chat message
    case topVisitor = "top_visitor"             // Be #1 visitor in a group for a month

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
        case .earlyRiser: return "Early Riser"
        case .lateNightOwl: return "Late Night Owl"
        case .lastOneStanding: return "Last One Standing"
        case .marathonSession: return "Marathon"

        case .firstFriend: return "First Friend"
        case .friendCollector: return "Friend Collector"
        case .popularKid: return "Popular Kid"
        case .crewUp: return "Crew Up"

        case .chatterbox: return "Chatterbox"
        case .conversationStarter: return "Conversation Starter"
        case .prolificMessenger: return "Prolific Messenger"

        case .midnightCrew: return "Midnight Crew"
        case .holidaySpirit: return "Holiday Spirit"
        case .newYearCheckIn: return "New Year Check-In"

        case .tripleBuilder: return "Triple Builder"
        case .homebody: return "Homebody"
        case .loyalMember: return "Loyal Member"
        case .landlord: return "Landlord"

        case .onARoll: return "On a Roll"
        case .creatureOfHabit: return "Creature of Habit"

        case .friendlyFace: return "Friendly Face"
        case .welcomeCommittee: return "Welcome Committee"
        case .identitySet: return "Identity Set"
        case .settingsExplorer: return "Settings Explorer"
        case .favoritesFan: return "Favorites Fan"
        case .shareTheLove: return "Share the Love"
        case .appAmbassador: return "App Ambassador"
        case .privateEntry: return "Private Entry"
        case .firstMessage: return "First Message"
        case .topVisitor: return "Top Visitor"
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
        case .earlyRiser: return "Check in before 7 AM"
        case .lateNightOwl: return "Check in after 11 PM"
        case .lastOneStanding: return "Be the last person to leave a group"
        case .marathonSession: return "Stay checked in for 4+ hours"

        case .firstFriend: return "Add your first friend"
        case .friendCollector: return "Have 10 or more friends"
        case .popularKid: return "Be in 5 or more groups at once"
        case .crewUp: return "Be checked in with 3 or more friends"

        case .chatterbox: return "Send 50 messages total"
        case .conversationStarter: return "Send the first message in a group chat"
        case .prolificMessenger: return "Send 10 messages in one day"

        case .midnightCrew: return "Check in between midnight and 1 AM"
        case .holidaySpirit: return "Check in on a major holiday"
        case .newYearCheckIn: return "Check in on January 1st"

        case .tripleBuilder: return "Create 3 groups"
        case .homebody: return "Check in to the same group 20 times"
        case .loyalMember: return "Check in to the same group 30 times"
        case .landlord: return "Own a group with 10 or more members"

        case .onARoll: return "Check in 3 days in a row"
        case .creatureOfHabit: return "Same group, same hour, 5 days in a row"

        case .friendlyFace: return "Send a friend request"
        case .welcomeCommittee: return "Accept a friend request"
        case .identitySet: return "Set your display name"
        case .settingsExplorer: return "View group settings"
        case .favoritesFan: return "Favorite 4 groups"
        case .shareTheLove: return "Share a group invite link"
        case .appAmbassador: return "Share the app with someone"
        case .privateEntry: return "Join a private group via invite code"
        case .firstMessage: return "Send your first chat message"
        case .topVisitor: return "Be the #1 visitor in a group for a month"
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
        case .earlyRiser: return "🌅"
        case .lateNightOwl: return "🌙"
        case .lastOneStanding: return "🧍"
        case .marathonSession: return "⏱️"

        case .firstFriend: return "👋"
        case .friendCollector: return "🫂"
        case .popularKid: return "😎"
        case .crewUp: return "👯"

        case .chatterbox: return "💬"
        case .conversationStarter: return "🗣️"
        case .prolificMessenger: return "📨"

        case .midnightCrew: return "🌃"
        case .holidaySpirit: return "🎄"
        case .newYearCheckIn: return "🎆"

        case .tripleBuilder: return "🏗️"
        case .homebody: return "🏡"
        case .loyalMember: return "🪪"
        case .landlord: return "🔑"

        case .onARoll: return "🎲"
        case .creatureOfHabit: return "⏰"

        case .friendlyFace: return "😊"
        case .welcomeCommittee: return "🤗"
        case .identitySet: return "🪪"
        case .settingsExplorer: return "⚙️"
        case .favoritesFan: return "⭐"
        case .shareTheLove: return "📤"
        case .appAmbassador: return "📣"
        case .privateEntry: return "🔐"
        case .firstMessage: return "✉️"
        case .topVisitor: return "👑"
        }
    }

    var category: AchievementCategory {
        switch self {
        case .firstCheckIn, .tenCheckIns, .fiftyCheckIns, .hundredCheckIns:
            return .checkIns
        case .earlyBird, .earlyBirdBronze, .earlyBirdSilver, .earlyBirdGold:
            return .earlyBird
        case .groupCreator, .communityBuilder, .socialHub, .tripleBuilder, .homebody, .loyalMember, .landlord:
            return .groups
        case .explorer, .adventurer, .globetrotter:
            return .explorer
        case .socialButterfly, .partyStarter, .connector:
            return .social
        case .weekWarrior, .dedicated, .unstoppable, .onARoll, .creatureOfHabit:
            return .streaks
        case .nightOwl, .weekendWarrior, .earlyRiser, .lateNightOwl, .lastOneStanding, .marathonSession:
            return .special
        case .firstFriend, .friendCollector, .popularKid, .crewUp:
            return .friends
        case .chatterbox, .conversationStarter, .prolificMessenger:
            return .chat
        case .midnightCrew, .holidaySpirit, .newYearCheckIn:
            return .seasonal
        case .friendlyFace, .welcomeCommittee, .identitySet, .settingsExplorer,
             .favoritesFan, .shareTheLove, .appAmbassador, .privateEntry, .firstMessage:
            return .appExploration
        case .topVisitor:
            return .groups
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
        case .earlyRiser: return 15
        case .lateNightOwl: return 15
        case .lastOneStanding: return 20
        case .marathonSession: return 40

        case .firstFriend: return 15
        case .friendCollector: return 50
        case .popularKid: return 30
        case .crewUp: return 35

        case .chatterbox: return 40
        case .conversationStarter: return 20
        case .prolificMessenger: return 25

        case .midnightCrew: return 20
        case .holidaySpirit: return 30
        case .newYearCheckIn: return 50

        case .tripleBuilder: return 30
        case .homebody: return 40
        case .loyalMember: return 60
        case .landlord: return 50

        case .onARoll: return 20
        case .creatureOfHabit: return 75

        case .friendlyFace: return 10
        case .welcomeCommittee: return 10
        case .identitySet: return 10
        case .settingsExplorer: return 10
        case .favoritesFan: return 25
        case .shareTheLove: return 15
        case .appAmbassador: return 20
        case .privateEntry: return 15
        case .firstMessage: return 10
        case .topVisitor: return 50
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
    case friends = "friends"
    case chat = "chat"
    case seasonal = "seasonal"
    case appExploration = "app_exploration"

    var displayName: String {
        switch self {
        case .checkIns: return "Check-Ins"
        case .earlyBird: return "Early Bird"
        case .groups: return "Groups"
        case .explorer: return "Explorer"
        case .social: return "Social"
        case .streaks: return "Streaks"
        case .special: return "Special"
        case .friends: return "Friends"
        case .chat: return "Chat"
        case .seasonal: return "Seasonal"
        case .appExploration: return "App Explorer"
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

/// Represents a user's level in the 100-level XP system.
/// Levels 1-100 with tier names every 10 levels.
/// XP formula: xpToAdvance(from level) = 30 + (level - 1) * 5
struct UserLevel {
    let level: Int           // 1-100
    let tierName: String     // e.g., "Newcomer", "Regular", etc.
    let currentXP: Int       // Total XP the user has
    let xpForCurrentLevel: Int   // Cumulative XP needed to reach current level
    let xpForNextLevel: Int?     // Cumulative XP needed to reach next level (nil if max)

    /// Progress from 0.0 to 1.0 toward the next level
    var progressToNextLevel: Double {
        guard let nextXP = xpForNextLevel else { return 1.0 }
        let range = nextXP - xpForCurrentLevel
        guard range > 0 else { return 1.0 }
        return Double(currentXP - xpForCurrentLevel) / Double(range)
    }

    /// XP remaining until next level
    var xpToNextLevel: Int {
        guard let nextXP = xpForNextLevel else { return 0 }
        return max(0, nextXP - currentXP)
    }

    /// Whether this is the maximum level
    var isMaxLevel: Bool { level >= Self.maxLevel }

    /// SF Symbol name for the level tier icon
    var tierIcon: String {
        switch level {
        case 1...10: return "leaf.fill"
        case 11...20: return "figure.walk"
        case 21...30: return "binoculars.fill"
        case 31...40: return "flame.fill"
        case 41...50: return "star.fill"
        case 51...60: return "shield.fill"
        case 61...70: return "bolt.fill"
        case 71...80: return "crown.fill"
        case 81...90: return "trophy.fill"
        case 91...100: return "medal.fill"
        default: return "leaf.fill"
        }
    }

    // MARK: - Constants

    static let maxLevel = 100

    static let tierNames: [(range: ClosedRange<Int>, name: String)] = [
        (1...10, "Newcomer"),
        (11...20, "Regular"),
        (21...30, "Explorer"),
        (31...40, "Enthusiast"),
        (41...50, "Dedicated"),
        (51...60, "Veteran"),
        (61...70, "Expert"),
        (71...80, "Master"),
        (81...90, "Legend"),
        (91...100, "Champion")
    ]

    // MARK: - XP Calculations

    /// XP needed to go from level `n` to level `n+1`
    static func xpToAdvance(from level: Int) -> Int {
        return 30 + (level - 1) * 5
    }

    /// Total cumulative XP needed to reach a given level
    static func cumulativeXP(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let n = level - 1
        // Sum of (30 + (i-1)*5) for i = 1 to n = 30*n + 5*(n-1)*n/2
        return 30 * n + 5 * (n - 1) * n / 2
    }

    /// Tier name for a given level
    static func tierName(for level: Int) -> String {
        let clamped = min(max(level, 1), maxLevel)
        return tierNames.first { $0.range.contains(clamped) }?.name ?? "Newcomer"
    }

    /// Calculate UserLevel from total XP
    static func calculate(from totalXP: Int) -> UserLevel {
        var currentLevel = 1

        for lvl in 2...maxLevel {
            if totalXP >= cumulativeXP(forLevel: lvl) {
                currentLevel = lvl
            } else {
                break
            }
        }

        let currentLevelXP = cumulativeXP(forLevel: currentLevel)
        let nextLevelXP: Int? = currentLevel < maxLevel
            ? cumulativeXP(forLevel: currentLevel + 1)
            : nil

        return UserLevel(
            level: currentLevel,
            tierName: tierName(for: currentLevel),
            currentXP: totalXP,
            xpForCurrentLevel: currentLevelXP,
            xpForNextLevel: nextLevelXP
        )
    }
}

/// Tracks consecutive same-group, same-hour check-ins for Creature of Habit
struct HabitEntry: Codable {
    var lastCheckInHour: Int
    var consecutiveDays: Int
    var lastCheckInDate: Date?
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

    // Friends
    var friendCount: Int = 0

    // Chat
    var totalMessagesSent: Int = 0
    var messagesToday: Int = 0
    var lastMessageDate: Date?
    var groupsWithFirstMessage: [String] = []

    // Per-group tracking
    var groupCheckInCounts: [String: Int] = [:]

    // Habit tracking (Creature of Habit)
    var habitTracker: [String: HabitEntry] = [:]

    // Session tracking
    var longestSessionMinutes: Int = 0
    var wasLastToLeaveCount: Int = 0

    // XP / Level tracking
    var totalXP: Int = 0
    var lastDailyLoginDate: Date?

    // App exploration tracking
    var hasSentFriendRequest: Bool = false
    var hasAcceptedFriendRequest: Bool = false
    var hasSetDisplayName: Bool = false
    var hasViewedGroupSettings: Bool = false
    var favoriteGroupCount: Int = 0
    var hasSharedGroupLink: Bool = false
    var hasSharedApp: Bool = false
    var hasJoinedPrivateGroup: Bool = false

    init() {}
}
