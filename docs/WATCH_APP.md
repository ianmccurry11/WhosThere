# Apple Watch App Documentation

## Overview

The Apple Watch companion app provides quick check-in/out functionality from the wrist.

**Target**: watchOS 10.0+
**Location**: `WhosThereWatch Watch App/`

---

## Features

- List view of all joined groups
- Nearby group detection with prominent display
- Tap to check in/out
- Auto check-in when within 100 meters
- Real-time presence counts
- Haptic feedback

---

## Files

### WhosThereWatchApp.swift
Main app entry point.

```swift
@main
struct WhosThereWatchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### ContentView.swift
Root view with navigation and state handling.

**States**:
- Loading: Shows progress indicator
- Empty: No groups joined message
- Groups: List of groups

### WatchViewModel.swift
Main view model handling data and communication.

---

## Data Model

### WatchGroup
Simplified group model for Watch.

```swift
struct WatchGroup: Identifiable, Codable {
    let id: String
    let name: String
    let emoji: String
    let centerLatitude: Double
    let centerLongitude: Double
    var presentCount: Int
    var isUserPresent: Bool
}
```

---

## WatchViewModel

### Published Properties

```swift
@Published var groups: [WatchGroup]
@Published var isLoading: Bool
@Published var nearestGroup: WatchGroup?
@Published var currentLocation: CLLocation?
```

### Key Methods

#### `loadGroups()`
Requests group data from iPhone and location update.

#### `toggleCheckIn(for group:)`
Toggles check-in status with optimistic update.

```swift
func toggleCheckIn(for group: WatchGroup) {
    let newState = !group.isUserPresent

    // Optimistic update
    if let index = groups.firstIndex(where: { $0.id == group.id }) {
        groups[index].isUserPresent = newState
        // Update presence count
    }

    // Send to iPhone
    sendMessage([
        "action": "toggleCheckIn",
        "groupId": group.id,
        "checkIn": newState
    ])

    // Haptic feedback
    WKInterfaceDevice.current().play(newState ? .success : .click)
}
```

#### `updateNearestGroup()`
Finds closest group and auto-checks-in if within 100m.

---

## iPhone Communication

Uses `WCSession` for Watch-iPhone data exchange.

### Messages Sent to iPhone

**Request Groups**:
```swift
["action": "requestGroups"]
```

**Toggle Check-in**:
```swift
[
    "action": "toggleCheckIn",
    "groupId": "abc123",
    "checkIn": true
]
```

### Messages Received from iPhone

**Groups Data**:
```swift
["groups": Data]  // JSON-encoded [WatchGroup]
```

**Presence Update**:
```swift
[
    "groupId": "abc123",
    "presentCount": 3,
    "isUserPresent": true
]
```

---

## Views

### GroupListView
Main list view with sections.

**Sections**:
1. **Nearby**: Shows nearest group prominently (if within 500m)
2. **Your Groups**: All joined groups

### NearbyGroupRow
Prominent display for nearest group.

**Features**:
- Large emoji
- Group name
- Check-in status badge
- Presence count
- Colored background based on status

### GroupRow
Standard group row for list.

**Features**:
- Emoji
- Name
- Presence count
- Check-in indicator (checkmark or circle)

### EmptyGroupsView
Shown when no groups joined.

---

## Location Handling

### Permissions
Requests "When In Use" permission on Watch.

### Location Updates
Uses `CLLocationManager.requestLocation()` for on-demand updates.

### Auto Check-in Logic
```swift
private func updateNearestGroup() {
    guard let location = currentLocation else { return }

    // Find closest group within 500m
    var closest: WatchGroup?
    var closestDistance: CLLocationDistance = .greatestFiniteMagnitude

    for group in groups {
        let distance = location.distance(from: group.center)
        if distance < 500 && distance < closestDistance {
            closest = group
            closestDistance = distance
        }
    }

    nearestGroup = closest

    // Auto check-in if within 100m and not already checked in
    if let nearest = closest,
       closestDistance < 100,
       !nearest.isUserPresent {
        toggleCheckIn(for: nearest)
    }
}
```

---

## Haptic Feedback

- **Check-in**: `.success` haptic
- **Check-out**: `.click` haptic

```swift
WKInterfaceDevice.current().play(.success)
```

---

## iPhone Side (WatchConnectivityService)

Located at: `WhosThereios/Services/WatchConnectivityService.swift`

### Initialization
Initialized in `AppDelegate` on app launch.

### sendGroupsToWatch()
Sends all joined groups with presence data.

```swift
func sendGroupsToWatch() {
    let watchGroups = firestoreService.joinedGroups.map { group in
        [
            "id": group.id,
            "name": group.name,
            "emoji": group.displayEmoji,
            "centerLatitude": group.centerLatitude,
            "centerLongitude": group.centerLongitude,
            "presentCount": presenceCount,
            "isUserPresent": isUserPresent
        ]
    }

    let data = try JSONSerialization.data(withJSONObject: watchGroups)
    session.updateApplicationContext(["groups": data])
}
```

### handleCheckInToggle()
Processes check-in requests from Watch.

```swift
func handleCheckInToggle(groupId: String, checkIn: Bool) async {
    if checkIn {
        await presenceService.manualCheckIn(groupId: groupId)
    } else {
        await presenceService.manualCheckOut(groupId: groupId)
    }

    sendPresenceUpdate(groupId: groupId)
}
```

---

## Limitations

1. **Requires iPhone**: Watch app depends on iPhone for data
2. **No Background Refresh**: Location updates only when app is open
3. **Simplified Data**: Uses WatchGroup instead of full LocationGroup
4. **No Chat**: Messaging not available on Watch

---

## Testing

1. Build Watch app to paired Watch or Simulator
2. Ensure iPhone app is running
3. Verify groups appear on Watch
4. Test check-in/out functionality
5. Test auto check-in with simulated location
6. Verify haptic feedback

---

## Adding Watch Target to Xcode

1. File → New → Target
2. Select watchOS → App
3. Product Name: "WhosThereWatch"
4. Check "Watch App"
5. Uncheck "Include Notification Scene"
6. Add existing Swift files to target
7. Configure signing
