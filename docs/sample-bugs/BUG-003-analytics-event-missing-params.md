# BUG-003: [Analytics] check_out event missing duration_minutes parameter

## Environment
- **Device**: Simulator (iPhone 17 Pro)
- **iOS Version**: 18.2
- **App Version**: 1.0.0 (build 42)
- **Account Type**: Anonymous
- **Network**: WiFi

## Severity
- [x] P3 - Low (minor/cosmetic)

## Description
The `check_out` analytics event should include a `duration_minutes` parameter indicating how long the user was checked in. This parameter is missing from all check_out events, making it impossible to analyze average session durations from analytics data.

## Steps to Reproduce
1. Open the Analytics Dashboard (5 taps on version in Profile)
2. Navigate to the Events tab
3. Check into a group
4. Wait 5 minutes
5. Check out of the group
6. Find the `check_out` event in the Events list
7. Expand the event parameters
8. Observe: No `duration_minutes` parameter is present

## Expected Behavior
The check_out event should include duration:
```
Event: check_out
Parameters:
  group_id: abc123
  is_manual: true
  duration_minutes: 5
```

## Actual Behavior
The check_out event is missing the duration:
```
Event: check_out
Parameters:
  group_id: abc123
  is_manual: true
  // duration_minutes is missing
```

## Frequency
- [x] Always (100%)

## Evidence

### Analytics Dashboard Screenshot
Events tab showing check_out event with only `group_id` and `is_manual` parameters. No `duration_minutes` parameter visible.

### Code Reference
`PresenceService.swift` - The checkout method calls `analyticsService.trackCheckOut()` before calculating the duration of the check-in session.

## Root Cause Analysis
The analytics tracking call in `PresenceService.checkOut()` does not compute or pass the duration. The check-in timestamp is available from the presence record, but it is not used to calculate elapsed time before logging the event.

## Workaround
Duration can be manually calculated by correlating `check_in` and `check_out` event timestamps in the Analytics Dashboard, but this is tedious and error-prone.

## Suggested Fix
In `PresenceService`, before removing the presence record:
1. Read the `checkedInAt` timestamp from the current presence
2. Calculate `Date().timeIntervalSince(checkedInAt) / 60`
3. Pass the result as `durationMinutes` to the analytics tracking call

```swift
// In PresenceService.checkOut():
let checkInTime = currentPresence.checkedInAt
let durationMinutes = Int(Date().timeIntervalSince(checkInTime) / 60)

analyticsService.trackCheckOut(
    groupId: groupId,
    isManual: true,
    durationMinutes: durationMinutes
)
```
