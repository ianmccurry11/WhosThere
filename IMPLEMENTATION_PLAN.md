# Who's There - Quality & Testing Enhancement Plan

## Executive Summary

This plan transforms the Who's There iOS app into a showcase of professional mobile QA practices. Each phase delivers a GitHub-committable feature with validation checkpoints.

**Total Phases:** 8
**Estimated Commits:** 12-15
**Key Deliverables:** Analytics Dashboard, Network Inspection Docs, Test Matrix, Regression Checklist, Auth Edge-Case Tests, Failure Injection System, Quality README, Bug Report Templates

---

## Pre-Implementation Checklist

Before starting, verify:
- [ ] Xcode project builds successfully
- [ ] App runs on simulator
- [ ] Firebase connection works
- [ ] Git repository is clean (`git status`)

**Verification Command:**
```bash
xcodebuild -scheme WhosThereios -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

---

## PHASE 1: Analytics Validation Dashboard
**Commit Message:** `feat: Add analytics validation dashboard with event tracking`

### 1.1 Objectives
- Add Firebase Analytics event tracking throughout the app
- Create admin dashboard view to display raw events and aggregated counts
- Enable "Validated analytics instrumentation and data accuracy across sessions"

### 1.2 Implementation Steps

#### Step 1.2.1: Create AnalyticsService
**File:** `WhosThereios/Services/AnalyticsService.swift`

**Events to Track:**
| Event Name | Parameters | Trigger Point |
|------------|------------|---------------|
| `app_launch` | `launch_type` (cold/warm) | AppDelegate.didFinishLaunching |
| `sign_in_attempted` | `method` (anonymous/apple) | AuthService.signIn* |
| `sign_in_success` | `method`, `is_new_user` | AuthService success path |
| `sign_in_failure` | `method`, `error_code` | AuthService error path |
| `group_created` | `has_boundary`, `member_count` | FirestoreService.createGroup |
| `group_joined` | `join_method` (invite/public) | FirestoreService.joinGroup |
| `group_left` | `was_owner` | FirestoreService.leaveGroup |
| `check_in` | `is_manual`, `group_id` | PresenceService.checkIn |
| `check_out` | `is_manual`, `duration_minutes` | PresenceService.checkOut |
| `achievement_unlocked` | `achievement_type`, `points` | AchievementService.unlock |
| `message_sent` | `group_id`, `message_length` | ChatService.sendMessage |
| `screen_view` | `screen_name` | Each major view .onAppear |
| `error_occurred` | `error_type`, `context` | All error handlers |

**Service Architecture:**
```swift
@MainActor
final class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    // In-memory event log for dashboard (last 100 events)
    @Published var recentEvents: [AnalyticsEvent] = []
    @Published var eventCounts: [String: Int] = [:]

    // Event tracking with local buffer
    func track(_ event: AnalyticsEvent)

    // Dashboard data
    func getEventsSince(_ date: Date) -> [AnalyticsEvent]
    func getAggregatedCounts() -> [String: Int]
    func getDiscrepancies() -> [AnalyticsDiscrepancy]
}
```

#### Step 1.2.2: Create AnalyticsEvent Model
**File:** `WhosThereios/Models/AnalyticsEvent.swift`

```swift
struct AnalyticsEvent: Identifiable, Codable {
    let id: UUID
    let name: String
    let parameters: [String: String]
    let timestamp: Date
    let sessionId: String
}

struct AnalyticsDiscrepancy: Identifiable {
    let id: UUID
    let eventName: String
    let localCount: Int
    let expectedCount: Int // From Firestore counters
    let description: String
}
```

#### Step 1.2.3: Create Analytics Dashboard View
**File:** `WhosThereios/Views/Admin/AnalyticsDashboardView.swift`

**UI Components:**
1. **Raw Events Tab**: Scrollable list of recent events with timestamp, name, parameters
2. **Aggregated Counts Tab**: Bar chart or list showing event totals by type
3. **Discrepancies Tab**: Comparison between local tracking and Firestore counters
4. **Session Info**: Current session ID, app version, device info
5. **Export Button**: Copy event log to clipboard for debugging

#### Step 1.2.4: Instrument Existing Services
Add tracking calls to:
- `AuthService.swift` - sign in/out events
- `FirestoreService.swift` - group CRUD events
- `PresenceService.swift` - check-in/out events
- `AchievementService.swift` - unlock events
- `ChatService.swift` - message events

#### Step 1.2.5: Add Dashboard Access Point
- Add hidden admin access (e.g., tap version number 5 times in ProfileView)
- Or add debug build flag to show Admin tab

### 1.3 Validation Checkpoints

**Checkpoint 1.3.1: Build Verification**
```bash
xcodebuild -scheme WhosThereios -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```
- [ ] Project compiles without errors
- [ ] No new warnings introduced

**Checkpoint 1.3.2: Runtime Verification**
- [ ] App launches successfully
- [ ] `app_launch` event appears in dashboard
- [ ] Sign in triggers `sign_in_*` events
- [ ] Creating group triggers `group_created` event
- [ ] Check-in triggers `check_in` event

**Checkpoint 1.3.3: Data Accuracy**
- [ ] Event timestamps are accurate
- [ ] Parameters contain expected values
- [ ] Session IDs persist across views
- [ ] Event counts match manual action count

### 1.4 Files Changed/Created
- [ ] `WhosThereios/Services/AnalyticsService.swift` (NEW)
- [ ] `WhosThereios/Models/AnalyticsEvent.swift` (NEW)
- [ ] `WhosThereios/Views/Admin/AnalyticsDashboardView.swift` (NEW)
- [ ] `WhosThereios/Services/AuthService.swift` (MODIFIED)
- [ ] `WhosThereios/Services/FirestoreService.swift` (MODIFIED)
- [ ] `WhosThereios/Services/PresenceService.swift` (MODIFIED)
- [ ] `WhosThereios/Services/AchievementService.swift` (MODIFIED)
- [ ] `WhosThereios/Services/ChatService.swift` (MODIFIED)
- [ ] `WhosThereios/Views/Profile/ProfileView.swift` (MODIFIED - admin access)

### 1.5 Git Commit
```bash
git add WhosThereios/Services/AnalyticsService.swift \
        WhosThereios/Models/AnalyticsEvent.swift \
        WhosThereios/Views/Admin/AnalyticsDashboardView.swift \
        WhosThereios/Services/AuthService.swift \
        WhosThereios/Services/FirestoreService.swift \
        WhosThereios/Services/PresenceService.swift \
        WhosThereios/Services/AchievementService.swift \
        WhosThereios/Services/ChatService.swift \
        WhosThereios/Views/Profile/ProfileView.swift

