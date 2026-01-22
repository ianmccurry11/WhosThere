# Who's There

A location-based presence app for iOS and Apple Watch that helps users see who's at their favorite spots.

## Overview

Who's There allows users to create and join location-based groups (basketball courts, coffee shops, parks, etc.) and see who else is currently there. The app uses geofencing for automatic check-ins and supports manual check-ins for users who prefer more control.

### Key Features

- **Location Groups**: Create custom geographic boundaries for any location
- **Real-time Presence**: See who's currently at a location
- **Automatic Check-ins**: Uses geofencing to detect when you arrive/leave
- **Manual Check-ins**: Toggle presence manually with auto-checkout timers
- **Group Chat**: Real-time messaging within groups
- **Achievements**: Gamification system with 20+ achievements
- **Apple Watch**: Quick check-in/out from your wrist
- **Privacy-First**: Only shares presence status, never exact location

## Requirements

- iOS 17.0+
- watchOS 10.0+
- Xcode 15.0+
- Firebase account
- Apple Developer account (for distribution)

## Installation

1. Clone the repository
2. Open `WhosThereios.xcodeproj` in Xcode
3. Add your `GoogleService-Info.plist` from Firebase Console
4. Build and run

## Project Structure

```
WhosThereios/
├── WhosThereios/              # Main iOS app
│   ├── Models/                # Data models
│   ├── Services/              # Business logic & Firebase
│   ├── Views/                 # SwiftUI views
│   ├── Utilities/             # Helpers & error handling
│   └── Assets.xcassets/       # Images & colors
├── WhosThereWatch Watch App/  # Apple Watch app
├── WhosThereiosTests/         # Unit tests
└── firestore.rules            # Firebase security rules
```

## Architecture

The app follows **MVVM with Service Layer** architecture:

- **Models**: Pure data structures with Codable conformance
- **Services**: Singleton business logic services (@MainActor, ObservableObject)
- **Views**: SwiftUI views with minimal logic
- **Utilities**: Cross-cutting concerns (validation, errors, haptics)

## Firebase Collections

```
users/{userId}
├── achievements/{type}
└── stats/current

groups/{groupId}
├── messages/{messageId}
└── daily_first_arrival/{date}

presence/{groupId}/members/{userId}
```

## License

Private - All rights reserved

## Support

For issues, contact the development team.
