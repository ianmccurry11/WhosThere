# CLAUDE.md - AI Development Guidelines for Who's There

This document provides context and guidelines for AI assistants working on the Who's There codebase.

## Project Overview

Who's There is a location-based presence iOS app built with SwiftUI and Firebase. Users create geographic "groups" (locations) and can see/share their presence at these locations with other members.

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Backend**: Firebase (Firestore, Auth, Analytics)
- **Platforms**: iOS 17+, watchOS 10+
- **Architecture**: MVVM with Service Layer
- **Concurrency**: Swift async/await, @MainActor

## Project Structure

```
WhosThereios/
├── Models/           # Data structures (User, Group, Message, Presence, Achievement)
├── Services/         # Business logic singletons
│   ├── AuthService.swift           # Firebase anonymous auth
│   ├── FirestoreService.swift      # All Firestore operations
│   ├── PresenceService.swift       # Check-in/out logic, geofencing callbacks
│   ├── LocationService.swift       # CLLocationManager, geofencing
│   ├── ChatService.swift           # Per-group messaging
│   ├── AchievementService.swift    # Gamification system
│   ├── NetworkMonitor.swift        # Connectivity status
│   └── WatchConnectivityService.swift  # iPhone-Watch bridge
├── Views/            # SwiftUI views organized by feature
│   ├── Auth/         # SignInView
│   ├── Home/         # HomeView, MapTabView, ListTabView
│   ├── Groups/       # Create, Detail, Chat, Settings views
│   ├── Profile/      # ProfileView, AchievementsView
│   ├── Onboarding/   # OnboardingView
│   ├── SplashScreen/ # SplashScreenView
│   └── Components/   # Reusable UI (StatusBanner, ConfettiView)
├── Utilities/        # Helpers
│   ├── AppError.swift      # Centralized error types
│   ├── Validation.swift    # Input validation & sanitization
│   └── HapticManager.swift # Haptic feedback
└── Assets.xcassets/  # Images, colors, app icon
```

## Key Architectural Patterns

### 1. Service Singletons
All services are `@MainActor` singletons accessed via `.shared`:
```swift
FirestoreService.shared
PresenceService.shared
LocationService.shared
AchievementService.shared
```

### 2. Reactive State
Services use `@Published` properties for SwiftUI binding:
```swift
@Published var joinedGroups: [LocationGroup] = []
@Published var isLoading = false
```

### 3. Error Handling
Use `AppError` enum and `AppResult<T>` type alias:
```swift
func createGroup(_ group: LocationGroup) async -> AppResult<String>
```

### 4. Validation
Always validate user input using `Validation` module:
```swift
let result = Validation.validateGroupName(name)
if !result.isValid { return .failure(result.error!) }
```

## Important Conventions

### Code Style
- Use Swift's native async/await (not completion handlers)
- Prefer `@MainActor` for UI-related classes
- Use meaningful variable names, avoid abbreviations
- Add MARK comments for code organization
- Keep functions focused and under 30 lines when possible

### Firebase Operations
- Always check authentication before Firestore operations
- Use merge: true for partial updates
- Validate data before writing to Firestore
- Handle errors gracefully with user-friendly messages

### Location & Presence
- Respect iOS geofence limits (max 20 regions)
- Throttle automatic presence updates (30-second minimum)
- Auto-checkout stale presences after 10 hours
- Support both "Always" and "When In Use" location permissions

### UI/UX
- Add haptic feedback for significant actions
- Show loading states for async operations
- Handle offline state gracefully
- Support pull-to-refresh where appropriate
- Use SF Symbols for icons

## Common Tasks

### Adding a New Achievement
1. Add case to `AchievementType` enum in `Achievement.swift`
2. Add to appropriate `AchievementCategory`
3. Define displayName, description, emoji, points, category
4. Add unlock logic in `AchievementService.swift`

### Adding a New Group Property
1. Add property to `LocationGroup` struct in `Group.swift`
2. Add to `CodingKeys` enum
3. Update initializer
4. Update Firebase security rules if needed
5. Add UI in `CreateGroupView` and `GroupSettingsView`

### Adding a New Service
1. Create file in `Services/` directory
2. Make it `@MainActor class` with `static let shared`
3. Conform to `ObservableObject` if UI needs to observe it
4. Initialize in `WhosThereiosApp.swift` if needed at startup

## Firebase Security Rules

The security rules are in `firestore.rules`. Key principles:
- Users can only read/write their own user document
- Group members can read group data
- Public groups are readable by all authenticated users
- Presence can only be written by the user it belongs to
- Messages require group membership

## Testing Guidelines

- Test on real devices for location features
- Test with both "Always" and "When In Use" permissions
- Test offline scenarios
- Test achievement edge cases (streaks, first arrival race conditions)
- Test Apple Watch communication

## Known Limitations

1. **Geofence Limit**: iOS allows max 20 monitored regions
2. **Background Location**: Requires "Always" permission for auto check-in
3. **Watch Independence**: Watch requires iPhone connection for data
4. **Message Retention**: Messages auto-delete after 7 days

## Do NOT

- Do not commit Firebase credentials or API keys
- Do not use force unwrapping (`!`) without safety checks
- Do not block the main thread with synchronous operations
- Do not ignore error handling
- Do not hardcode strings that should be localized
- Do not modify security rules without understanding implications

## Helpful Commands

```bash
# Build iOS app
xcodebuild -scheme WhosThereios -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Deploy Firebase rules
firebase deploy --only firestore:rules

# Run tests
xcodebuild test -scheme WhosThereios -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Contact

For questions about this codebase, check existing documentation first, then ask the development team.