git commit -m "feat: Add analytics validation dashboard with event tracking

- Add AnalyticsService for comprehensive event tracking
- Create AnalyticsEvent model with session support
- Build admin dashboard with raw events, counts, discrepancies
- Instrument auth, group, presence, achievement, chat services
- Add hidden admin access via profile tap gesture

Events tracked: app_launch, sign_in_*, group_*, check_in/out,
achievement_unlocked, message_sent, screen_view, error_occurred"
```

---

## PHASE 2: Network Inspection Workflow
**Commit Message:** `docs: Add network inspection workflow with HTTP request documentation`

### 2.1 Objectives
- Document HTTP request inspection methodology
- Capture and document auth requests, event payloads, session identifiers
- Create reference screenshots and README
- Demonstrate "Skilled in HTTP request inspection tools"

### 2.2 Implementation Steps

#### Step 2.2.1: Create Network Inspection Documentation
**File:** `docs/NETWORK_INSPECTION.md`

**Contents:**
1. **Tool Setup**
   - Proxyman configuration for iOS simulator
   - Charles Proxy alternative setup
   - SSL certificate installation on device/simulator

2. **Request Categories to Capture**
   - Firebase Auth requests (`identitytoolkit.googleapis.com`)
   - Firestore requests (`firestore.googleapis.com`)
   - FCM token registration
   - Analytics event batches

3. **Sample Request Documentation**
   - Auth request structure (anonymized)
   - Session token format
   - Event payload structure

#### Step 2.2.2: Create Network Request Logger (Debug Builds)
**File:** `WhosThereios/Utilities/NetworkLogger.swift`

```swift
#if DEBUG
@MainActor
final class NetworkLogger: ObservableObject {
    static let shared = NetworkLogger()

    @Published var requests: [NetworkRequest] = []

    struct NetworkRequest: Identifiable {
        let id: UUID
        let timestamp: Date
        let url: String
        let method: String
        let statusCode: Int?
        let duration: TimeInterval
        let requestBody: String?
        let responseBody: String?
    }

    func log(_ request: NetworkRequest)
    func export() -> String // JSON export
}
#endif
```

#### Step 2.2.3: Create Screenshots Directory
**Directory:** `docs/network-inspection/screenshots/`

**Required Screenshots:**
1. `proxyman-setup.png` - Proxyman with iOS simulator connected
2. `auth-request.png` - Anonymous auth request/response
3. `firestore-write.png` - Group creation request
4. `event-batch.png` - Analytics event payload
5. `session-token.png` - JWT token structure (decoded, anonymized)

#### Step 2.2.4: Document JWT Token Analysis
**File:** `docs/network-inspection/JWT_ANALYSIS.md`

- How to decode Firebase ID tokens
- Token structure (header, payload, signature)
- Key claims to inspect (exp, iat, sub, firebase)
- Token refresh behavior

### 2.3 Validation Checkpoints

**Checkpoint 2.3.1: Documentation Complete**
- [ ] `NETWORK_INSPECTION.md` contains all sections
- [ ] Screenshots are captured and referenced
- [ ] JWT analysis document is complete

**Checkpoint 2.3.2: Network Logger Works**
- [ ] Debug build includes NetworkLogger
- [ ] Requests are captured during app usage
- [ ] Export produces valid JSON

**Checkpoint 2.3.3: External Tool Verification**
- [ ] Proxyman can intercept Firebase requests
- [ ] SSL pinning doesn't block inspection (Firebase doesn't pin)
- [ ] Request/response bodies are readable

### 2.4 Files Changed/Created
- [ ] `docs/NETWORK_INSPECTION.md` (NEW)
- [ ] `docs/network-inspection/screenshots/` (NEW DIRECTORY)
- [ ] `docs/network-inspection/JWT_ANALYSIS.md` (NEW)
- [ ] `WhosThereios/Utilities/NetworkLogger.swift` (NEW - DEBUG only)

### 2.5 Git Commit
```bash
git add docs/NETWORK_INSPECTION.md \
        docs/network-inspection/ \
        WhosThereios/Utilities/NetworkLogger.swift

git commit -m "docs: Add network inspection workflow with HTTP request documentation

- Create comprehensive network inspection guide
- Document Proxyman/Charles setup for iOS
- Add screenshots of captured requests
- Include JWT token analysis documentation
- Add debug-only NetworkLogger utility

Demonstrates HTTP inspection skills for:
- Firebase Auth requests
- Firestore operations
- Analytics event payloads
- Session token analysis"
```

---

## PHASE 3: Emulator & Device Test Matrix
**Commit Message:** `docs: Add comprehensive device/emulator test matrix`

### 3.1 Objectives
- Document testing across iOS simulator versions
- Document real device testing
- Cover background/foreground state transitions
- Document location permission edge cases

### 3.2 Implementation Steps

#### Step 3.2.1: Create Test Matrix Document
**File:** `docs/TEST_MATRIX.md`

**Matrix Dimensions:**

| Dimension | Values to Test |
|-----------|----------------|
| **Device Type** | Simulator, Physical Device |
| **iOS Version** | 17.0, 17.2, 17.4, 18.0 |
| **Device Model** | iPhone 15 Pro, iPhone SE 3rd gen, iPhone 12 mini |
| **App State** | Fresh install, Upgrade, Reinstall |
| **Location Permission** | Not Determined, When In Use, Always, Denied |
| **Network State** | WiFi, Cellular, Offline, Slow (Network Link Conditioner) |
| **Background State** | Foreground, Background, Suspended, Terminated |

#### Step 3.2.2: Create Test Scenarios
**File:** `docs/TEST_SCENARIOS.md`

**Scenario Categories:**
1. **First Launch Scenarios**
   - Fresh install flow
   - Permission request handling
   - Onboarding completion

2. **Location Permission Scenarios**
   - Grant "When In Use" → Verify no auto check-in
   - Grant "Always" → Verify auto check-in works
   - Deny → Verify graceful degradation
   - Revoke in Settings → Verify app handles removal

3. **Background/Foreground Scenarios**
   - Enter geofence while backgrounded
   - Exit geofence while backgrounded
   - App killed → Geofence trigger → App launch
   - Background refresh timing

4. **Network Scenarios**
   - Offline during check-in attempt
   - Network loss during Firestore write
   - Slow network (2G simulation)

#### Step 3.2.3: Create Test Execution Tracker
**File:** `docs/test-execution/TEST_RUN_TEMPLATE.md`

```markdown
# Test Run: [Date] - [Tester Name]

