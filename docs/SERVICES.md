# Services Documentation

## Overview

Services are singleton classes that encapsulate business logic. All services:
- Are accessed via `ServiceName.shared`
- Use `@MainActor` for thread safety
- Conform to `ObservableObject` when UI needs to observe state
- Use Swift async/await for asynchronous operations

---

## AuthService

**File**: `Services/AuthService.swift`

**Purpose**: Firebase Authentication management

### Published Properties

```swift
@Published var user: FirebaseAuth.User?
@Published var isAuthenticated: Bool
@Published var isLoading: Bool
@Published var errorMessage: String?
```

### Methods

#### `signInAnonymously()`
Creates an anonymous Firebase account.

```swift
func signInAnonymously() async
```

#### `signOut()`
Signs out the current user and clears local state.

```swift
func signOut()
```

### Usage

```swift
@StateObject private var authService = AuthService()

Button("Sign In") {
    Task {
        await authService.signInAnonymously()
    }
}
```

---

## FirestoreService

**File**: `Services/FirestoreService.swift`

**Purpose**: All Firestore database operations

### Published Properties

```swift
@Published var currentUser: User?
@Published var joinedGroups: [LocationGroup]
@Published var publicGroups: [LocationGroup]
@Published var nearbyGroups: [LocationGroup]
@Published var lastError: AppError?
```

### User Operations

#### `createUserIfNeeded(userId:displayName:email:)`
Creates user document if it doesn't exist.

#### `fetchCurrentUser()`
Fetches current user's document from Firestore.

#### `updateDisplayName(_ name:) -> AppResult<Void>`
Updates user's display name with validation.

#### `updateAutoCheckOutMinutes(_ minutes:)`
Updates user's auto-checkout timer setting.

### Group Operations

#### `createGroup(_ group:) -> AppResult<String>`
Creates a new group and returns the group ID.

```swift
let result = await firestoreService.createGroup(group)
switch result {
case .success(let groupId):
    print("Created group: \(groupId)")
case .failure(let error):
    print("Error: \(error.userMessage)")
}
```

#### `fetchJoinedGroups()`
Fetches all groups where current user is a member.

#### `fetchPublicGroups()`
Fetches discoverable public groups.

#### `fetchNearbyGroups(center:radiusKm:)`
Fetches groups near a location.

#### `joinGroup(groupId:) -> AppResult<Void>`
Adds current user to group's memberIds.

#### `joinGroupByInviteCode(_ code:) -> AppResult<LocationGroup>`
Joins a private group using invite code.

#### `leaveGroup(groupId:) -> AppResult<Void>`
Removes current user from group.

#### `deleteGroup(groupId:) -> AppResult<Void>`
Deletes group (owner only).

#### `updateGroupSettings(groupId:name:emoji:presenceDisplayMode:)`
Updates group configuration.

### Presence Operations

#### `updatePresence(groupId:isPresent:isManual:)`
Updates user's presence status at a group.

#### `fetchPresenceForGroup(groupId:) -> [Presence]`
Fetches all presence records for a group.

#### `listenToPresence(groupId:completion:) -> ListenerRegistration`
Sets up real-time listener for presence changes.

#### `clearAllPresence()`
Clears user's presence from all groups (used on sign out).

### Invite Code Operations

#### `generateInviteCode() -> String`
Generates 6-character alphanumeric invite code.

#### `findGroupByInviteCode(_ code:) -> LocationGroup?`
Looks up group by invite code.

---

## PresenceService

**File**: `Services/PresenceService.swift`

**Purpose**: Check-in/out logic and presence state management

### Published Properties

```swift
@Published var presenceByGroup: [String: GroupPresenceSummary]
@Published var manualOverrides: [String: Bool]
@Published var autoCheckOutTimers: [String: Date]
```

### Manual Check-in/out

#### `manualCheckIn(groupId:)`
Checks user in with manual override.

```swift
await presenceService.manualCheckIn(groupId: group.id!)
```

#### `manualCheckOut(groupId:)`
Checks user out with manual override.

#### `clearManualOverride(groupId:)`
Clears manual override, allowing automatic updates.

### Automatic Presence

#### `startMonitoring(groups:)`
Starts monitoring groups for automatic presence.

#### `stopMonitoring()`
Stops all presence monitoring.

#### `checkAndUpdateAllPresence(groups:)`
Checks user's current location against all groups.

### Auto Check-out Timer

#### `remainingAutoCheckOutTime(groupId:) -> TimeInterval?`
Returns remaining time until auto-checkout, or nil if no timer.

#### `resetAutoCheckOutTimer(groupId:)`
Restarts the auto-checkout timer.

### Presence Data

#### `getPresenceSummary(for groupId:) -> GroupPresenceSummary?`
Gets cached presence summary for a group.

#### `isUserPresent(groupId:userId:) -> Bool`
Checks if a specific user is present.

#### `formatPresenceDisplay(for group:) -> String`
Formats presence for display ("3 people here" or "Alice, Bob").

### Internal Methods

