# Firestore Data Contract

> **Single source of truth for iOS and Android codebases.**
> All field names are case-sensitive and must match exactly as documented.
> Last updated: 2026-03-05

---

## Collection: `users/{userId}`

Document ID = Firebase Auth UID.

| Field | Type | Required | Default | Constraints |
|-------|------|----------|---------|-------------|
| `displayName` | string | yes | — | 1-50 chars |
| `email` | string | no | `null` | — |
| `joinedGroupIds` | array\<string\> | yes | `[]` | Array of group document IDs |
| `favoriteGroupIds` | array\<string\> | yes | `[]` | Array of group document IDs |
| `createdAt` | timestamp | yes | now | — |
| `autoCheckOutMinutes` | number | yes | `60` | Timer duration in minutes |
| `discriminator` | string | yes | `"0000"` | 4-digit zero-padded (e.g. `"5363"`) |
| `usernameTag` | string | yes | — | Lowercase searchable (e.g. `"ian#5363"`) |
| `fcmToken` | string | no | `null` | Firebase Cloud Messaging token |
| `isPremium` | boolean | yes | `false` | — |
| `profileEmoji` | string | no | `null` | Custom emoji avatar (premium feature) |
| `profileColor` | string | no | `null` | Hex color string for profile accent |
| `totalXP` | number | yes | `0` | Cumulative experience points |
| `level` | number | yes | `1` | Range 1-100 |

### Subcollection: `users/{userId}/achievements/{achievementId}`

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `achievementType` | string | yes | Enum value (see Achievement Types below) |
| `earnedAt` | timestamp | yes | — |
| `userId` | string | yes | Must match parent `userId` |

### Subcollection: `users/{userId}/stats/current`

Single document with ID `"current"`.

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `totalCheckIns` | number | `0` | Lifetime check-in count |
| `earlyBirdCount` | number | `0` | Times user was first to arrive |
| `groupsCreated` | number | `0` | — |
| `groupsJoined` | number | `0` | — |
| `uniquePeopleMetCount` | number | `0` | — |
| `currentStreak` | number | `0` | Consecutive days checked in |
| `longestStreak` | number | `0` | All-time best streak |
| `lastCheckInDate` | timestamp | `null` | — |
| `uniquePeopleMet` | array\<string\> | `[]` | User IDs of people met |
| `checkedInOnSaturday` | boolean | `false` | Resets weekly for Weekend Warrior |
| `checkedInOnSunday` | boolean | `false` | Resets weekly for Weekend Warrior |
| `lastWeekendReset` | timestamp | `null` | — |
| `friendCount` | number | `0` | — |
| `totalMessagesSent` | number | `0` | — |
| `messagesToday` | number | `0` | Resets daily |
| `lastMessageDate` | timestamp | `null` | — |
| `groupsWithFirstMessage` | array\<string\> | `[]` | Group IDs where user sent first message |
| `groupCheckInCounts` | map\<string, number\> | `{}` | Key = groupId, value = check-in count |
| `habitTracker` | map\<string, object\> | `{}` | Key = groupId, value = `{ lastCheckInHour: number, consecutiveDays: number, lastCheckInDate: timestamp }` |
| `longestSessionMinutes` | number | `0` | — |
| `wasLastToLeaveCount` | number | `0` | — |
| `totalXP` | number | `0` | Mirrors user-level `totalXP` |
| `lastDailyLoginDate` | timestamp | `null` | — |

### Subcollection: `users/{userId}/friends/{friendId}`

Document ID = friend's Firebase Auth UID.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `addedAt` | timestamp | yes | now | — |
| `notifyOnArrival` | boolean | yes | `true` | Push notification when friend arrives |

> **Note:** `displayName`, `usernameTag`, `discriminator`, `isPremium`, `profileEmoji` are populated client-side via user lookup and are NOT stored in this subcollection.

### Subcollection: `users/{userId}/notificationPreferences/{groupId}`

Document ID = group document ID.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `arrivals` | boolean | yes | Notify on member arrivals |
| `departures` | boolean | yes | Notify on member departures |
| `messages` | boolean | yes | Notify on new chat messages |
| `muted` | boolean | yes | Master mute toggle |

---

## Collection: `groups/{groupId}`