## Environment
- Device:
- iOS Version:
- App Version:
- Build:

## Test Results

| Test Case | Status | Notes |
|-----------|--------|-------|
| TC-001: Fresh Install | PASS/FAIL | |
| TC-002: Location When In Use | PASS/FAIL | |
| ... | | |

## Issues Found
1. ...

## Screenshots
- [Link to screenshots]
```

#### Step 3.2.4: Document Location Edge Cases
**File:** `docs/LOCATION_EDGE_CASES.md`

1. User at boundary edge (GPS drift)
2. Multiple overlapping geofences
3. Geofence limit exceeded (>20 groups)
4. Location services disabled system-wide
5. Airplane mode behavior
6. Significant location change vs continuous location

### 3.3 Validation Checkpoints

**Checkpoint 3.3.1: Matrix Completeness**
- [ ] All device types documented
- [ ] All iOS versions listed with support status
- [ ] All permission states covered
- [ ] All app states covered

**Checkpoint 3.3.2: Scenario Coverage**
- [ ] Happy path scenarios documented
- [ ] Edge cases documented
- [ ] Error scenarios documented
- [ ] Recovery scenarios documented

**Checkpoint 3.3.3: Execution Feasibility**
- [ ] Test cases are executable
- [ ] Expected results are clear
- [ ] Pass/fail criteria defined

### 3.4 Files Changed/Created
- [ ] `docs/TEST_MATRIX.md` (NEW)
- [ ] `docs/TEST_SCENARIOS.md` (NEW)
- [ ] `docs/test-execution/TEST_RUN_TEMPLATE.md` (NEW)
- [ ] `docs/LOCATION_EDGE_CASES.md` (NEW)

### 3.5 Git Commit
```bash
git add docs/TEST_MATRIX.md \
        docs/TEST_SCENARIOS.md \
        docs/test-execution/ \
        docs/LOCATION_EDGE_CASES.md

git commit -m "docs: Add comprehensive device/emulator test matrix

- Create device/iOS version test matrix
- Document location permission edge cases
- Add background/foreground state test scenarios
- Include test execution template
- Cover network condition testing

Matrix covers:
- iOS 17.0-18.0 across device types
- All location permission states
- Background/foreground transitions
- Network conditions (offline, slow, cellular)"
```

---

## PHASE 4: Regression Test Checklist
**Commit Message:** `docs: Add regression test checklist for release validation`

### 4.1 Objectives
- Create manual regression test checklist
- Cover critical user flows
- Ensure release quality gates
- Demonstrate process maturity

### 4.2 Implementation Steps

#### Step 4.2.1: Create Regression Checklist
**File:** `docs/REGRESSION_CHECKLIST.md`

**Checklist Categories:**

```markdown
# Regression Test Checklist

## Pre-Release Checklist

### 1. Authentication (5 tests)
- [ ] REG-AUTH-001: Anonymous sign-in works on fresh install
- [ ] REG-AUTH-002: Apple Sign-In completes successfully
- [ ] REG-AUTH-003: Sign out clears all local data
- [ ] REG-AUTH-004: App handles auth token expiration gracefully
- [ ] REG-AUTH-005: Re-authentication preserves user data

### 2. Groups (8 tests)
- [ ] REG-GRP-001: Create group with default boundary
- [ ] REG-GRP-002: Create group with custom boundary
- [ ] REG-GRP-003: Join group via invite code
- [ ] REG-GRP-004: Join public group from search
- [ ] REG-GRP-005: Leave group as member
- [ ] REG-GRP-006: Delete group as owner
- [ ] REG-GRP-007: Edit group settings
- [ ] REG-GRP-008: Edit group boundary

### 3. Location & Presence (10 tests)
- [ ] REG-LOC-001: Manual check-in works
- [ ] REG-LOC-002: Manual check-out works
- [ ] REG-LOC-003: Auto check-in on geofence entry (Always permission)
- [ ] REG-LOC-004: Auto check-out on geofence exit
- [ ] REG-LOC-005: Auto-checkout timer works (60 min default)
- [ ] REG-LOC-006: Stale presence cleanup (10 hours)
- [ ] REG-LOC-007: Manual override prevents auto check-out
- [ ] REG-LOC-008: Location permission request flow
- [ ] REG-LOC-009: Presence shows for other members
- [ ] REG-LOC-010: Throttling prevents rapid updates (30 sec)

### 4. Chat (5 tests)
- [ ] REG-CHAT-001: Send message in group
- [ ] REG-CHAT-002: Receive message from other user
- [ ] REG-CHAT-003: Rate limiting enforced (2 sec)
- [ ] REG-CHAT-004: Message character limit enforced
- [ ] REG-CHAT-005: Messages load on group open

### 5. Achievements (5 tests)
- [ ] REG-ACH-001: First check-in achievement unlocks
- [ ] REG-ACH-002: Streak tracking increments
- [ ] REG-ACH-003: Early bird achievement (before 7 AM)
- [ ] REG-ACH-004: Achievement notification shows
- [ ] REG-ACH-005: Achievement points accumulate

