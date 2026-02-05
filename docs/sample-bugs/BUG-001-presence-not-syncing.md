# BUG-001: [Presence] User presence not visible to other group members

## Environment
- **Device**: iPhone 17 Pro (Physical)
- **iOS Version**: 18.2
- **App Version**: 1.0.0 (build 42)
- **Account Type**: Apple Sign-In
- **Network**: WiFi (Strong signal)

## Severity
- [x] P1 - High (major feature broken)

## Description
After checking into a group, other members in the same group do not see the user's presence. The check-in appears successful locally (green indicator, haptic feedback), but presence does not propagate to other devices.

## Steps to Reproduce
1. User A opens the app and navigates to "Test Group"
2. User A taps "Check In" button
3. User A sees green check mark and "You're here" indicator
4. User B opens the app and navigates to "Test Group"
5. User B does NOT see User A in the "Who's Here" list
6. Wait 60 seconds, pull to refresh - still not visible

## Expected Behavior
User B should see User A in the "Who's Here" list within 5 seconds of User A checking in.

## Actual Behavior
User A's presence is never visible to User B, even after:
- Waiting 5 minutes
- Pull-to-refresh
- Force closing and reopening app
- User A checking out and back in

## Frequency
- [x] Often (>50%) - Occurs approximately 60% of check-ins

## Evidence

### Network Trace (User A - Check-In Write)
```
Operation: write
Collection: presences
Document: user123_group456
Status: success
Duration: 234ms

Write Data:
  userId: user123
  groupId: group456
  checkedInAt: 2026-01-15T10:30:00Z
  isManual: true
```

### Network Trace (User B - Presence Query)
```
Operation: query
Collection: presences
Filter: groupId == group456
Status: success
Duration: 156ms
Result Count: 0  // Empty - User A's presence not returned
```

### Analytics Events (User A)
```
Event: check_in
Timestamp: 2026-01-15T10:30:00Z
Parameters:
  group_id: group456
  is_manual: true
```

## Root Cause Analysis
The Firestore write succeeds on User A's device but the document may not be immediately available for queries by other users. Possible causes:
1. Firestore security rules blocking read access to presences collection
2. Missing composite index for the presence query
3. Eventual consistency delay (unlikely to persist >60s)
4. Client-side cache returning stale empty result

## Workaround
User B can:
1. Wait 2-3 minutes for Firestore consistency
2. Navigate away from group and back
3. Force close app and reopen

## Suggested Fix
1. Verify Firestore security rules allow group members to read all presences in their groups
2. Add real-time snapshot listener instead of one-time fetch for presence data
3. Implement presence refresh on group view `onAppear`
4. Add composite index on `presences` collection for `groupId` + `checkedInAt`