| Field | Type | Required | Default | Constraints |
|-------|------|----------|---------|-------------|
| `name` | string | yes | — | 1-100 chars |
| `emoji` | string | no | `null` | Single emoji character |
| `isPublic` | boolean | yes | — | — |
| `ownerId` | string | yes | — | Firebase Auth UID of creator |
| `memberIds` | array\<string\> | yes | — | Array of Firebase Auth UIDs |
| `boundary` | array\<object\> | yes | — | 3-100 points, each `{ latitude: number, longitude: number }` |
| `centerLatitude` | number | yes | — | -90 to 90 |
| `centerLongitude` | number | yes | — | -180 to 180 |
| `presenceDisplayMode` | string | yes | `"names"` | `"count"` or `"names"` |
| `createdAt` | timestamp | yes | now | — |
| `inviteCode` | string | no | `null` | 6 chars from charset `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` |
| `groupColor` | string | no | `"blue"` | Enum: `"blue"`, `"green"`, `"red"`, `"orange"`, `"purple"`, `"pink"`, `"teal"`, `"yellow"`, `"gold"`, `"indigo"`, `"mint"`, `"lavender"`, `"coral"`, `"slate"` |

### Subcollection: `groups/{groupId}/messages/{messageId}`

Messages are **immutable** (no updates allowed).

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `groupId` | string | yes | Must match parent groupId |
| `senderId` | string | yes | Must match authenticated user |
| `senderName` | string | yes | 1-50 chars |
| `senderIsPremium` | boolean | no | — |
| `text` | string | yes | 1-500 chars |
| `createdAt` | timestamp | yes | — |

**Limits:**
- Max 100 messages per group (oldest pruned on write)
- 7-day TTL (messages older than 7 days are cleaned up)
- 2-second rate limit per sender

### Subcollection: `groups/{groupId}/daily_first_arrival/{dateId}`

Document ID format: `"YYYY-MM-DD"`. Created via Firestore transaction (first write wins). **Immutable** once created -- no updates or deletes allowed.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `userId` | string | yes | UID of the first person to arrive that day |

---

## Collection: `presence/{groupId}/members/{memberId}`

Document ID = Firebase Auth UID.

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `userId` | string | yes | — | Must match authenticated user |
| `groupId` | string | yes | — | Must match parent path `groupId` |
| `isPresent` | boolean | yes | — | — |
| `isManual` | boolean | yes | `false` | Manual vs. geofence-triggered |
| `lastUpdated` | timestamp | yes | now | — |
| `expiresAt` | timestamp | no | `null` | Auto-checkout time (set on check-in, cleared on check-out) |
| `displayName` | string | no | `null` | Snapshot of user's display name |
| `isPremium` | boolean | no | `null` | Snapshot of user's premium status |
| `profileEmoji` | string | no | `null` | Snapshot of user's emoji avatar |
| `level` | number | no | `null` | Snapshot of user's level |

---

## Collection: `friendRequests/{requestId}`

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `senderId` | string | yes | Firebase Auth UID |
| `receiverId` | string | yes | Firebase Auth UID |
| `senderName` | string | yes | 1-50 chars |
| `senderTag` | string | yes | 1-60 chars (e.g. `"ian#5363"`) |
| `status` | string | yes | `"pending"`, `"accepted"`, or `"declined"`. Created as `"pending"`. |
| `createdAt` | timestamp | yes | — |

---

## Collection: `counters/{counterId}`

Used for sequential discriminator generation via Firestore transactions.

| Document ID | Field | Type | Description |
|-------------|-------|------|-------------|
| `"userDiscriminator"` | `value` | number | Atomically incremented; wraps at 10000 |

---

## Collection: `reports/{reportId}`

| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `reporterId` | string | yes | Firebase Auth UID of reporter |
| `reportedUserId` | string | yes | Firebase Auth UID of reported user |
| `reportedDisplayName` | string | yes | Snapshot of reported user's name |
| `reason` | string | yes | Enum: `"inappropriate_name"`, `"harassment_or_bullying"`, `"spam"`, `"inappropriate_messages"`, `"other"` |
| `context` | string | yes | Enum: `"presence"`, `"chat"`, `"friend_request"`, `"friend_list"` |
| `details` | string | no | Free-text from reporter |
| `groupId` | string | no | Group where issue occurred |
| `messageId` | string | no | Specific message ID (if reporting a chat message) |
| `messageText` | string | no | Snapshot of the message text |
| `status` | string | yes | `"pending"`, `"reviewed"`, `"resolved"`, or `"dismissed"` |
| `createdAt` | timestamp | yes | — |