### 6. Analytics Accuracy (5 tests)
- [ ] REG-ANA-001: App launch event fires
- [ ] REG-ANA-002: Sign-in events tracked correctly
- [ ] REG-ANA-003: Check-in events include correct parameters
- [ ] REG-ANA-004: Error events captured
- [ ] REG-ANA-005: Dashboard counts match actions

### 7. Offline Behavior (4 tests)
- [ ] REG-OFF-001: App launches offline
- [ ] REG-OFF-002: Offline indicator shows
- [ ] REG-OFF-003: Operations queue when offline
- [ ] REG-OFF-004: Sync completes when online

### 8. Watch App (3 tests)
- [ ] REG-WCH-001: Watch connects to phone
- [ ] REG-WCH-002: Presence syncs to watch
- [ ] REG-WCH-003: Check-in from watch works
```

#### Step 4.2.2: Create Smoke Test Subset
**File:** `docs/SMOKE_TEST.md`

Quick 15-minute validation for CI/CD:
```markdown
# Smoke Test Checklist (15 min)

Essential functionality only:
- [ ] App launches without crash
- [ ] Sign-in completes
- [ ] Groups list loads
- [ ] Can check into a group
- [ ] Can check out of a group
- [ ] Can send a chat message
- [ ] Push notification received
```

#### Step 4.2.3: Create Release Readiness Criteria
**File:** `docs/RELEASE_CRITERIA.md`

```markdown
# Release Readiness Criteria

## Must Pass (Blockers)
- [ ] All smoke tests pass
- [ ] No P0/P1 bugs open
- [ ] Crash rate < 0.1%
- [ ] Analytics validation complete

## Should Pass
- [ ] 95%+ regression tests pass
- [ ] No P2 bugs in critical flows
- [ ] Performance metrics within threshold

## Documentation Required
- [ ] Release notes prepared
- [ ] Known issues documented
- [ ] Rollback plan ready
```

### 4.3 Validation Checkpoints

**Checkpoint 4.3.1: Checklist Completeness**
- [ ] All critical flows have test cases
- [ ] Test IDs are unique and trackable
- [ ] Pass/fail criteria are clear

**Checkpoint 4.3.2: Practicality**
- [ ] Tests can be completed in reasonable time
- [ ] Prerequisites are documented
- [ ] Expected results are specified

### 4.4 Files Changed/Created
- [ ] `docs/REGRESSION_CHECKLIST.md` (NEW)
- [ ] `docs/SMOKE_TEST.md` (NEW)
- [ ] `docs/RELEASE_CRITERIA.md` (NEW)

### 4.5 Git Commit
```bash
git add docs/REGRESSION_CHECKLIST.md \
        docs/SMOKE_TEST.md \
        docs/RELEASE_CRITERIA.md

git commit -m "docs: Add regression test checklist for release validation

- Create comprehensive 40-test regression checklist
- Add 15-minute smoke test for quick validation
- Define release readiness criteria
- Organize by feature area with unique test IDs

Covers: Authentication, Groups, Location/Presence,
Chat, Achievements, Analytics, Offline, Watch App"
```

---

## PHASE 5: Auth Edge-Case Testing
**Commit Message:** `feat: Add authentication edge-case handling and tests`

### 5.1 Objectives
- Handle anonymous → logged-in upgrade path
- Handle expired session scenarios
- Handle token refresh failures
- Decode and analyze JWT tokens
- Demonstrate authentication security testing skills

### 5.2 Implementation Steps

#### Step 5.2.1: Enhance AuthService with Edge-Case Handling
**File:** `WhosThereios/Services/AuthService.swift` (MODIFY)

**New Capabilities:**
```swift
extension AuthService {
    // Token analysis
    func getTokenClaims() async throws -> [String: Any]
    func isTokenExpiringSoon(withinMinutes: Int = 5) -> Bool
    func getTokenExpirationDate() -> Date?

    // Session management
    func refreshTokenIfNeeded() async throws
    func handleExpiredSession() async

    // Upgrade flow
    func upgradeAnonymousAccount(to credential: AuthCredential) async throws
    func linkAppleCredential() async throws

    // Edge-case recovery
    func recoverFromAuthError(_ error: Error) async -> AuthRecoveryAction
}

enum AuthRecoveryAction {
    case retry
    case reauthenticate
    case clearAndRestart
    case showError(String)
}
```

#### Step 5.2.2: Create JWT Token Analyzer Utility
**File:** `WhosThereios/Utilities/JWTAnalyzer.swift`

```swift
struct JWTAnalyzer {
    struct TokenInfo {
        let header: [String: Any]
        let payload: [String: Any]
        let expirationDate: Date?
        let issuedAt: Date?
        let subject: String?
        let isExpired: Bool
        let timeUntilExpiration: TimeInterval
    }

    static func decode(_ token: String) -> TokenInfo?
    static func validateStructure(_ token: String) -> Bool
}
```

#### Step 5.2.3: Add Auth Edge-Case Tests
**File:** `WhosThereiosTests/AuthEdgeCaseTests.swift` (NEW)

```swift
final class AuthEdgeCaseTests: XCTestCase {

    // Token Tests
    func testTokenExpirationDetection()
    func testTokenClaimsExtraction()
    func testExpiredTokenIdentification()
    func testTokenRefreshTiming()

    // Session Tests
    func testExpiredSessionRecovery()
    func testInvalidTokenHandling()
    func testConcurrentAuthRequests()

    // Upgrade Tests
    func testAnonymousToAppleUpgrade()
    func testUpgradePreservesData()
    func testUpgradeFailureRecovery()

    // Error Recovery Tests
    func testNetworkErrorRetry()
    func testInvalidCredentialHandling()
    func testRateLimitHandling()
}
```

#### Step 5.2.4: Document Auth Flows
**File:** `docs/AUTH_EDGE_CASES.md`

```markdown
# Authentication Edge Cases

## Token Lifecycle
1. Token issued on sign-in (valid ~1 hour)
2. Firebase SDK auto-refreshes before expiration
3. If refresh fails → re-authentication required

