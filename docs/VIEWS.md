# Views Documentation

## Overview

All views are SwiftUI-based and located in `WhosThereios/Views/`, organized by feature.

---

## App Entry Points

### WhosThereiosApp.swift
Main app entry point with Firebase initialization.

### ContentView.swift
Root navigation controller handling:
- Splash screen (1.5 seconds)
- Onboarding flow (first launch)
- Authentication state
- Main app navigation

---

## Auth Views

### SignInView.swift

**Purpose**: Anonymous sign-in screen

**Features**:
- App logo and tagline
- Feature highlights
- Anonymous sign-in button
- Loading state

**Usage**:
```swift
SignInView()
```

---

## Home Views

### HomeView.swift

**Purpose**: Main app container with tab navigation

**Components**:
- Custom tab bar (Map / List / Create / Profile)
- Offline banner when disconnected
- Achievement unlock toast with confetti

**State**:
```swift
@State private var selectedTab = 0
@State private var showCreateGroup = false
@State private var showProfile = false
@State private var showConfetti = false
```

### MapTabView.swift

**Purpose**: Map display of groups

**Features**:
- User location annotation
- Group boundary polygons (colored by group color)
- Group center annotations with presence info
- Tap to view group details
- Location permission overlay if denied

**Key Logic**:
- Deduplicates joined + public groups
- Colors boundaries based on membership and group color
- Fetches nearby groups on significant location change (100m+)

### ListTabView.swift

**Purpose**: List view of groups

**Sections**:
1. **Joined Groups**: Groups user is a member of
2. **Nearby Groups**: Public groups near user

**Features**:
- Group rows with emoji, name, presence count
- Tap for group details
- Empty state when no groups

---

## Group Views

### CreateGroupView.swift

**Purpose**: Create new location group

**Steps**:
1. Enter group name
2. Set public/private
3. Choose presence display mode
4. Select boundary color
5. Draw boundary on map

**Boundary Drawing**:
- Tap map to add points
- Tap marker to select, tap elsewhere to move
- Long press marker for delete option
- Minimum 3 points required
- Validates area size (100m² - 1km²)

**State**:
```swift
@State private var groupName = ""
@State private var isPublic = true
@State private var presenceMode: PresenceDisplayMode = .names
@State private var selectedColor: GroupColor = .blue
@State private var boundaryPoints: [CLLocationCoordinate2D] = []
```

### GroupDetailView.swift

**Purpose**: View and interact with a group

**Sections**:
1. **Map**: Group boundary with user location
2. **Info Card**: Name, emoji, owner badge, public/private
3. **Check-in Button**: Toggle presence (if member)
4. **Auto-checkout Timer**: Shows remaining time
5. **Present Members**: List of checked-in users
6. **Invite Code**: For private groups (tap to copy)
7. **Actions**: Chat, Settings, Leave/Delete

**Conditional UI**:
- Join button if not member
- Settings if owner
- Delete if owner
- Leave if member (not owner)

### GroupChatView.swift

**Purpose**: Real-time group messaging

**Features**:
- Message list with auto-scroll
- Message bubbles (different for own vs others)
- Message input with send button
- Empty state when no messages
- Real-time updates via listener

**Message Bubble**:
- Sender name (for others' messages)
- Message text
- Timestamp

### GroupSettingsView.swift

**Purpose**: Edit group settings (owner only)

**Editable**:
- Group name
- Group emoji (picker with suggestions)
- Presence display mode

**Danger Zone**:
- Delete group (with confirmation)

---

## Profile Views

### ProfileView.swift

**Purpose**: User profile and settings

**Sections**:
1. **Display Name**: Editable with validation
2. **Auto Check-out Timer**: Picker (30min - 4hr)
3. **Achievements Link**: Navigate to achievements
4. **Sign Out**: With confirmation

### AchievementsView.swift

**Purpose**: Achievement gallery with progress

**Components**:
- Points summary card
- Category filter pills
- Achievement grid by category

**Achievement Card**:
- Emoji icon
- Name and description
- Points value
- Progress bar (if not earned)
- Earned date (if earned)
- Locked/unlocked state

---

## Onboarding Views

### OnboardingView.swift

**Purpose**: First-launch introduction

**Pages**:
1. **Find Your Crew**: Create/join groups explanation
2. **Privacy First**: Location privacy explanation
3. **Know Who's There**: Real-time presence
4. **Location Access**: Permission request context

**Features**:
- Animated page transitions
- Progress indicators
- Continue/Skip buttons
- Stored completion in UserDefaults

---

## Splash Screen

### SplashScreenView.swift

**Purpose**: Launch animation

**Features**:
- App icon with pulsing animation
- App name fade-in
- 1.5 second duration
- Smooth transition to main content

---

## Component Views

### StatusBanner.swift

**Contains multiple reusable components**:

#### StatusBanner
Generic banner for status messages.
```swift
StatusBanner(message: "No internet", type: .offline)
```

Types: `.info`, `.warning`, `.error`, `.offline`

#### OfflineBanner
Pre-configured offline indicator.

#### ErrorToast
Floating error message.

#### EmptyStateView
Generic empty state with icon and message.
```swift
EmptyStateView(
    icon: "person.3",
    title: "No Groups",
    message: "Create or join a group to get started"
)
```

#### LoadingView
Full-screen loading indicator.

#### SkeletonLoader / SkeletonCard
Loading placeholder animations.

### ConfettiView.swift

**Purpose**: Celebration animation for achievements

**Features**:
- Multiple confetti shapes (circle, square, triangle, star)
- Rainbow colors
- Physics-based falling animation
- View modifier for easy use

**Usage**:
```swift
SomeView()
    .confetti(isActive: $showConfetti)
```

---

## Navigation Patterns

### Sheet Presentation
Used for:
- Create Group
- Group Detail
- Profile
- Group Settings

```swift
.sheet(item: $selectedGroup) { group in
    GroupDetailView(group: group)
}
```

### Navigation Stack
Used for:
- Main app navigation
- Achievements detail

```swift
NavigationStack {
    // Content
}
.navigationTitle("Title")
```

### Tab View
Custom tab bar in HomeView (not native TabView).

---

## Common View Patterns

### Async Data Loading
```swift
.task {
    await loadData()
}
```

### Pull to Refresh
```swift
.refreshable {
    await refreshData()
}
```

### Keyboard Handling
```swift
@FocusState private var isInputFocused: Bool

TextField("Input", text: $text)
    .focused($isInputFocused)
```

### Sheet Dismiss
```swift
@Environment(\.dismiss) private var dismiss

Button("Done") {
    dismiss()
}
```

### Confirmation Dialog
```swift
.confirmationDialog("Delete Group?", isPresented: $showDelete) {
    Button("Delete", role: .destructive) {
        // Delete action
    }
}
```
