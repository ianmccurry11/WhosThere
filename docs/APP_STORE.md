# App Store Submission Guide

This document covers everything needed for App Store submission and ongoing compliance.

---

## Pre-Submission Checklist

### Required Items

- [ ] **App Icon**: All required sizes in Assets.xcassets
- [ ] **App Name**: "Who's There" (verify availability)
- [ ] **Bundle ID**: com.IanMcCurry.WhosThereios
- [ ] **Privacy Policy URL**: Required for location apps
- [ ] **Screenshots**: All required device sizes
- [ ] **App Description**: Store listing copy
- [ ] **Keywords**: For App Store search
- [ ] **Category**: Social Networking or Lifestyle
- [ ] **Age Rating**: 4+ (no objectionable content)
- [ ] **Apple Developer Account**: Active membership

### Technical Requirements

- [ ] No crashes on launch
- [ ] No placeholder content
- [ ] All features functional
- [ ] Proper error handling
- [ ] Network error states handled
- [ ] Location permission properly requested
- [ ] Delete account functionality (Apple requirement)

---

## Privacy & Data Handling

### Data Collected

| Data Type | Purpose | Linked to User |
|-----------|---------|----------------|
| Location (When In Use) | Check-in functionality | Yes |
| Location (Always) | Automatic geofence check-ins | Yes |
| User ID | Authentication | Yes |
| Display Name | Profile | Yes |
| Usage Data | Analytics | No |

### Privacy Policy Requirements

Your privacy policy must address:

1. **What data is collected**
   - Location data (for presence detection)
   - Display name (user-provided)
   - Group membership data
   - Check-in history
   - Chat messages

2. **How data is used**
   - To show user presence at locations
   - To enable group communication
   - To track achievements

3. **Data sharing**
   - Display name shared with group members
   - Presence status shared with group members
   - Exact location is NOT shared (only presence at defined areas)

4. **Data retention**
   - Messages deleted after 7 days
   - Presence auto-clears after 10 hours
   - Account data retained until deletion requested

5. **User rights**
   - Access their data
   - Delete their account
   - Export their data (if applicable)

### Location Usage Descriptions

Add these to Info.plist:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Who's There uses your location to show when you're at your favorite spots and to let friends know you're there.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Who's There can automatically check you in when you arrive at locations, even when the app is closed. Your exact location is never shared - only whether you're at a defined spot.</string>

<key>NSLocationAlwaysUsageDescription</key>
<string>Who's There can automatically check you in when you arrive at locations. Your exact location is never shared.</string>
```

---

## App Store Connect Setup

### App Information

**Name**: Who's There
**Subtitle**: See who's at your spots
**Category**: Social Networking (Primary), Lifestyle (Secondary)

### Description

```
See who's at your favorite spots before you go.

Who's There lets you create location-based groups for the places you frequent - basketball courts, coffee shops, parks, or anywhere your friends gather. Check in when you arrive and see who else is there.

KEY FEATURES:

• Create Custom Spots
Draw boundaries around any location to create a group. Share it with friends or make it public for anyone to join.

• Real-Time Presence
See who's currently at a location. Choose to show just a count ("3 people here") or names.

• Automatic Check-ins
With location permission, the app can automatically detect when you arrive and leave.

• Group Chat
Message other people at the same location in real-time.

• Achievements
Earn badges for checking in regularly, being the first to arrive, and more.

• Apple Watch Support
Quick check-in and presence viewing from your wrist.

PRIVACY FIRST:
We never share your exact location. Only your presence at defined spots is visible to group members.

Perfect for:
- Pickup basketball games
- Regular coffee meetups
- Coworking spaces
- Neighborhood parks
- Any recurring hangout spot