## Tested Scenarios

### Scenario 1: Expired Token
**Trigger:** Force token expiration in simulator
**Expected:** App detects expiration, triggers refresh
**Recovery:** If refresh fails, prompt re-auth

### Scenario 2: Anonymous → Apple Upgrade
**Trigger:** Sign in with Apple while anonymous
**Expected:** Account linked, data preserved
**Recovery:** If link fails, offer retry or new account

### Scenario 3: Concurrent Auth Requests
**Trigger:** Multiple sign-in attempts simultaneously
**Expected:** Only one completes, others cancelled
**Recovery:** Prevent duplicate auth states

### Scenario 4: Network Failure During Auth
**Trigger:** Disable network during sign-in
**Expected:** Clear error message, retry option
**Recovery:** Queue request when network returns
```

### 5.3 Validation Checkpoints

**Checkpoint 5.3.1: Build Verification**
```bash
xcodebuild test -scheme WhosThereios -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```
- [ ] All new tests pass
- [ ] No regressions in existing tests

**Checkpoint 5.3.2: Edge-Case Verification**
- [ ] Token expiration detected correctly
- [ ] Expired sessions trigger re-auth flow
- [ ] Anonymous upgrade preserves user data
- [ ] Network errors show retry option

**Checkpoint 5.3.3: JWT Analysis**
- [ ] Token can be decoded
- [ ] Claims are accessible
- [ ] Expiration date extracted correctly

### 5.4 Files Changed/Created
- [ ] `WhosThereios/Services/AuthService.swift` (MODIFIED)
- [ ] `WhosThereios/Utilities/JWTAnalyzer.swift` (NEW)
- [ ] `WhosThereiosTests/AuthEdgeCaseTests.swift` (NEW)
- [ ] `docs/AUTH_EDGE_CASES.md` (NEW)

### 5.5 Git Commit
```bash
git add WhosThereios/Services/AuthService.swift \
        WhosThereios/Utilities/JWTAnalyzer.swift \
        WhosThereiosTests/AuthEdgeCaseTests.swift \
        docs/AUTH_EDGE_CASES.md

git commit -m "feat: Add authentication edge-case handling and tests

- Enhance AuthService with token analysis and refresh
- Add JWT decoder for session analysis
- Implement anonymous → Apple upgrade flow
- Add comprehensive auth edge-case tests
- Document authentication scenarios

Aligns with: 'decode JWT tokens for authentication
and session analysis' requirement"
```

---

## PHASE 6: Failure Injection System
**Commit Message:** `feat: Add failure injection system for resilience testing`

### 6.1 Objectives
- Simulate no network conditions
- Simulate delayed responses
- Simulate partial failures
- Document expected vs actual behavior

### 6.2 Implementation Steps

#### Step 6.2.1: Create Failure Injection Service
**File:** `WhosThereios/Services/FailureInjectionService.swift`

```swift
#if DEBUG
@MainActor
final class FailureInjectionService: ObservableObject {
    static let shared = FailureInjectionService()

    enum FailureMode: String, CaseIterable {
        case none = "Normal"
        case noNetwork = "No Network"
        case slowNetwork = "Slow Network (3s delay)"
        case intermittent = "Intermittent Failures (50%)"
        case authFailure = "Auth Always Fails"
        case firestoreFailure = "Firestore Always Fails"
        case timeout = "Request Timeout (10s)"
    }

    @Published var currentMode: FailureMode = .none
    @Published var failureLog: [FailureEvent] = []

    struct FailureEvent: Identifiable {
        let id: UUID
        let timestamp: Date
        let operation: String
        let injectedFailure: FailureMode
        let actualBehavior: String
    }

    // Injection points
    func shouldFail(for operation: String) -> Bool
    func simulateDelay() async
    func logBehavior(_ operation: String, behavior: String)
}
#endif
```

#### Step 6.2.2: Create Debug Settings View
**File:** `WhosThereios/Views/Admin/DebugSettingsView.swift`

**Features:**
- Toggle failure modes
- View injected failure log
- Compare expected vs actual behavior
- Reset all failures
- Network condition simulation

#### Step 6.2.3: Integrate Failure Injection Points
Modify services to check failure injection:

**FirestoreService.swift:**
```swift
func createGroup(_ group: LocationGroup) async -> AppResult<String> {
    #if DEBUG
    if FailureInjectionService.shared.shouldFail(for: "createGroup") {
        return .failure(.firestoreError("Injected failure for testing"))
    }
    await FailureInjectionService.shared.simulateDelay()
    #endif

    // Normal implementation...
}
```

#### Step 6.2.4: Document Failure Scenarios
**File:** `docs/FAILURE_INJECTION.md`

```markdown
# Failure Injection Testing

## Available Failure Modes

### 1. No Network
**Simulation:** All network requests fail immediately
**Expected App Behavior:**
- Offline indicator shows
- Operations fail with "No network" error
- Retry button appears
**Actual Behavior:** [Document during testing]

### 2. Slow Network (3s delay)
**Simulation:** All requests delayed by 3 seconds
**Expected App Behavior:**
- Loading indicators show
- UI remains responsive
- Timeouts don't trigger prematurely
**Actual Behavior:** [Document during testing]

### 3. Intermittent Failures (50%)
**Simulation:** 50% of requests fail randomly
**Expected App Behavior:**
- Retry logic handles failures
- User sees occasional errors
- No data corruption
**Actual Behavior:** [Document during testing]

### 4. Auth Always Fails
**Simulation:** Authentication requests always fail
**Expected App Behavior:**
- Clear error message
- Retry option offered
- No infinite loops
**Actual Behavior:** [Document during testing]

### 5. Firestore Always Fails
**Simulation:** All Firestore operations fail
**Expected App Behavior:**
- Graceful degradation
- Cached data shown if available
- Error messaging
**Actual Behavior:** [Document during testing]