---

## Security Rules Summary

| Collection | Read | Create | Update | Delete |
|------------|------|--------|--------|--------|
| `users/{userId}` | Any authenticated user | Owner only (`userId` matches auth UID) | Owner only | Owner only |
| `users/{userId}/achievements/*` | Any authenticated user | Owner only (must set `userId` to own UID) | Owner only | Owner only |
| `users/{userId}/stats/*` | Any authenticated user | Owner only | Owner only | Owner only |
| `users/{userId}/friends/{friendId}` | Owner only | Owner OR the friend themselves (friendId == auth UID) | Owner only | Owner only |
| `users/{userId}/notificationPreferences/*` | Owner only | Owner only (all 4 bool fields required) | Owner only (all 4 bool fields required) | Owner only |
| `friendRequests/{requestId}` | Sender or receiver | Sender only (status must be `"pending"`) | Receiver only (cannot change sender/receiver) | Sender or receiver |
| `groups/{groupId}` | Any authenticated user | Creator (must be owner and member) | Owner (full), members (memberIds only), public joiners, invite-code joiners | Owner only |
| `groups/{groupId}/messages/*` | Group members | Group members (senderId must match auth UID) | **Never** (immutable) | Sender only |
| `groups/{groupId}/daily_first_arrival/*` | Group members | Group members (userId must match auth UID) | **Never** (immutable) | **Never** |
| `presence/{groupId}/members/{memberId}` | Any authenticated user | Owner only (userId must match, isPresent and isManual must be bool) | Owner only (same validations) | Owner only |
| `counters/{counterId}` | Any authenticated user | Any authenticated user | Any authenticated user | **Never** |
| `reports/{reportId}` | Reporter can read their own reports only | Authenticated user (must be reporter, status must be `"pending"`) | **Never** | **Never** |
| Everything else | **Denied** | **Denied** | **Denied** | **Denied** |

---

## Firestore Indexes

Index definitions are in `firestore.indexes.json`. Currently no composite indexes are explicitly defined -- the queries used rely on single-field indexes which Firestore creates automatically. If you add queries that combine multiple `where` clauses with `orderBy` on different fields, you will need to add composite index definitions.

---

## Key Queries

Both platforms must support these queries:

### User Queries
```
// Fetch user by ID
db.collection("users").document(userId)

// Exact username tag search
db.collection("users")
  .whereField("usernameTag", isEqualTo: lowercaseTag)
  .limit(to: 1)

// Username prefix search
db.collection("users")
  .whereField("usernameTag", isGreaterThanOrEqualTo: lowercaseQuery)
  .whereField("usernameTag", isLessThan: lowercaseQuery + "\u{f8ff}")
  .limit(to: 20)

// Fetch user achievements (ordered by date)
db.collection("users").document(userId)
  .collection("achievements")
  .orderBy("earnedAt", descending: true)

// Fetch user stats
db.collection("users").document(userId)
  .collection("stats").document("current")
```

### Group Queries
```
// Fetch groups where user is a member
db.collection("groups")
  .whereField("memberIds", arrayContains: userId)

// Fetch public groups
db.collection("groups")
  .whereField("isPublic", isEqualTo: true)
  .limit(to: 50)

// Find group by invite code
db.collection("groups")
  .whereField("inviteCode", isEqualTo: code)
  .limit(to: 1)

// Fetch groups owned by user (used during account deletion)
db.collection("groups")
  .whereField("ownerId", isEqualTo: userId)
```

### Presence Queries
```
// Fetch present members in a group
db.collection("presence").document(groupId)
  .collection("members")
  .whereField("isPresent", isEqualTo: true)

// Real-time listener for presence
db.collection("presence").document(groupId)
  .collection("members")
  .whereField("isPresent", isEqualTo: true)
  .addSnapshotListener(...)
```

### Message Queries
```
// Real-time listener for messages (newest N)
db.collection("groups").document(groupId)
  .collection("messages")
  .orderBy("createdAt", descending: false)
  .limitToLast(100)
  .addSnapshotListener(...)

// Cleanup old messages
db.collection("groups").document(groupId)
  .collection("messages")
  .whereField("createdAt", isLessThan: cutoffTimestamp)

// Unread count since a date
db.collection("groups").document(groupId)
  .collection("messages")
  .whereField("createdAt", isGreaterThan: sinceTimestamp)
```