Stop wondering if anyone's at the court. Know who's there before you go.
```

### Keywords

```
location,presence,check-in,friends,basketball,meetup,hangout,nearby,social,group,court,park
```

### What's New (Version Notes)

```
Initial release featuring:
- Create and join location groups
- Real-time presence sharing
- Group messaging
- Achievement system
- Apple Watch companion app
```

---

## Screenshots Requirements

### iPhone Screenshots (Required)

**6.7" Display** (iPhone 15 Pro Max): 1290 x 2796 px
**6.5" Display** (iPhone 14 Plus): 1284 x 2778 px
**5.5" Display** (iPhone 8 Plus): 1242 x 2208 px

### iPad Screenshots (If Universal)

**12.9" Display**: 2048 x 2732 px
**11" Display**: 1668 x 2388 px

### Screenshot Suggestions

1. **Map view** showing group boundaries with presence indicators
2. **List view** of groups with check-in status
3. **Group detail** view with members present
4. **Create group** view with boundary drawing
5. **Achievements** screen showing earned badges
6. **Apple Watch** app (use Watch frame)

---

## Apple Review Guidelines Compliance

### 4.2 Minimum Functionality
✅ App provides real utility (presence sharing)
✅ Not a simple website wrapper
✅ Features work as described

### 4.3 Spam
✅ Unique functionality
✅ Not a copy of existing app

### 5.1 Privacy
✅ Privacy policy provided
✅ Location usage clearly explained
✅ Data collection disclosed
✅ User data protected

### 5.1.1 Data Collection and Storage
✅ Collect only necessary data
✅ Secure transmission (HTTPS/Firebase)
✅ Clear purpose for each data type

### 5.1.2 Data Use and Sharing
✅ Don't sell user data
✅ Only share with user consent (group membership)
✅ Third-party sharing disclosed (Firebase)

### 5.1.5 Account Sign-In
✅ Anonymous sign-in option (no account required)
⚠️ Consider Sign in with Apple for future versions

### 5.1.4 Account Deletion
🔴 **REQUIRED**: Must implement account deletion feature

Implementation needed:
```swift
func deleteAccount() async {
    // 1. Delete all user data from Firestore
    // 2. Delete Firebase Auth account
    // 3. Clear local data
    // 4. Sign out
}
```

### 4.2.3 Background Location
✅ Clear reason for background location (geofencing)
✅ Location indicator shown when in use
✅ Works without "Always" permission (manual check-in)

---

## TestFlight Beta Testing

### Internal Testing
- Add up to 100 internal testers
- Builds available immediately after processing

### External Testing
- Up to 10,000 testers
- Requires Beta App Review (usually 24-48 hours)
- Provide test instructions

### Test Instructions Template

```
Welcome to the Who's There beta!

To test the app:
1. Allow location permission (either "While Using" or "Always")
2. Create a new group by tapping the + button
3. Draw a boundary around a location
4. Check in to the group
5. Try the chat feature
6. View your achievements

Known issues:
- [List any known bugs]

Please report issues to: [email/feedback link]
```

---

## Common Rejection Reasons & Solutions

### 1. Guideline 5.1.1 - Data Collection
**Issue**: Unclear why location is needed
**Solution**: Ensure Info.plist strings clearly explain purpose

### 2. Guideline 4.2 - Minimum Functionality
**Issue**: App doesn't work without account
**Solution**: Anonymous auth allows immediate use

### 3. Guideline 2.1 - Performance: App Completeness
**Issue**: Placeholder content, crashes
**Solution**: Thorough testing before submission

### 4. Guideline 5.1.1 - Account Deletion
**Issue**: No way to delete account/data
**Solution**: Implement delete account feature in settings

### 5. Guideline 4.0 - Design: Location Permission
**Issue**: Asking for location before explaining why
**Solution**: Show onboarding explaining location use first

---

## Post-Submission

### Response Time
- Typical review: 24-48 hours
- May be longer during busy periods (holidays, WWDC)

### If Rejected
1. Read rejection reason carefully
2. Address specific concerns
3. Reply in Resolution Center with explanation
4. Resubmit updated build

### After Approval
1. Set release date (immediate or scheduled)
2. Monitor crash reports in Xcode Organizer
3. Respond to user reviews
4. Plan update cycle

---

## Maintenance Checklist

### Regular Updates
- [ ] Fix reported crashes
- [ ] Address user feedback
- [ ] Update for new iOS versions
- [ ] Refresh screenshots for new devices
- [ ] Review analytics for usage patterns

### Annual Requirements
- [ ] Renew Apple Developer membership ($99/year)
- [ ] Update privacy policy if data practices change
- [ ] Ensure app runs on latest iOS version
