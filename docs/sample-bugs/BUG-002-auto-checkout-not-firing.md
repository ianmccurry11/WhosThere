# BUG-002: [Presence] Auto-checkout timer doesn't fire when app is backgrounded

## Environment
- **Device**: iPhone SE 3rd gen (Physical)
- **iOS Version**: 18.0
- **App Version**: 1.0.0 (build 42)
- **Account Type**: Anonymous
- **Network**: WiFi

## Severity
- [x] P2 - Medium (feature impaired)

## Description
When a user checks into a group and then backgrounds the app, the auto-checkout timer (default 60 minutes) does not execute. The user remains "checked in" indefinitely until stale presence cleanup (10 hours) or manual checkout.

## Steps to Reproduce
1. Open the app and navigate to a group with 60-minute auto-checkout configured
2. Tap "Check In"
3. Immediately press the Home button to background the app
4. Wait 65 minutes
5. Open the app again
6. Observe: Still shows as checked in

## Expected Behavior
User should be automatically checked out after 60 minutes, regardless of whether the app is in the foreground or background.

## Actual Behavior
Timer is suspended when the app enters background. The timer only resumes counting when the app returns to the foreground. After 65 minutes in background, the timer has only elapsed ~1 second of its 60-minute countdown.

## Frequency
- [x] Always (100%)

## Evidence

### Console Log (Before Background)
```
[PresenceService] Check-in successful for group: group789
[PresenceService] Starting auto-checkout timer: 3600 seconds
[PresenceService] Timer task initiated via Task.sleep
```

### Console Log (After 65 min, App Foregrounded)
```
[AppDelegate] App entered foreground
[PresenceService] Checking presence states...
[PresenceService] Active presence found: group789 (checked in 65 min ago)
[PresenceService] Auto-checkout timer still pending (never fired)
```

### Analytics Events
```
Event: check_in
Timestamp: 2026-01-20T09:00:00Z
Parameters:
  group_id: group789
  is_manual: true

// No check_out event after 65 minutes
```

## Root Cause Analysis
The auto-checkout timer uses `Task.sleep()` which is suspended by iOS when the app enters the background state. iOS does not allow arbitrary background execution for standard apps, so the sleep duration is paused until the app returns to the foreground.

This is a known iOS platform behavior, not a code bug per se, but the feature does not work as users would expect.

## Workaround
Users must:
1. Manually check out before leaving
2. Rely on geofence exit detection (requires "Always" location permission)
3. Accept that stale presence cleanup will remove them after 10 hours

## Suggested Fix
Several approaches, in order of recommendation:
1. **On-foreground check**: When app enters foreground, compare `checkedInAt + autoCheckoutDuration` against current time. If exceeded, immediately perform checkout. This is the simplest fix.
2. **Background Tasks API**: Schedule a `BGAppRefreshTask` for the checkout time. Not guaranteed by iOS but better than nothing.
3. **Server-side cleanup**: Use Firebase Cloud Functions with a scheduled trigger to clean up expired presences.
4. **Document the limitation**: Update the UI to indicate that auto-checkout requires the app to be in the foreground or "Always" location permission enabled.