### Friend Request Queries
```
// Listen for pending incoming requests
db.collection("friendRequests")
  .whereField("receiverId", isEqualTo: userId)
  .whereField("status", isEqualTo: "pending")
  .addSnapshotListener(...)

// Listen for pending sent requests
db.collection("friendRequests")
  .whereField("senderId", isEqualTo: userId)
  .whereField("status", isEqualTo: "pending")
  .addSnapshotListener(...)

// Check for recent reports (spam prevention)
db.collection("reports")
  .whereField("reporterId", isEqualTo: reporterId)
  .whereField("reportedUserId", isEqualTo: reportedUserId)
  .whereField("createdAt", isGreaterThan: twentyFourHoursAgo)
  .limit(to: 1)
```

### Counter Queries
```
// Atomic discriminator increment (must use transaction)
db.runTransaction {
  let doc = transaction.getDocument(db.collection("counters").document("userDiscriminator"))
  let current = doc.data["value"] as Int ?? 0
  transaction.setData(["value": current + 1], forDocument: counterRef)
  return current  // Returns value before increment
}
```

---

## Achievement Type Enum Values

These are the string values stored in `achievementType`:

| Category | Values |
|----------|--------|
| Check-Ins | `first_check_in`, `ten_check_ins`, `fifty_check_ins`, `hundred_check_ins` |
| Early Bird | `early_bird`, `early_bird_bronze`, `early_bird_silver`, `early_bird_gold` |
| Groups | `group_creator`, `community_builder`, `social_hub`, `triple_builder`, `homebody`, `loyal_member`, `landlord` |
| Explorer | `explorer`, `adventurer`, `globetrotter` |
| Social | `social_butterfly`, `party_starter`, `connector` |
| Streaks | `week_warrior`, `dedicated`, `unstoppable`, `on_a_roll`, `creature_of_habit` |
| Special | `night_owl`, `weekend_warrior`, `early_riser`, `late_night_owl`, `last_one_standing`, `marathon_session` |
| Friends | `first_friend`, `friend_collector`, `popular_kid`, `crew_up` |
| Chat | `chatterbox`, `conversation_starter`, `prolific_messenger` |
| Seasonal | `midnight_crew`, `holiday_spirit`, `new_year_check_in` |

---

## Cross-Platform Notes

1. **Field names are case-sensitive.** `displayName` is not the same as `DisplayName` or `display_name`. Use the exact casing shown in this document.

2. **Timestamps use Firestore's `Timestamp` type**, not ISO 8601 strings or Unix epoch numbers. On iOS this maps to `Date` via Codable; on Android use `Timestamp` or `@ServerTimestamp`.

3. **Arrays use `FieldValue.arrayUnion()` and `FieldValue.arrayRemove()`** for atomic add/remove operations. Never read-modify-write arrays manually -- use these atomic operations to avoid race conditions.

4. **Document IDs** are auto-generated except where noted:
   - `users/{userId}` -- ID is Firebase Auth UID
   - `presence/{groupId}/members/{memberId}` -- memberId is Firebase Auth UID
   - `users/{userId}/friends/{friendId}` -- friendId is the friend's Firebase Auth UID
   - `users/{userId}/stats/current` -- always `"current"`
   - `users/{userId}/notificationPreferences/{groupId}` -- ID is the group document ID
   - `groups/{groupId}/daily_first_arrival/{dateId}` -- format `"YYYY-MM-DD"`
   - `counters/userDiscriminator` -- fixed document ID

5. **Merge writes:** Use `setData(..., merge: true)` (iOS) / `set(..., SetOptions.merge())` (Android) for partial updates to avoid overwriting unrelated fields.

6. **Batch writes** are used for friend acceptance (creating entries in both users' friend subcollections atomically).

7. **Transactions** are used for:
   - Sequential discriminator generation (counter increment)
   - Daily first arrival claims (first-write-wins semantics)

8. **The `reports` collection** allows the reporter to read back their own reports (used for the 24-hour duplicate-report spam check). All other reads are denied. Reports cannot be updated or deleted by users. Admin review should be done via the Firebase Console or a server-side admin tool using the Firebase Admin SDK.