- `handleRegionEnter(groupId:)` - Called when user enters geofence
- `handleRegionExit(groupId:)` - Called when user exits geofence
- `performAutoCheckOut(groupId:)` - Executes auto-checkout

---

## LocationService

**File**: `Services/LocationService.swift`

**Purpose**: CoreLocation and geofencing management

### Published Properties

```swift
@Published var currentLocation: CLLocation?
@Published var authorizationStatus: CLAuthorizationStatus
@Published var isMonitoring: Bool
@Published var errorMessage: String?
```

### Callbacks

```swift
var onEnterRegion: ((String) -> Void)?  // groupId
var onExitRegion: ((String) -> Void)?   // groupId
```

### Authorization

#### `requestAuthorization()`
Requests "When In Use" permission.

#### `requestAlwaysAuthorization()`
Requests "Always" permission (for background geofencing).

### Geofencing

#### `startMonitoringGroups(_ groups:)`
Starts monitoring up to 20 nearest groups.

```swift
locationService.startMonitoringGroups(firestoreService.joinedGroups)
```

#### `stopMonitoringAllGroups()`
Stops all geofence monitoring.

#### `checkPresenceInGroups(_ groups:) -> [String: Bool]`
Checks current location against all group boundaries.

### Location

#### `checkIfUserInGroup(_ group:) -> Bool`
Checks if user is currently inside group boundary.

### Internal Details

- Uses circular regions (CLCircularRegion) for geofencing
- Calculates radius from maximum boundary point distance + 10% buffer
- iOS limit: 20 monitored regions max
- Sorts groups by distance, monitors nearest 20

---

## ChatService

**File**: `Services/ChatService.swift`

**Purpose**: Per-group messaging

### Initialization

```swift
let chatService = ChatService(groupId: "abc123")
```

### Published Properties

```swift
@Published var messages: [Message]
@Published var isLoading: Bool
@Published var error: String?
```

### Methods

#### `startListening()`
Starts real-time message listener.

#### `stopListening()`
Stops listener (called in deinit).

#### `sendMessage(_ text:) -> Bool`
Sends a message with validation and rate limiting.

```swift
let success = await chatService.sendMessage("Hello!")
```

### Static Methods

#### `getUnreadCount(groupId:since:) -> Int`
Gets count of messages since a given date.

### Constraints

- Max 500 characters per message
- 2-second rate limit between messages
- Messages auto-delete after 7 days
- Keeps max 100 messages per group

---

## AchievementService

**File**: `Services/AchievementService.swift`

**Purpose**: Achievement tracking and gamification

### Published Properties

```swift
@Published var earnedAchievements: [UserAchievement]
@Published var userStats: UserStats?
@Published var newlyUnlockedAchievement: AchievementType?
@Published var totalPoints: Int
```

### Recording Events

#### `recordCheckIn(groupId:presentMembers:)`
Records a check-in and checks related achievements.

```swift
await achievementService.recordCheckIn(
    groupId: group.id!,
    presentMembers: presenceSummary.presentMembers
)
```

#### `recordGroupCreated()`
Records group creation.

#### `recordGroupJoined()`
Records joining a group.

#### `recordGroupMemberCountChanged(count:)`
Records group size changes for community achievements.

### Query Methods

#### `getProgress(for type:) -> (current: Int, target: Int)`
Gets progress toward an achievement.

```swift
let (current, target) = achievementService.getProgress(for: .fiftyCheckIns)
// Returns (23, 50) if user has 23 of 50 check-ins
```

#### `achievementsByCategory() -> [AchievementCategory: [AchievementType]]`
Groups all achievements by category.

### Data Loading

#### `loadUserData()`
Loads achievements and stats from Firestore.

### Internal Methods

- `tryUnlock(_ type:)` - Attempts to unlock an achievement
- `checkIfFirstArrivalToday(groupId:userId:)` - Atomic transaction for Early Bird
- `updateStreak()` - Updates check-in streak

---

## NetworkMonitor

**File**: `Services/NetworkMonitor.swift`

**Purpose**: Network connectivity observation

### Published Properties

```swift
@Published var isConnected: Bool
@Published var connectionType: ConnectionType

enum ConnectionType {
    case wifi, cellular, ethernet, unknown
}
```

### Usage

```swift
@ObservedObject private var networkMonitor = NetworkMonitor.shared

if !networkMonitor.isConnected {
    OfflineBanner()
}
```

---

## WatchConnectivityService

**File**: `Services/WatchConnectivityService.swift`

**Purpose**: iPhone-Watch communication

### Methods

#### `sendGroupsToWatch()`
Sends current groups and presence to Watch.

#### `sendPresenceUpdate(groupId:)`
Sends presence change for a specific group.

### Message Handling

Receives from Watch:
- `requestGroups` - Watch requests group data
- `toggleCheckIn` - Watch requests check-in/out

### Implementation Notes

- Uses `WCSession` for communication
- Updates `applicationContext` for persistent state
- Uses `sendMessage` for real-time updates
- Handles optimistic updates on Watch side
