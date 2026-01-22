# Data Models Documentation

## Overview

All models are defined in `WhosThereios/Models/` and follow these conventions:
- Conform to `Codable` for Firebase serialization
- Conform to `Identifiable` for SwiftUI lists
- Use `@DocumentID` for Firestore document IDs
- Include computed properties for convenience

---

## User

**File**: `Models/User.swift`

**Purpose**: Represents an app user

```swift
struct User: Identifiable, Codable {
    @DocumentID var id: String?
    var displayName: String
    var email: String?
    var joinedGroupIds: [String]
    var createdAt: Date
    var autoCheckOutMinutes: Int  // Default: 60
}
```

**Firestore Path**: `users/{userId}`

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| id | String | Firebase Auth UID |
| displayName | String | User's display name (1-50 chars) |
| email | String? | Optional email |
| joinedGroupIds | [String] | Array of group IDs user has joined |
| createdAt | Date | Account creation timestamp |
| autoCheckOutMinutes | Int | Auto-checkout timer duration |

---

## LocationGroup

**File**: `Models/Group.swift`

**Purpose**: Represents a geographic location group

```swift
struct LocationGroup: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var emoji: String?
    var isPublic: Bool
    var ownerId: String
    var memberIds: [String]
    var boundary: [Coordinate]
    var centerLatitude: Double
    var centerLongitude: Double
    var presenceDisplayMode: PresenceDisplayMode
    var createdAt: Date
    var inviteCode: String?
    var groupColor: GroupColor?
}
```

**Firestore Path**: `groups/{groupId}`

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| id | String | Auto-generated document ID |
| name | String | Group name (1-100 chars) |
| emoji | String? | Custom emoji icon |
| isPublic | Bool | Whether group is discoverable |
| ownerId | String | Creator's user ID |
| memberIds | [String] | Array of member user IDs |
| boundary | [Coordinate] | Polygon boundary points (3-100) |
| centerLatitude | Double | Calculated center latitude |
| centerLongitude | Double | Calculated center longitude |
| presenceDisplayMode | Enum | "count" or "names" |
| createdAt | Date | Creation timestamp |
| inviteCode | String? | 6-char invite code for private groups |
| groupColor | GroupColor? | Boundary color on map |

**Computed Properties**:
- `displayEmoji`: Returns emoji or default based on public/private
- `displayColor`: Returns color or default (blue)
- `center`: CLLocationCoordinate2D from lat/lng
- `boundaryCoordinates`: [CLLocationCoordinate2D] array

**Methods**:
- `contains(coordinate:)`: Point-in-polygon test

---

## Coordinate

**File**: `Models/Group.swift`

**Purpose**: Lat/lng pair for boundary points

```swift
struct Coordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double
}
```

---

## GroupColor

**File**: `Models/Group.swift`

**Purpose**: Predefined colors for group boundaries

```swift
enum GroupColor: String, Codable, CaseIterable {
    case blue, green, red, orange, purple, pink, teal, yellow
}
```

---

## PresenceDisplayMode

**File**: `Models/Group.swift`

**Purpose**: How presence is shown to members

```swift
enum PresenceDisplayMode: String, Codable {
    case count = "count"   // "3 people here"
    case names = "names"   // "Alice, Bob, Carol"
}
```

---

## Presence

**File**: `Models/Presence.swift`

**Purpose**: User's presence status at a group

```swift
struct Presence: Identifiable, Codable {
    @DocumentID var id: String?
    var userId: String
    var groupId: String
    var isPresent: Bool
    var isManual: Bool
    var lastUpdated: Date
    var displayName: String
}
```

**Firestore Path**: `presence/{groupId}/members/{userId}`

**Fields**:
| Field | Type | Description |
|-------|------|-------------|
| id | String | Same as userId |
| userId | String | User's ID |
| groupId | String | Group's ID |
| isPresent | Bool | Currently at location |
| isManual | Bool | Manual vs automatic check-in |
| lastUpdated | Date | Last status change |
| displayName | String | Cached display name |