### 6. Request Timeout
**Simulation:** Requests hang for 10 seconds
**Expected App Behavior:**
- Timeout after reasonable period
- Loading state doesn't persist forever
- User can cancel
**Actual Behavior:** [Document during testing]
```

### 6.3 Validation Checkpoints

**Checkpoint 6.3.1: Build Verification**
- [ ] Debug build compiles with failure injection
- [ ] Release build excludes failure injection code
- [ ] No compiler warnings

**Checkpoint 6.3.2: Injection Verification**
- [ ] Each failure mode can be activated
- [ ] Failures are logged correctly
- [ ] Failure mode persists during session

**Checkpoint 6.3.3: App Resilience**
- [ ] App doesn't crash under any failure mode
- [ ] Error messages are user-friendly
- [ ] Recovery paths work

### 6.4 Files Changed/Created
- [ ] `WhosThereios/Services/FailureInjectionService.swift` (NEW)
- [ ] `WhosThereios/Views/Admin/DebugSettingsView.swift` (NEW)
- [ ] `WhosThereios/Services/FirestoreService.swift` (MODIFIED)
- [ ] `WhosThereios/Services/AuthService.swift` (MODIFIED)
- [ ] `docs/FAILURE_INJECTION.md` (NEW)

### 6.5 Git Commit
```bash
git add WhosThereios/Services/FailureInjectionService.swift \
        WhosThereios/Views/Admin/DebugSettingsView.swift \
        WhosThereios/Services/FirestoreService.swift \
        WhosThereios/Services/AuthService.swift \
        docs/FAILURE_INJECTION.md

git commit -m "feat: Add failure injection system for resilience testing

- Create FailureInjectionService with 6 failure modes
- Add debug settings UI for failure control
- Integrate injection points in Firestore and Auth
- Document expected vs actual behavior

Failure modes: No network, Slow network, Intermittent,
Auth failure, Firestore failure, Timeout"
```

---

## PHASE 7: Quality & Testing README
**Commit Message:** `docs: Add comprehensive quality and testing documentation`

### 7.1 Objectives
- Create single-source quality documentation
- Document testing strategy
- List tools used
- Document known limitations
- Explain bug reporting process

### 7.2 Implementation Steps

#### Step 7.2.1: Create Quality README
**File:** `docs/QUALITY_AND_TESTING.md`

```markdown
# Quality & Testing Documentation

## Testing Strategy

### Test Pyramid
```
           /\
          /  \     UI Tests (5%)
         /----\    - Critical user journeys
        /      \   - End-to-end flows
       /--------\  Integration Tests (15%)
      /          \ - Service interactions
     /------------\- Firebase integration
    /              \ Unit Tests (80%)
   /----------------\- Models, utilities
  /                  \- Business logic
```

### Test Coverage Goals
| Area | Current | Target |
|------|---------|--------|
| Models | 85% | 90% |
| Services | 40% | 70% |
| Views | 10% | 30% |

## Tools Used

### Development
- **Xcode 15+** - Primary IDE
- **Swift 5.9** - Language version
- **SwiftUI** - UI framework

### Testing
- **XCTest** - Unit and integration tests
- **XCUITest** - UI automation (planned)
- **Proxyman** - Network inspection
- **Network Link Conditioner** - Network simulation

### Quality Assurance
- **Firebase Crashlytics** - Crash reporting
- **Firebase Analytics** - Event tracking
- **Custom Analytics Dashboard** - Validation

### CI/CD
- **Xcode Cloud** - Build automation (planned)
- **GitHub Actions** - PR checks (planned)

## Known Limitations

### Platform Limitations
1. **Geofence Limit**: iOS limits to 20 monitored regions
   - Mitigation: Monitor nearest 20 groups only

2. **Background Location**: Requires "Always" permission
   - Mitigation: Graceful degradation with "When In Use"

3. **Watch Independence**: Watch requires iPhone for data
   - Mitigation: Cache last known state on watch

### Testing Limitations
1. **Location Testing**: Cannot fully test geofencing in simulator
   - Mitigation: Use location simulation + real device testing

2. **Push Notifications**: Cannot test in simulator
   - Mitigation: Real device testing required

3. **Background States**: Hard to automate
   - Mitigation: Manual testing checklist

### Known Issues
| Issue | Severity | Status | Workaround |
|-------|----------|--------|------------|
| GPS drift at boundary edges | Medium | Open | 10% radius buffer |
| Occasional delayed presence sync | Low | Open | Pull-to-refresh |

## Bug Reporting Process

### How Bugs Are Found
1. **Automated Testing**: Unit/integration test failures
2. **Manual Testing**: Regression checklist execution
3. **Analytics**: Error event monitoring
4. **Crash Reports**: Crashlytics alerts
5. **User Reports**: In-app feedback

### Bug Report Template
See `docs/BUG_REPORT_TEMPLATE.md`

### Severity Definitions
- **P0 (Critical)**: App crash, data loss, security issue
- **P1 (High)**: Major feature broken, no workaround
- **P2 (Medium)**: Feature impaired, workaround exists
- **P3 (Low)**: Minor issue, cosmetic

### Bug Lifecycle
1. **New** → Triage within 24 hours
2. **Triaged** → Assigned priority and owner
3. **In Progress** → Fix being developed
4. **In Review** → PR under review
5. **Verified** → Fix confirmed in staging
6. **Closed** → Shipped to production
```

### 7.3 Validation Checkpoints

**Checkpoint 7.3.1: Documentation Completeness**
- [ ] Testing strategy is clear
- [ ] All tools are listed
- [ ] Known limitations documented
- [ ] Bug process explained

**Checkpoint 7.3.2: Accuracy**
- [ ] Coverage numbers are realistic
- [ ] Tool versions are current
- [ ] Limitations match reality

### 7.4 Files Changed/Created
- [ ] `docs/QUALITY_AND_TESTING.md` (NEW)

### 7.5 Git Commit
```bash
git add docs/QUALITY_AND_TESTING.md

git commit -m "docs: Add comprehensive quality and testing documentation

