# Firebase Configuration & Security Rules

## Project Configuration

**Project ID**: whostherefb
**iOS Bundle ID**: com.IanMcCurry.WhosThereios
**Android Package Name**: com.whosthere.android

### Services Used

- **Firebase Authentication**: Anonymous sign-in, Sign in with Apple, Sign in with Google (Android)
- **Cloud Firestore**: Main database (shared between iOS and Android)
- **Firebase Cloud Messaging (FCM)**: Push notifications
- **Firebase App Check**: Bot/abuse prevention
- **Firebase Analytics**: Usage tracking (optional, currently disabled)

### Configuration Files

| Platform | File | Notes |
|----------|------|-------|
| iOS | `GoogleService-Info.plist` | Add to Xcode project; never commit |
| Android | `google-services.json` | Place in `app/`; never commit |

Both files come from the **same Firebase project** (`whostherefb`). In the Firebase Console, iOS and Android apps are registered as separate entries under the same project.

### Android Setup Steps

1. Firebase Console → Project Settings → Add app → Android
2. Package name: `com.whosthere.android`
3. Register debug SHA-1 fingerprint (from `./gradlew signingReport`)
4. Download `google-services.json` → place in `WhosThereAndroid/app/`
5. Enable **Google Sign-In** in Firebase Auth → Sign-in method
6. After building the Android app, add its SHA-256 fingerprint to `public/.well-known/assetlinks.json` for App Links deep link verification

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

**Canonical file**: `firestore.rules` (project root) — this is what gets deployed. Do not maintain a separate copy here.

### Overview

The security rules enforce:
1. Users can only access their own user data (achievements, stats, notification prefs)
2. Group reads are open to any authenticated user; writes are restricted by role
3. Any authenticated user can join a public group or a private group with an invite code
4. Presence can only be written by the user it belongs to
5. Messages require group membership and are immutable after creation
6. Reports can be created by any authenticated user but cannot be read except by the reporter
7. All writes are validated server-side (field types, string lengths, coordinate ranges)

> See `firestore.rules` for the complete current rules.
> See `FIRESTORE_SCHEMA.md` for the security rules summary table.

### Deploying Rules

```bash
firebase deploy --only firestore:rules
```

> **Note**: Rules are platform-agnostic. The same rules govern both iOS and Android clients since Firebase Auth UIDs are consistent across platforms.

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
