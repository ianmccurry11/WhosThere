# Architecture Documentation

## Overview

Who's There follows a **MVVM with Service Layer** architecture pattern, optimized for SwiftUI and Firebase real-time synchronization.

## Architectural Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          SwiftUI Views                          │
│  (HomeView, MapTabView, GroupDetailView, ProfileView, etc.)     │
└─────────────────────────────┬───────────────────────────────────┘
                              │ @ObservedObject / @StateObject
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Service Layer                            │
│  ┌─────────────┐ ┌──────────────┐ ┌────────────────┐           │
│  │ AuthService │ │FirestoreService│ │PresenceService│           │
│  └─────────────┘ └──────────────┘ └────────────────┘           │
│  ┌─────────────┐ ┌──────────────┐ ┌────────────────┐           │
│  │LocationService│ │ ChatService  │ │AchievementService│        │
│  └─────────────┘ └──────────────┘ └────────────────┘           │
│  ┌─────────────┐ ┌──────────────────────┐                      │
│  │NetworkMonitor│ │WatchConnectivityService│                    │
│  └─────────────┘ └──────────────────────┘                      │
└─────────────────────────────┬───────────────────────────────────┘
                              │ async/await
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Data Layer                              │
│  ┌────────────────┐  ┌─────────────────┐  ┌──────────────┐     │
│  │ Firebase Auth  │  │ Cloud Firestore │  │ CLLocationMgr│     │
│  └────────────────┘  └─────────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Models                                 │
│  User, LocationGroup, Presence, Message, Achievement            │
└─────────────────────────────────────────────────────────────────┘
```

## Layer Responsibilities

### Views Layer
- Pure UI presentation
- Minimal business logic
- Binds to service @Published properties
- Handles user interactions and navigation

### Service Layer
- Business logic and state management
- Firebase operations
- Real-time listeners
- Cross-cutting concerns (auth, location, network)

### Data Layer
- Firebase SDK integration
- CoreLocation integration
- WatchConnectivity integration

### Models Layer
- Pure data structures
- Codable conformance for Firebase
- Computed properties for convenience

## Service Details

### AuthService
**Purpose**: Firebase Authentication management

**Responsibilities**:
- Anonymous sign-in
- Auth state observation
- Sign out

**Published State**:
- `user: FirebaseAuth.User?`
- `isAuthenticated: Bool`
- `isLoading: Bool`

### FirestoreService
**Purpose**: All Firestore database operations

**Responsibilities**:
- User CRUD operations
- Group CRUD operations
- Presence updates
- Real-time listeners
- Invite code management

**Published State**:
- `currentUser: User?`
- `joinedGroups: [LocationGroup]`
- `publicGroups: [LocationGroup]`
- `nearbyGroups: [LocationGroup]`
- `lastError: AppError?`

### PresenceService
**Purpose**: User presence management and geofencing coordination

**Responsibilities**:
- Manual check-in/out
- Automatic presence via geofencing
- Auto-checkout timers
- Stale presence cleanup
- Presence summary calculations

**Published State**:
- `presenceByGroup: [String: GroupPresenceSummary]`
- `manualOverrides: [String: Bool]`
- `autoCheckOutTimers: [String: Date]`

### LocationService
**Purpose**: CoreLocation and geofencing management

**Responsibilities**:
- Location authorization
- Current location tracking
- Geofence region monitoring
- Point-in-polygon calculations

**Published State**:
- `currentLocation: CLLocation?`
- `authorizationStatus: CLAuthorizationStatus`
- `isMonitoring: Bool`

**Callbacks**:
- `onEnterRegion: (String) -> Void`
- `onExitRegion: (String) -> Void`

### ChatService
**Purpose**: Per-group real-time messaging

**Responsibilities**:
- Message sending with validation
- Real-time message listening
- Old message cleanup
- Rate limiting

**Published State**:
- `messages: [Message]`
- `isLoading: Bool`
- `error: String?`

### AchievementService
**Purpose**: Gamification and progress tracking

**Responsibilities**:
- Achievement unlock detection
- User stats tracking
- Progress calculations
- First-arrival race condition handling

**Published State**:
- `earnedAchievements: [UserAchievement]`
- `userStats: UserStats?`
- `newlyUnlockedAchievement: AchievementType?`
- `totalPoints: Int`

### NetworkMonitor
**Purpose**: Network connectivity observation

**Responsibilities**:
- Connection status monitoring
- Connection type detection

**Published State**:
- `isConnected: Bool`
- `connectionType: ConnectionType`

### WatchConnectivityService
**Purpose**: iPhone-Watch communication bridge

**Responsibilities**:
- Send group data to Watch
- Receive check-in commands from Watch
- Presence sync between devices

## Data Flow

### Check-In Flow
```
User taps "Check In"
        │
        ▼
PresenceService.manualCheckIn(groupId)
        │
        ▼
FirestoreService.updatePresence()
        │
        ▼
Firestore writes document
        │
        ▼
Snapshot listener fires
        │
        ▼
presenceByGroup updated
        │
        ▼
UI automatically updates
```

### Automatic Check-In Flow
```
User enters geofence region
        │
        ▼
LocationService detects entry
        │
        ▼
onEnterRegion callback fires
        │
        ▼
PresenceService.handleRegionEnter()
        │
        ▼
Check throttle (30s minimum)
        │
        ▼
FirestoreService.updatePresence()
        │
        ▼
AchievementService.recordCheckIn()
```

### Achievement Unlock Flow
```
Check-in recorded
        │
        ▼
Stats updated in Firestore
        │
        ▼
Achievement criteria checked
        │
        ▼
If met: tryUnlock(type)
        │
        ▼
Save to Firestore
        │
        ▼
Set newlyUnlockedAchievement
        │
        ▼
Toast + Confetti displayed
        │
        ▼
Clear after 3 seconds
```

## Concurrency Model

### Thread Safety
- All services use `@MainActor` for UI thread safety
- Firebase operations use async/await
- Background tasks use structured concurrency

### Example
```swift
@MainActor
class ExampleService: ObservableObject {
    @Published var data: [Item] = []

    func loadData() async {
        // Already on main actor, safe to update @Published
        let items = await fetchFromFirestore()
        self.data = items
    }
}
```

## Real-Time Synchronization

### Firestore Listeners
- Presence changes: Real-time snapshot listener per group
- Messages: Real-time snapshot listener per group
- User data: Fetched on demand, cached locally

### Optimistic Updates
- UI updates immediately on user action
- Firestore write happens asynchronously
- Rollback on failure (rare)

## Error Handling Strategy

### AppError Enum
Centralized error types with:
- `errorDescription`: Full technical description
- `userMessage`: Short user-friendly message
- `recoverySuggestion`: How to fix the issue
- `shouldLog`: Whether to log for debugging

### Error Propagation
```swift
func someOperation() async -> AppResult<Data> {
    guard authenticated else {
        return .failure(.notAuthenticated)
    }

    do {
        let data = try await firebase.fetch()
        return .success(data)
    } catch {
        return .failure(.serverError(underlying: error))
    }
}
```

## State Management

### Published Properties
Services expose state via @Published for automatic SwiftUI updates.

### Derived State
Views compute derived state from published properties:
```swift
var isUserCheckedIn: Bool {
    presenceService.isUserPresent(groupId: group.id, userId: userId)
}
```

### Local State
Views use @State for UI-only state:
```swift
@State private var showingSheet = false
@State private var inputText = ""
```