- Document testing strategy with test pyramid
- List all development, testing, and QA tools
- Document known platform and testing limitations
- Explain bug finding and reporting process
- Include severity definitions and bug lifecycle"
```

---

## PHASE 8: Bug Report Examples
**Commit Message:** `docs: Add sample bug report templates with examples`

### 8.1 Objectives
- Create 2-3 sample bug tickets
- Include reproduction steps
- Show expected vs actual behavior
- Reference network traces
- Demonstrate professional bug reporting

### 8.2 Implementation Steps

#### Step 8.2.1: Create Bug Report Template
**File:** `docs/BUG_REPORT_TEMPLATE.md`

```markdown
# Bug Report Template

## Title
[Component] Brief description of the issue

## Environment
- **Device**: iPhone 15 Pro / Simulator
- **iOS Version**: 17.4
- **App Version**: 1.0.0 (build 42)
- **Account Type**: Anonymous / Apple Sign-In
- **Network**: WiFi / Cellular / Offline

## Severity
- [ ] P0 - Critical (crash, data loss, security)
- [ ] P1 - High (major feature broken)
- [ ] P2 - Medium (feature impaired)
- [ ] P3 - Low (minor/cosmetic)

## Description
Clear description of what went wrong.

## Steps to Reproduce
1. First step
2. Second step
3. Third step
4. Observe the bug

## Expected Behavior
What should happen.

## Actual Behavior
What actually happens.

## Frequency
- [ ] Always (100%)
- [ ] Often (>50%)
- [ ] Sometimes (<50%)
- [ ] Rare (<10%)
- [ ] Once

## Evidence
### Screenshots
[Attach screenshots]

### Network Trace
[If applicable, paste relevant network request/response]

### Logs
[Paste relevant console logs]

### Analytics Events
[Paste relevant analytics data if applicable]

## Additional Context
Any other relevant information.

## Workaround
If known, describe how to work around the issue.
```

#### Step 8.2.2: Create Sample Bug Reports
**File:** `docs/sample-bugs/BUG-001-presence-not-syncing.md`

```markdown
# BUG-001: [Presence] User presence not visible to other group members

## Environment
- **Device**: iPhone 15 Pro (Physical)
- **iOS Version**: 17.4
- **App Version**: 1.0.0 (build 42)
- **Account Type**: Apple Sign-In
- **Network**: WiFi (Strong signal)

## Severity
- [x] P1 - High (major feature broken)

## Description
After checking into a group, other members in the same group do not see the user's presence. The check-in appears successful locally (green indicator, haptic feedback), but presence doesn't propagate.

## Steps to Reproduce
1. User A opens the app and navigates to "Test Group"
2. User A taps "Check In" button
3. User A sees green check mark and "You're here" indicator
4. User B opens the app and navigates to "Test Group"
5. User B does NOT see User A in the "Who's Here" list
6. Wait 60 seconds, refresh - still not visible

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

