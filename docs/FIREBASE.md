# Firebase Configuration & Security Rules

## Project Configuration

**Project ID**: whostherefb
**Bundle ID**: com.IanMcCurry.WhosThereios

### Services Used

- **Firebase Authentication**: Anonymous sign-in
- **Cloud Firestore**: Main database
- **Firebase Analytics**: Usage tracking (optional)

### Configuration Files

- `GoogleService-Info.plist` - Firebase SDK configuration (do not commit to public repos)

---

## Firestore Data Structure

### Collections Overview

```
firestore/
├── users/
│   └── {userId}/
│       ├── [user document]
│       ├── achievements/
│       │   └── {achievementType}/
│       └── stats/
│           └── current
├── groups/
│   └── {groupId}/
│       ├── [group document]
│       ├── messages/
│       │   └── {messageId}/
│       └── daily_first_arrival/
│           └── {dateId}/
└── presence/
    └── {groupId}/
        └── members/
            └── {userId}/
```

### Document Schemas

#### users/{userId}
```json
{
  "displayName": "string (1-50 chars)",
  "email": "string? (optional)",
  "joinedGroupIds": ["string array"],
  "createdAt": "timestamp",
  "autoCheckOutMinutes": "number (default 60)"
}
```

#### users/{userId}/achievements/{achievementType}
```json
{
  "achievementType": "string (enum value)",
  "earnedAt": "timestamp",
  "userId": "string"
}
```

#### users/{userId}/stats/current
```json
{
  "totalCheckIns": "number",
  "uniqueGroupsVisited": "number",
  "groupsCreated": "number",
  "groupsJoined": "number",
  "currentStreak": "number",
  "longestStreak": "number",
  "lastCheckInDate": "timestamp?",
  "uniquePeopleMet": "number",
  "maxGroupSize": "number",
  "hasWeekendSaturday": "boolean",
  "hasWeekendSunday": "boolean",
  "weekendWeekNumber": "number?"
}
```

#### groups/{groupId}
```json
{
  "name": "string (1-100 chars)",
  "emoji": "string? (optional)",
  "isPublic": "boolean",
  "ownerId": "string (user ID)",
  "memberIds": ["string array of user IDs"],
  "boundary": [
    {"latitude": "number", "longitude": "number"}
  ],
  "centerLatitude": "number",
  "centerLongitude": "number",
  "presenceDisplayMode": "string ('count' or 'names')",
  "createdAt": "timestamp",
  "inviteCode": "string? (6 chars, private groups only)",
  "groupColor": "string? (color enum value)"
}
```

#### groups/{groupId}/messages/{messageId}
```json
{
  "text": "string (1-500 chars)",
  "senderId": "string (user ID)",
  "senderName": "string",
  "groupId": "string",
  "createdAt": "timestamp"
}
```

#### groups/{groupId}/daily_first_arrival/{dateId}
```json
{
  "userId": "string",
  "timestamp": "timestamp"
}
```
*dateId format: "YYYY-MM-DD"*

#### presence/{groupId}/members/{userId}
```json
{
  "userId": "string",
  "groupId": "string",
  "isPresent": "boolean",
  "isManual": "boolean",
  "lastUpdated": "timestamp",
  "displayName": "string"
}
```

---

## Security Rules

**File**: `firestore.rules`

### Overview

The security rules enforce:
1. Users can only access their own user data
2. Group access is based on membership and visibility
3. Presence can only be modified by the user it belongs to
4. Messages require group membership
5. All writes are validated

