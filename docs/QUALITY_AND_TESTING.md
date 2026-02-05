# Quality & Testing Documentation

## Testing Strategy

### Test Pyramid

```
           /\
          /  \     Manual / Regression Tests
         /----\    - 45-check regression checklist
        /      \   - Critical user journey validation
       /--------\  Integration Tests
      /          \ - Service interactions
     /------------\- Firebase integration
    /              \ Unit Tests
   /----------------\- Models, utilities, services
  /                  \- Business logic validation
```

### Test Coverage Areas

| Area | Focus | Approach |
|------|-------|----------|
| Models | Data integrity, Codable conformance | Unit tests |
| Services | Business logic, state management | Unit tests |
| Analytics | Event tracking accuracy | Dashboard validation |
| Network | Request/response logging | Network inspector |
| Device Matrix | Cross-device compatibility | Test matrix tracker |
| Auth | Edge cases, token lifecycle | JWT analysis + tests |
| Resilience | Failure handling | Failure injection |
| Regression | Full app functionality | 45-check checklist |

## In-App Testing Tools

### Analytics Dashboard
Access via 5 taps on version number in Profile view.

**Tabs:**
- **Events** - Real-time analytics event log with filtering
- **Counts** - Aggregated event counts (session + all-time)
- **Network** - Request/response inspector with timing
- **Devices** - Test matrix tracker with coverage analysis
- **Checks** - 45-item regression test checklist

**Additional Tools (via menu):**
- **Failure Injection** - Simulate network/auth/Firestore failures

### Network Inspector
Logs all Firebase operations with:
- Operation type (read/write/query/auth)
- Duration in milliseconds
- Success/failure status
- Request metadata
- Slow request detection (>500ms warning, >2000ms critical)

### Test Matrix Tracker
Records device/OS configurations tested:
- Physical vs simulator detection
- Screen category classification (compact/regular/large/tablet)
- OS version tracking
- Coverage gap recommendations
- Test session recording

### Regression Checklist
45 manual tests across 8 categories:
- Authentication (5 tests)
- Groups (8 tests)
- Location & Presence (10 tests)
- Chat (5 tests)
- Achievements (5 tests)
- Analytics (5 tests)
- Offline (4 tests)
- Watch App (3 tests)

### Failure Injection
7 simulation modes for resilience testing:
- Normal (no injection)
- No Network
- Slow Network (3s delay)
- Intermittent Failures (50%)
- Auth Always Fails
- Firestore Always Fails
- Request Timeout (10s)

## Tools Used

### Development
- **Xcode 16+** - Primary IDE
- **Swift 5.9+** - Language version
- **SwiftUI** - UI framework (iOS 17+)

### Testing
- **XCTest** - Unit tests for models, services, utilities
- **Custom Analytics Dashboard** - In-app event validation
- **Network Inspector** - Built-in request/response logging
- **Failure Injection System** - Resilience testing
- **JWT Analyzer** - Token decoding and session analysis

### Backend
- **Firebase Auth** - Anonymous + Apple Sign-In
- **Firebase Firestore** - Document database
- **Firebase Cloud Messaging** - Push notifications

### Quality Assurance
- **Test Matrix Tracker** - Device/OS coverage tracking
- **Regression Checklist** - Manual test execution tracking
- **Analytics Validation** - Event count verification

## Known Limitations

### Platform Limitations
1. **Geofence Limit**: iOS limits to 20 monitored regions
   - Mitigation: Monitor nearest 20 groups only
   - Impact: Users with 20+ groups may miss auto check-ins

2. **Background Location**: Requires "Always" permission for auto check-in
   - Mitigation: Graceful degradation with "When In Use" permission
   - Impact: Manual check-in still works without Always permission

3. **Watch Independence**: Watch requires iPhone connection for data
   - Mitigation: Cache last known state on watch

4. **Message Retention**: Messages auto-delete after 7 days
   - Mitigation: Documented behavior, no user-facing workaround needed

### Testing Limitations
1. **Location Testing**: Cannot fully test geofencing in simulator
   - Mitigation: Use Xcode location simulation + real device testing

2. **Push Notifications**: Cannot test in simulator
   - Mitigation: Real device testing required for notification flows

3. **Background States**: Hard to automate background/foreground transitions
   - Mitigation: Manual testing via regression checklist

4. **Multi-User Scenarios**: Require multiple devices or accounts
   - Mitigation: Use anonymous auth for easy account switching

## Bug Severity Definitions

| Severity | Definition | Response Time |
|----------|------------|---------------|
| P0 - Critical | App crash, data loss, security issue | Immediate |
| P1 - High | Major feature broken, no workaround | Within 24 hours |
| P2 - Medium | Feature impaired, workaround exists | Within 1 week |
| P3 - Low | Minor issue, cosmetic | Backlog |

## Bug Lifecycle

1. **New** - Bug identified via testing, analytics, or user report
2. **Triaged** - Assigned severity and category
3. **In Progress** - Fix being developed
4. **In Review** - Code review / PR
5. **Verified** - Fix confirmed
6. **Closed** - Merged and deployed

## Unit Test Files

| File | Tests | Coverage |
|------|-------|----------|
| `AnalyticsTests.swift` | Analytics events, service, discrepancies | Models + Service |
| `NetworkInspectorTests.swift` | Network requests, filtering, statistics | Models + Service |
| `TestMatrixTests.swift` | Device info, sessions, coverage | Models + Service |
| `RegressionChecklistTests.swift` | Checks, runs, categories, service | Models + Service |
| `AuthEdgeCaseTests.swift` | JWT decoding, token analysis, auth errors | Utilities + Models |
| `FailureInjectionTests.swift` | Failure modes, injection, logging | Models + Service |