### Screenshot
[User A's view showing "You're here" indicator]
[User B's view showing empty "Who's Here" list]

### Network Trace (User A's Check-In Request)
```
POST /v1/projects/.../databases/(default)/documents:commit
Status: 200 OK
Duration: 234ms

Request Body:
{
  "writes": [{
    "update": {
      "name": "projects/.../presences/user123_group456",
      "fields": {
        "userId": {"stringValue": "user123"},
        "groupId": {"stringValue": "group456"},
        "checkedInAt": {"timestampValue": "2024-01-15T10:30:00Z"},
        "isManual": {"booleanValue": true}
      }
    }
  }]
}

Response: {"commitTime": "2024-01-15T10:30:00.123456Z"}
```

### Firestore Query (User B)
```
GET /v1/projects/.../databases/(default)/documents/presences?where=groupId==group456
Status: 200 OK
Duration: 156ms

Response:
{
  "documents": []  // Empty - User A's presence not returned!
}
```

### Logs
```
[PresenceService] Check-in initiated for group: group456
[PresenceService] Manual check-in: true
[FirestoreService] Writing presence document: user123_group456
[FirestoreService] Write successful
[AnalyticsService] Event: check_in {group_id: group456, is_manual: true}
```

### Analytics Events
```
Event: check_in
Timestamp: 2024-01-15T10:30:00Z
Parameters:
  - group_id: group456
  - is_manual: true
  - user_id: user123
```

## Root Cause Analysis
The Firestore write succeeds locally but the document may not be immediately available for queries by other users. This could be:
1. Firestore eventual consistency delay
2. Security rules blocking read access
3. Query index missing
4. Cache invalidation issue

## Workaround
User B can:
1. Wait 2-3 minutes for consistency
2. Navigate away and back to group
3. Force close app and reopen

## Suggested Fix
1. Verify security rules allow group members to read presences
2. Add real-time listener instead of one-time fetch
3. Implement presence refresh on group view foreground
```

**File:** `docs/sample-bugs/BUG-002-auto-checkout-not-firing.md`

```markdown
# BUG-002: [Presence] Auto-checkout timer doesn't fire when app is backgrounded

## Environment
- **Device**: iPhone 12 mini (Physical)
- **iOS Version**: 17.2
- **App Version**: 1.0.0 (build 42)
- **Account Type**: Anonymous
- **Network**: WiFi

## Severity
- [x] P2 - Medium (feature impaired)

## Description
When a user checks into a group and then backgrounds the app, the auto-checkout timer (default 60 minutes) does not execute. User remains "checked in" indefinitely until stale presence cleanup (10 hours) or manual checkout.

## Steps to Reproduce
1. Check into a group with 60-minute auto-checkout
2. Background the app immediately
3. Wait 65 minutes
4. Open the app
5. Observe: Still shows as checked in

## Expected Behavior
User should be automatically checked out after 60 minutes, even if app is backgrounded.

## Actual Behavior
Timer is suspended when app backgrounds. Timer only resumes when app returns to foreground.

## Frequency
- [x] Always (100%)

## Evidence

### Logs (Before Background)
```
[PresenceService] Starting auto-checkout timer: 60 minutes
[PresenceService] Timer task initiated
```

### Logs (After 65 min, App Foregrounded)
```
[PresenceService] App foregrounded
[PresenceService] Timer still pending (never fired while backgrounded)
// No checkout log
```

## Root Cause Analysis
`Task.sleep()` is suspended when the app is backgrounded. iOS doesn't allow arbitrary background execution.

## Workaround
User must manually check out before leaving, or rely on geofence exit (requires "Always" location permission).

## Suggested Fix
Options:
1. Use Background Tasks API for deferred checkout
2. Store checkout time in UserDefaults, check on foreground
3. Use push notification scheduled via Cloud Functions
4. Accept limitation and document behavior
```

**File:** `docs/sample-bugs/BUG-003-analytics-event-missing-params.md`

```markdown
# BUG-003: [Analytics] check_in event missing duration_minutes parameter

## Environment
- **Device**: Simulator (iPhone 15 Pro)
- **iOS Version**: 17.4
- **App Version**: 1.0.0 (build 42)

## Severity
- [x] P3 - Low (minor/cosmetic)

## Description
The `check_out` event should include `duration_minutes` parameter showing how long the user was checked in. This parameter is missing from all check_out events.

## Steps to Reproduce
1. Open Analytics Dashboard
2. Check into a group
3. Wait 5 minutes
4. Check out
5. View check_out event in dashboard
6. Observe: No duration_minutes parameter

## Expected Behavior
check_out event should include:
```json
{
  "event": "check_out",
  "parameters": {
    "group_id": "abc123",
    "is_manual": true,
    "duration_minutes": 5
  }
}
```

## Actual Behavior
```json
{
  "event": "check_out",
  "parameters": {
    "group_id": "abc123",
    "is_manual": true
    // duration_minutes missing!
  }
}
```

## Frequency
- [x] Always (100%)

## Evidence

### Analytics Dashboard Screenshot
[Screenshot showing event without duration parameter]

### Code Reference
`PresenceService.swift:145` - checkout method doesn't calculate duration

## Root Cause Analysis
The checkout method tracks the event before calculating duration. Need to:
1. Calculate time since check-in
2. Include in analytics event

## Suggested Fix
```swift
func checkOut(from groupId: String) async {
    let checkInTime = currentPresences[groupId]?.checkedInAt ?? Date()
    let duration = Date().timeIntervalSince(checkInTime) / 60

    AnalyticsService.shared.track(.checkOut(
        groupId: groupId,
        isManual: true,
        durationMinutes: Int(duration)
    ))

    // Continue with checkout logic...
}
```
```

### 8.3 Validation Checkpoints

**Checkpoint 8.3.1: Template Quality**
- [ ] Template covers all necessary sections
- [ ] Severity levels are clear
- [ ] Evidence sections are comprehensive

**Checkpoint 8.3.2: Sample Bug Quality**
- [ ] Bugs are realistic to the app
- [ ] Reproduction steps are clear
- [ ] Network traces are included
- [ ] Root cause analysis is thoughtful

### 8.4 Files Changed/Created
- [ ] `docs/BUG_REPORT_TEMPLATE.md` (NEW)
- [ ] `docs/sample-bugs/BUG-001-presence-not-syncing.md` (NEW)
- [ ] `docs/sample-bugs/BUG-002-auto-checkout-not-firing.md` (NEW)
- [ ] `docs/sample-bugs/BUG-003-analytics-event-missing-params.md` (NEW)

### 8.5 Git Commit
```bash
git add docs/BUG_REPORT_TEMPLATE.md \
        docs/sample-bugs/

git commit -m "docs: Add sample bug report templates with examples

- Create comprehensive bug report template
- Add 3 realistic sample bug reports
- Include network traces and analytics references
- Demonstrate professional bug documentation

Sample bugs cover:
- P1: Presence sync failure with network trace
- P2: Background timer not firing
- P3: Missing analytics parameter"
```

---

## Post-Implementation Summary

### Final Verification Checklist

After completing all phases:

- [ ] All code compiles without errors
- [ ] App runs on simulator
- [ ] App runs on physical device
- [ ] All new tests pass
- [ ] No regressions in existing functionality
- [ ] All documentation is accurate
- [ ] Git history is clean (no merge conflicts)

### Files Created (Summary)

**Services (4 new):**
- `AnalyticsService.swift`
- `FailureInjectionService.swift` (DEBUG)
- `NetworkLogger.swift` (DEBUG)

**Models (1 new):**
- `AnalyticsEvent.swift`

**Utilities (1 new):**
- `JWTAnalyzer.swift`

**Views (2 new):**
- `AnalyticsDashboardView.swift`
- `DebugSettingsView.swift`

**Tests (1 new):**
- `AuthEdgeCaseTests.swift`

**Documentation (15+ new):**
- `NETWORK_INSPECTION.md`
- `TEST_MATRIX.md`
- `TEST_SCENARIOS.md`
- `LOCATION_EDGE_CASES.md`
- `REGRESSION_CHECKLIST.md`
- `SMOKE_TEST.md`
- `RELEASE_CRITERIA.md`
- `AUTH_EDGE_CASES.md`
- `FAILURE_INJECTION.md`
- `QUALITY_AND_TESTING.md`
- `BUG_REPORT_TEMPLATE.md`
- `sample-bugs/BUG-001-*.md`
- `sample-bugs/BUG-002-*.md`
- `sample-bugs/BUG-003-*.md`
- `network-inspection/JWT_ANALYSIS.md`

### GitHub Push Commands

After each phase, push to GitHub:
```bash
git push origin main
```

Or create feature branches per phase:
```bash
git checkout -b feature/analytics-dashboard
# Complete Phase 1
git push -u origin feature/analytics-dashboard
# Create PR, merge to main
```

---

## Appendix: Quick Reference

### Build Commands
```bash
# Build iOS app
xcodebuild -scheme WhosThereios -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Run tests
xcodebuild test -scheme WhosThereios -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# Clean build
xcodebuild clean -scheme WhosThereios
```

### Git Commands
```bash
# Check status
git status

# Stage specific files
git add path/to/file

# Commit with message
git commit -m "type: description"

# Push to remote
git push origin main
```

### Commit Message Format
```
type: short description

- Detailed bullet point 1
- Detailed bullet point 2

Footer notes
```

Types: `feat`, `fix`, `docs`, `test`, `refactor`, `chore`