### Complete Rules

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    // ============================================
    // HELPER FUNCTIONS
    // ============================================

    function isAuthenticated() {
      return request.auth != null;
    }

    function userId() {
      return request.auth.uid;
    }

    function isOwner(ownerId) {
      return isAuthenticated() && userId() == ownerId;
    }

    function isValidString(field, minLen, maxLen) {
      return field is string && field.size() >= minLen && field.size() <= maxLen;
    }

    function isValidLatitude(lat) {
      return lat is number && lat >= -90 && lat <= 90;
    }

    function isValidLongitude(lng) {
      return lng is number && lng >= -180 && lng <= 180;
    }

    // ============================================
    // USERS COLLECTION
    // ============================================

    match /users/{userDocId} {
      allow read: if isOwner(userDocId);

      allow create: if isOwner(userDocId)
        && isValidString(request.resource.data.displayName, 1, 50);

      allow update: if isOwner(userDocId)
        && isValidString(request.resource.data.displayName, 1, 50);

      allow delete: if isOwner(userDocId);

      // Achievements subcollection
      match /achievements/{achievementId} {
        allow read: if isOwner(userDocId);
        allow create, update: if isOwner(userDocId)
          && request.resource.data.userId == userId();
        allow delete: if isOwner(userDocId);
      }

      // Stats subcollection
      match /stats/{statId} {
        allow read: if isOwner(userDocId);
        allow create, update: if isOwner(userDocId);
        allow delete: if isOwner(userDocId);
      }
    }

    // ============================================
    // GROUPS COLLECTION
    // ============================================

    match /groups/{groupId} {
      function isMember() {
        return isAuthenticated() && userId() in resource.data.memberIds;
      }

      function isGroupOwner() {
        return isAuthenticated() && userId() == resource.data.ownerId;
      }

      function willBeMember() {
        return isAuthenticated() && userId() in request.resource.data.memberIds;
      }

      function isValidGroupData() {
        let data = request.resource.data;
        return isValidString(data.name, 1, 100)
          && data.isPublic is bool
          && data.boundary is list
          && data.boundary.size() >= 3
          && data.boundary.size() <= 100
          && isValidLatitude(data.centerLatitude)
          && isValidLongitude(data.centerLongitude);
      }

      // Read: public groups or member
      allow read: if isAuthenticated()
        && (resource.data.isPublic == true || isMember());

      // Create: set self as owner and member
      allow create: if isAuthenticated()
        && request.resource.data.ownerId == userId()
        && userId() in request.resource.data.memberIds
        && isValidGroupData();

      // Update: owner or member (limited) or joining public
      allow update: if isAuthenticated()
        && (
          (isGroupOwner() && request.resource.data.ownerId == resource.data.ownerId && isValidGroupData())
          ||
          (isMember()
            && request.resource.data.name == resource.data.name
            && request.resource.data.isPublic == resource.data.isPublic
            && request.resource.data.ownerId == resource.data.ownerId
            && request.resource.data.boundary == resource.data.boundary
            && request.resource.data.centerLatitude == resource.data.centerLatitude
            && request.resource.data.centerLongitude == resource.data.centerLongitude)
          ||
          (resource.data.isPublic == true
            && willBeMember()
            && request.resource.data.name == resource.data.name
            && request.resource.data.isPublic == resource.data.isPublic
            && request.resource.data.ownerId == resource.data.ownerId
            && request.resource.data.boundary == resource.data.boundary)
        );

      // Delete: owner only
      allow delete: if isGroupOwner();

      // Messages subcollection
      match /messages/{messageId} {
        function isGroupMember() {
          let groupDoc = get(/databases/$(database)/documents/groups/$(groupId));
          return isAuthenticated() && userId() in groupDoc.data.memberIds;
        }

        function isValidMessage() {
          let data = request.resource.data;
          return isValidString(data.text, 1, 500)
            && data.senderId == userId()
            && isValidString(data.senderName, 1, 50)
            && data.groupId == groupId
            && data.createdAt is timestamp;
        }

        allow read: if isGroupMember();
        allow create: if isGroupMember() && isValidMessage();
        allow delete: if isAuthenticated() && resource.data.senderId == userId();
        allow update: if false;
      }

      // Daily first arrival (for Early Bird achievement)
      match /daily_first_arrival/{dateId} {
        function isGroupMemberForArrival() {
          let groupDoc = get(/databases/$(database)/documents/groups/$(groupId));
          return isAuthenticated() && userId() in groupDoc.data.memberIds;
        }

        allow read: if isGroupMemberForArrival();
        allow create: if isGroupMemberForArrival()
          && request.resource.data.userId == userId();
        allow update, delete: if false;
      }
    }

    // ============================================
    // PRESENCE COLLECTION
    // ============================================

    match /presence/{groupId} {
      allow read: if isAuthenticated();

      match /members/{memberId} {
        allow read: if isAuthenticated();

        allow create, update: if isOwner(memberId)
          && request.resource.data.userId == userId()
          && request.resource.data.groupId == groupId
          && request.resource.data.isPresent is bool
          && request.resource.data.isManual is bool;

        allow delete: if isOwner(memberId);
      }
    }

    // ============================================
    // DEFAULT: DENY ALL
    // ============================================

    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Deployment

### Deploy Rules

```bash
cd /path/to/WhosThere
firebase deploy --only firestore:rules
```

### Alternative: Firebase Console

1. Go to https://console.firebase.google.com
2. Select project "whostherefb"
3. Navigate to Firestore Database → Rules
4. Paste rules and click "Publish"

---

## Indexes

Firestore automatically creates indexes for most queries. Custom composite indexes may be needed for:

- Querying groups by `isPublic` + `createdAt`
- Querying messages by `groupId` + `createdAt`

If you see index errors in the console, click the provided link to create the index.

---

## Data Retention

### Automatic Cleanup

- **Messages**: Deleted after 7 days (client-side cleanup)
- **Stale Presence**: Auto-checkout after 10 hours of inactivity

### Manual Cleanup

Consider periodic Cloud Functions for:
- Orphaned presence records
- Inactive users
- Empty groups

---

## Security Best Practices

1. **Never expose API keys** in public repositories
2. **Validate all input** before writing to Firestore
3. **Use transactions** for atomic operations (e.g., Early Bird)
4. **Rate limit** client operations where appropriate
5. **Monitor usage** in Firebase Console
6. **Test rules** using Firebase Rules Playground