---

## GroupPresenceSummary

**File**: `Models/Presence.swift`

**Purpose**: Aggregate presence data for a group

```swift
struct GroupPresenceSummary {
    let groupId: String
    let presentCount: Int
    let presentMembers: [Presence]
}
```

---

## Message

**File**: `Models/Message.swift`

**Purpose**: Chat message in a group

```swift
struct Message: Identifiable, Codable {
    @DocumentID var id: String?
    var text: String
    var senderId: String
    var senderName: String
    var groupId: String
    var createdAt: Date
}
```

**Firestore Path**: `groups/{groupId}/messages/{messageId}`

**Constraints**:
- Max 500 characters per message
- 2-second rate limit between messages
- Auto-delete after 7 days
- Max 100 messages per group

---

## ChatMetadata

**File**: `Models/Message.swift`

**Purpose**: Group chat summary data

```swift
struct ChatMetadata: Codable {
    var lastMessageText: String?
    var lastMessageTime: Date?
    var unreadCount: Int
}
```

---

## Achievement Types

**File**: `Models/Achievement.swift`

### AchievementType Enum

20+ achievement types across categories:

**Check-in Achievements**:
- `firstCheckIn` - First check-in ever
- `tenCheckIns` - 10 total check-ins
- `fiftyCheckIns` - 50 total check-ins
- `hundredCheckIns` - 100 total check-ins

**Early Bird**:
- `earlyBird` - First person at location for the day

**Groups**:
- `groupCreator` - Create first group
- `fiveGroups` - Create 5 groups

**Explorer**:
- `explorer` - Join 5 different groups
- `globetrotter` - Join 10 different groups

**Social**:
- `socialButterfly` - Meet 10 unique people
- `communityBuilder` - Be in a group with 5+ people
- `partyStarter` - Be in a group with 10+ people

**Streaks**:
- `threeDayStreak` - 3-day check-in streak
- `weekStreak` - 7-day streak
- `monthStreak` - 30-day streak

**Special**:
- `weekendWarrior` - Check in on both Saturday and Sunday
- `nightOwl` - Check in after 10 PM

### AchievementCategory Enum

```swift
enum AchievementCategory: String, CaseIterable {
    case checkIns, earlyBird, groups, explorer, social, streaks, special
}
```

### Achievement Properties

Each `AchievementType` has:
- `displayName`: Human-readable name
- `description`: How to earn it
- `emoji`: Visual icon
- `points`: 10-150 points
- `category`: Which category it belongs to

---

## UserAchievement

**File**: `Models/Achievement.swift`

**Purpose**: Record of earned achievement

```swift
struct UserAchievement: Identifiable, Codable {
    @DocumentID var id: String?
    var achievementType: AchievementType
    var earnedAt: Date
    var userId: String
}
```

**Firestore Path**: `users/{userId}/achievements/{achievementType}`

---

## UserStats

**File**: `Models/Achievement.swift`

**Purpose**: User progress tracking

```swift
struct UserStats: Codable {
    var totalCheckIns: Int
    var uniqueGroupsVisited: Int
    var groupsCreated: Int
    var groupsJoined: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastCheckInDate: Date?
    var uniquePeopleMet: Int
    var maxGroupSize: Int
    var hasWeekendSaturday: Bool
    var hasWeekendSunday: Bool
    var weekendWeekNumber: Int?
}
```

**Firestore Path**: `users/{userId}/stats/current`

---

## Validation Constraints

All input validation is in `Utilities/Validation.swift`:

| Field | Min | Max | Notes |
|-------|-----|-----|-------|
| Display Name | 1 | 50 | Alphanumeric + basic punctuation |
| Group Name | 1 | 100 | Any characters |
| Boundary Points | 3 | 100 | Valid lat/lng pairs |
| Boundary Area | 100 m² | 1 km² | ~10x10m to ~247 acres |
| Invite Code | 6 | 6 | Alphanumeric, no ambiguous chars |
| Message | 1 | 500 | Any characters |
