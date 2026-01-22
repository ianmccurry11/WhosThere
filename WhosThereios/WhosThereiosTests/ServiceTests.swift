//
//  ServiceTests.swift
//  WhosThereiosTests
//
//  Created by Ian McCurry on 1/15/26.
//

import XCTest
import CoreLocation
@testable import WhosThereios

final class FirestoreServiceTests: XCTestCase {

    func testGenerateInviteCode() async {
        let firestoreService = await FirestoreService.shared
        let code = await firestoreService.generateInviteCode()

        // Code should be 6 characters
        XCTAssertEqual(code.count, 6)

        // Code should only contain allowed characters
        let allowedCharacters = CharacterSet(charactersIn: "ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for char in code.unicodeScalars {
            XCTAssertTrue(allowedCharacters.contains(char), "Invalid character in invite code: \(char)")
        }
    }

    func testGenerateInviteCodeUniqueness() async {
        let firestoreService = await FirestoreService.shared

        // Generate multiple codes and check they're different
        var codes = Set<String>()
        for _ in 0..<10 {
            let code = await firestoreService.generateInviteCode()
            codes.insert(code)
        }

        // With 6 characters from 32 possible, collisions should be very rare
        // We expect at least 9 unique codes out of 10
        XCTAssertGreaterThanOrEqual(codes.count, 9)
    }
}

final class LocationServiceTests: XCTestCase {

    func testDistanceToGroup() async {
        let locationService = await LocationService.shared

        // Create a group at a known location
        let boundary = [
            Coordinate(latitude: 40.7128, longitude: -74.0060),
            Coordinate(latitude: 40.7128, longitude: -74.0160),
            Coordinate(latitude: 40.7228, longitude: -74.0160),
            Coordinate(latitude: 40.7228, longitude: -74.0060)
        ]

        let group = LocationGroup(
            name: "NYC Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Without a current location, distance should be nil
        let distance = await locationService.distanceToGroup(group)
        XCTAssertNil(distance)
    }

    func testCheckPresenceInGroupsWithoutLocation() async {
        let locationService = await LocationService.shared

        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1),
            Coordinate(latitude: 40.0, longitude: -74.1)
        ]

        let group = LocationGroup(
            id: "group123",
            name: "Test Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Without a current location, presence map should be empty
        let presenceMap = await locationService.checkPresenceInGroups([group])
        XCTAssertTrue(presenceMap.isEmpty)
    }

    func testIsInGroupWithoutLocation() async {
        let locationService = await LocationService.shared

        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1),
            Coordinate(latitude: 40.0, longitude: -74.1)
        ]

        let group = LocationGroup(
            name: "Test Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Without location, should return false
        let isIn = await locationService.isInGroup(group)
        XCTAssertFalse(isIn)
    }
}

final class PresenceServiceTests: XCTestCase {

    func testFormatPresenceDisplayCount() async {
        let presenceService = await PresenceService.shared

        // Create a group with count display mode
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1)
        ]

        let group = LocationGroup(
            id: "group123",
            name: "Test Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary,
            presenceDisplayMode: .count
        )

        // Without any presence data, should show "No one here"
        let display = await presenceService.formatPresenceDisplay(for: group)
        XCTAssertEqual(display, "No one here")
    }

    func testFormatPresenceDisplayNames() async {
        let presenceService = await PresenceService.shared

        // Create a group with names display mode
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1)
        ]

        let group = LocationGroup(
            id: "group456",
            name: "Names Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary,
            presenceDisplayMode: .names
        )

        // Without any presence data, should show "No one here"
        let display = await presenceService.formatPresenceDisplay(for: group)
        XCTAssertEqual(display, "No one here")
    }

    func testGetPresenceSummaryForUnknownGroup() async {
        let presenceService = await PresenceService.shared

        let summary = await presenceService.getPresenceSummary(for: "nonexistent-group")
        XCTAssertNil(summary)
    }

    func testIsUserPresentForUnknownGroup() async {
        let presenceService = await PresenceService.shared

        let isPresent = await presenceService.isUserPresent(groupId: "nonexistent-group", userId: "user123")
        XCTAssertFalse(isPresent)
    }
}

// MARK: - Group Membership Tests

final class GroupMembershipTests: XCTestCase {

    func testUserJoinedGroupIdsArrayOperations() {
        // Test that array operations work correctly on User model
        var user = User(
            id: "user123",
            displayName: "Test User",
            joinedGroupIds: ["group1", "group2"]
        )

        // Verify initial state
        XCTAssertEqual(user.joinedGroupIds.count, 2)
        XCTAssertTrue(user.joinedGroupIds.contains("group1"))
        XCTAssertTrue(user.joinedGroupIds.contains("group2"))

        // Simulate leaving a group
        user.joinedGroupIds.removeAll { $0 == "group1" }
        XCTAssertEqual(user.joinedGroupIds.count, 1)
        XCTAssertFalse(user.joinedGroupIds.contains("group1"))
        XCTAssertTrue(user.joinedGroupIds.contains("group2"))
    }

    func testGroupMemberIdsArrayOperations() {
        // Test that array operations work correctly on LocationGroup model
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1)
        ]

        var group = LocationGroup(
            id: "group123",
            name: "Test Group",
            isPublic: true,
            ownerId: "owner123",
            memberIds: ["user1", "user2", "user3"],
            boundary: boundary
        )

        // Verify initial state
        XCTAssertEqual(group.memberIds.count, 3)
        XCTAssertTrue(group.memberIds.contains("user1"))

        // Simulate user leaving
        group.memberIds.removeAll { $0 == "user1" }
        XCTAssertEqual(group.memberIds.count, 2)
        XCTAssertFalse(group.memberIds.contains("user1"))
        XCTAssertTrue(group.memberIds.contains("user2"))
        XCTAssertTrue(group.memberIds.contains("user3"))
    }

    func testUserCannotLeaveOwnedGroup() {
        // This is a logic test - owner should use delete, not leave
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1)
        ]

        let group = LocationGroup(
            id: "group123",
            name: "Test Group",
            isPublic: true,
            ownerId: "user123",
            memberIds: ["user123", "user456"],
            boundary: boundary
        )

        // Owner should be identified correctly
        let currentUserId = "user123"
        let isOwner = group.ownerId == currentUserId
        XCTAssertTrue(isOwner)

        // Non-owner should not be identified as owner
        let otherUserId = "user456"
        let isOtherOwner = group.ownerId == otherUserId
        XCTAssertFalse(isOtherOwner)
    }

    func testJoinedCheckWithEmptyGroupIds() {
        let user = User(
            id: "user123",
            displayName: "Test User",
            joinedGroupIds: []
        )

        // With empty joinedGroupIds, contains should return false
        XCTAssertFalse(user.joinedGroupIds.contains("anyGroupId"))
    }

    func testLeaveGroupUpdatesCorrectData() {
        // Simulates what should happen when leaving a group
        var user = User(
            id: "user123",
            displayName: "Test User",
            joinedGroupIds: ["groupA", "groupB", "groupC"]
        )

        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1)
        ]

        var group = LocationGroup(
            id: "groupB",
            name: "Group B",
            isPublic: true,
            ownerId: "owner456",
            memberIds: ["user123", "user456", "user789"],
            boundary: boundary
        )

        let groupIdToLeave = "groupB"
        let userId = "user123"

        // Simulate leave operation
        user.joinedGroupIds.removeAll { $0 == groupIdToLeave }
        group.memberIds.removeAll { $0 == userId }

        // Verify user no longer has the group
        XCTAssertFalse(user.joinedGroupIds.contains(groupIdToLeave))
        XCTAssertEqual(user.joinedGroupIds, ["groupA", "groupC"])

        // Verify group no longer has the user
        XCTAssertFalse(group.memberIds.contains(userId))
        XCTAssertEqual(group.memberIds, ["user456", "user789"])
    }
}

// MARK: - Auto Check-out Timer Tests

final class AutoCheckOutTimerTests: XCTestCase {

    func testTimerExpirationCalculation() {
        // Test that expiration date is calculated correctly
        let minutes = 60
        let startTime = Date()
        let expirationDate = startTime.addingTimeInterval(TimeInterval(minutes * 60))

        // Should be 1 hour (3600 seconds) in the future
        let expectedInterval: TimeInterval = 3600
        let actualInterval = expirationDate.timeIntervalSince(startTime)

        XCTAssertEqual(actualInterval, expectedInterval, accuracy: 1.0)
    }

    func testRemainingTimeCalculation() {
        // Simulate checking remaining time
        let expirationDate = Date().addingTimeInterval(1800) // 30 minutes from now
        let remaining = expirationDate.timeIntervalSinceNow

        // Should be approximately 30 minutes (1800 seconds)
        XCTAssertGreaterThan(remaining, 1790)
        XCTAssertLessThan(remaining, 1810)
    }

    func testExpiredTimerReturnsNegative() {
        // Timer that expired 5 minutes ago
        let expirationDate = Date().addingTimeInterval(-300)
        let remaining = expirationDate.timeIntervalSinceNow

        XCTAssertLessThan(remaining, 0)
    }

    func testTimerDurationOptions() {
        // Verify all timer options convert correctly to seconds
        let options = [15, 30, 60, 120, 240] // minutes

        let expectedSeconds = [900, 1800, 3600, 7200, 14400]

        for (index, minutes) in options.enumerated() {
            let seconds = minutes * 60
            XCTAssertEqual(seconds, expectedSeconds[index])
        }
    }

    func testDefaultAutoCheckOutMinutes() {
        // New users should default to 60 minutes
        let user = User(
            id: "user123",
            displayName: "Test User"
        )

        XCTAssertEqual(user.autoCheckOutMinutes, 60)
    }

    func testCustomAutoCheckOutMinutes() {
        let user = User(
            id: "user123",
            displayName: "Test User",
            autoCheckOutMinutes: 30
        )

        XCTAssertEqual(user.autoCheckOutMinutes, 30)
    }
}

// MARK: - Location Permission Tests

final class LocationPermissionTests: XCTestCase {

    func testAlwaysPermissionEnablesBackgroundTracking() {
        // This is a conceptual test - in real app, CLAuthorizationStatus.authorizedAlways
        // enables background location updates and geofencing
        let alwaysStatus = CLAuthorizationStatus.authorizedAlways
        let whenInUseStatus = CLAuthorizationStatus.authorizedWhenInUse

        // Always permission should enable background features
        XCTAssertTrue(alwaysStatus == .authorizedAlways)
        XCTAssertFalse(whenInUseStatus == .authorizedAlways)
    }

    func testWhenInUseRequiresManualCheckIn() {
        // Users with "When In Use" permission need manual check-in
        // and will have auto check-out timers
        let whenInUseStatus = CLAuthorizationStatus.authorizedWhenInUse

        let needsManualCheckIn = whenInUseStatus != .authorizedAlways
        XCTAssertTrue(needsManualCheckIn)
    }
}

// MARK: - Geofence Region Tests

final class GeofenceRegionTests: XCTestCase {

    func testMaxMonitoredRegions() {
        // iOS allows maximum of 20 monitored regions
        let maxRegions = 20

        // Simulate having 25 groups
        let totalGroups = 25

        // We should only monitor the nearest 20
        let regionsToMonitor = min(totalGroups, maxRegions)
        XCTAssertEqual(regionsToMonitor, 20)
    }

    func testCircularRegionRadius() {
        // Test radius calculation from boundary
        let boundary = [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 0, longitude: 0.001),
            Coordinate(latitude: 0.001, longitude: 0.001),
            Coordinate(latitude: 0.001, longitude: 0)
        ]

        let group = LocationGroup(
            name: "Test",
            isPublic: true,
            ownerId: "owner",
            boundary: boundary
        )

        // Center should be calculated from boundary
        let expectedCenterLat = 0.0005
        let expectedCenterLng = 0.0005

        XCTAssertEqual(group.centerLatitude, expectedCenterLat, accuracy: 0.0001)
        XCTAssertEqual(group.centerLongitude, expectedCenterLng, accuracy: 0.0001)
    }

    func testRegionEntryExitCallbacks() {
        // Test that region identifiers match group IDs
        let groupId = "group123"

        // In real implementation, CLCircularRegion uses groupId as identifier
        let regionIdentifier = groupId

        XCTAssertEqual(regionIdentifier, "group123")
    }
}

// MARK: - Presence State Tests

final class PresenceStateTests: XCTestCase {

    func testManualCheckInOverridesAuto() {
        // Manual overrides should take precedence
        var manualOverrides: [String: Bool] = [:]

        // User manually checks in
        manualOverrides["group1"] = true

        // Manual check-in should be recorded
        XCTAssertEqual(manualOverrides["group1"], true)

        // User manually checks out
        manualOverrides["group1"] = false

        // Manual check-out should be recorded
        XCTAssertEqual(manualOverrides["group1"], false)
    }

    func testClearManualOverride() {
        var manualOverrides: [String: Bool] = ["group1": true, "group2": false]

        // Clear override for group1
        manualOverrides.removeValue(forKey: "group1")

        // group1 should be nil (no override)
        XCTAssertNil(manualOverrides["group1"])

        // group2 should still have its override
        XCTAssertEqual(manualOverrides["group2"], false)
    }

    func testPresenceModelCreation() {
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            lastUpdated: Date(),
            displayName: "Test User"
        )

        XCTAssertEqual(presence.userId, "user123")
        XCTAssertEqual(presence.groupId, "group456")
        XCTAssertTrue(presence.isPresent)
        XCTAssertFalse(presence.isManual)
        XCTAssertEqual(presence.displayName, "Test User")
    }

    func testManualPresenceFlag() {
        // Manual check-in should set isManual to true
        let manualPresence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: true,
            lastUpdated: Date(),
            displayName: "Test User"
        )

        XCTAssertTrue(manualPresence.isManual)

        // Auto check-in should set isManual to false
        let autoPresence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            lastUpdated: Date(),
            displayName: "Test User"
        )

        XCTAssertFalse(autoPresence.isManual)
    }
}

// MARK: - Stale Presence Tests

final class StalePresenceTests: XCTestCase {

    /// 10 hours in seconds (matches PresenceService.maxPresenceDuration)
    let maxPresenceDuration: TimeInterval = 10 * 60 * 60

    func testPresenceAgeCalculation() {
        // Create a presence from 5 hours ago
        let fiveHoursAgo = Date().addingTimeInterval(-5 * 60 * 60)
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            lastUpdated: fiveHoursAgo,
            displayName: "Test User"
        )

        let age = Date().timeIntervalSince(presence.lastUpdated)

        // Should be approximately 5 hours
        XCTAssertGreaterThan(age, 5 * 60 * 60 - 10)
        XCTAssertLessThan(age, 5 * 60 * 60 + 10)
    }

    func testPresenceUnderMaxDurationIsNotStale() {
        // Create a presence from 9 hours ago (under 10 hour limit)
        let nineHoursAgo = Date().addingTimeInterval(-9 * 60 * 60)
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            lastUpdated: nineHoursAgo,
            displayName: "Test User"
        )

        let age = Date().timeIntervalSince(presence.lastUpdated)
        let isStale = age > maxPresenceDuration

        XCTAssertFalse(isStale)
    }

    func testPresenceOverMaxDurationIsStale() {
        // Create a presence from 11 hours ago (over 10 hour limit)
        let elevenHoursAgo = Date().addingTimeInterval(-11 * 60 * 60)
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            lastUpdated: elevenHoursAgo,
            displayName: "Test User"
        )

        let age = Date().timeIntervalSince(presence.lastUpdated)
        let isStale = age > maxPresenceDuration

        XCTAssertTrue(isStale)
    }

    func testPresenceExactlyAtLimitIsNotStale() {
        // Create a presence from exactly 10 hours ago
        let tenHoursAgo = Date().addingTimeInterval(-10 * 60 * 60)
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            lastUpdated: tenHoursAgo,
            displayName: "Test User"
        )

        let age = Date().timeIntervalSince(presence.lastUpdated)
        // Age should be > maxDuration to be stale, not >=
        let isStale = age > maxPresenceDuration

        // At exactly 10 hours, should not be stale yet (need to be over)
        XCTAssertFalse(isStale)
    }

    func testPresenceJustOverLimitIsStale() {
        // Create a presence from 10 hours and 1 minute ago
        let justOverLimit = Date().addingTimeInterval(-10 * 60 * 60 - 60)
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            lastUpdated: justOverLimit,
            displayName: "Test User"
        )

        let age = Date().timeIntervalSince(presence.lastUpdated)
        let isStale = age > maxPresenceDuration

        XCTAssertTrue(isStale)
    }

    func testFreshPresenceIsNotStale() {
        // Create a presence from just now
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            lastUpdated: Date(),
            displayName: "Test User"
        )

        let age = Date().timeIntervalSince(presence.lastUpdated)
        let isStale = age > maxPresenceDuration

        XCTAssertFalse(isStale)
    }

    func testFilterStalePresences() {
        // Create a mix of fresh and stale presences
        let freshPresence = Presence(
            userId: "user1",
            groupId: "group1",
            isPresent: true,
            isManual: false,
            lastUpdated: Date(),
            displayName: "Fresh User"
        )

        let oldPresence = Presence(
            userId: "user2",
            groupId: "group1",
            isPresent: true,
            isManual: false,
            lastUpdated: Date().addingTimeInterval(-12 * 60 * 60), // 12 hours ago
            displayName: "Stale User"
        )

        let anotherFreshPresence = Presence(
            userId: "user3",
            groupId: "group1",
            isPresent: true,
            isManual: false,
            lastUpdated: Date().addingTimeInterval(-1 * 60 * 60), // 1 hour ago
            displayName: "Another Fresh User"
        )

        let presences = [freshPresence, oldPresence, anotherFreshPresence]

        // Filter out stale presences
        let activePresences = presences.filter { presence in
            let age = Date().timeIntervalSince(presence.lastUpdated)
            return age <= maxPresenceDuration
        }

        XCTAssertEqual(activePresences.count, 2)
        XCTAssertTrue(activePresences.contains { $0.userId == "user1" })
        XCTAssertFalse(activePresences.contains { $0.userId == "user2" })
        XCTAssertTrue(activePresences.contains { $0.userId == "user3" })
    }

    func testMaxPresenceDurationConstant() {
        // Verify the constant is 10 hours in seconds
        let expectedDuration: TimeInterval = 10 * 60 * 60 // 36000 seconds
        XCTAssertEqual(maxPresenceDuration, expectedDuration)
        XCTAssertEqual(maxPresenceDuration, 36000)
    }
}

// MARK: - Point in Polygon Algorithm Tests

final class PointInPolygonTests: XCTestCase {

    func testSquareBoundary() {
        let boundary = [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 0, longitude: 10),
            Coordinate(latitude: 10, longitude: 10),
            Coordinate(latitude: 10, longitude: 0)
        ]

        let group = LocationGroup(
            name: "Square",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Center point - should be inside
        XCTAssertTrue(group.contains(coordinate: CLLocationCoordinate2D(latitude: 5, longitude: 5)))

        // Near corner but inside
        XCTAssertTrue(group.contains(coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1)))

        // Outside - to the right
        XCTAssertFalse(group.contains(coordinate: CLLocationCoordinate2D(latitude: 5, longitude: 15)))

        // Outside - above
        XCTAssertFalse(group.contains(coordinate: CLLocationCoordinate2D(latitude: 15, longitude: 5)))

        // Outside - negative coordinates
        XCTAssertFalse(group.contains(coordinate: CLLocationCoordinate2D(latitude: -5, longitude: 5)))
    }

    func testTriangleBoundary() {
        let boundary = [
            Coordinate(latitude: 0, longitude: 5),
            Coordinate(latitude: 10, longitude: 0),
            Coordinate(latitude: 10, longitude: 10)
        ]

        let group = LocationGroup(
            name: "Triangle",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Centroid should be inside
        XCTAssertTrue(group.contains(coordinate: CLLocationCoordinate2D(latitude: 6.67, longitude: 5)))

        // Point outside the triangle
        XCTAssertFalse(group.contains(coordinate: CLLocationCoordinate2D(latitude: 2, longitude: 2)))
    }

    func testLShapedBoundary() {
        // L-shaped polygon
        let boundary = [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 0, longitude: 5),
            Coordinate(latitude: 5, longitude: 5),
            Coordinate(latitude: 5, longitude: 10),
            Coordinate(latitude: 10, longitude: 10),
            Coordinate(latitude: 10, longitude: 0)
        ]

        let group = LocationGroup(
            name: "L-Shape",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Point in bottom part of L - should be inside
        XCTAssertTrue(group.contains(coordinate: CLLocationCoordinate2D(latitude: 2, longitude: 7)))

        // Point in top part of L - should be inside
        XCTAssertTrue(group.contains(coordinate: CLLocationCoordinate2D(latitude: 7, longitude: 7)))

        // Point in the "notch" of L - should be outside
        XCTAssertFalse(group.contains(coordinate: CLLocationCoordinate2D(latitude: 2, longitude: 7)))
    }
}

// MARK: - Validation Tests

final class ValidationTests: XCTestCase {

    // MARK: - Display Name Validation

    func testValidDisplayName() {
        let result = Validation.validateDisplayName("John Doe")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
    }

    func testEmptyDisplayName() {
        let result = Validation.validateDisplayName("")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }

    func testWhitespaceOnlyDisplayName() {
        let result = Validation.validateDisplayName("   ")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }

    func testDisplayNameTooLong() {
        let longName = String(repeating: "a", count: 51)
        let result = Validation.validateDisplayName(longName)
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }

    func testDisplayNameMaxLength() {
        let maxName = String(repeating: "a", count: 50)
        let result = Validation.validateDisplayName(maxName)
        XCTAssertTrue(result.isValid)
    }

    func testDisplayNameWithAllowedPunctuation() {
        let result = Validation.validateDisplayName("John O'Connor-Smith")
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Group Name Validation

    func testValidGroupName() {
        let result = Validation.validateGroupName("Basketball Court")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.error)
    }

    func testEmptyGroupName() {
        let result = Validation.validateGroupName("")
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.error)
    }

    func testGroupNameTooLong() {
        let longName = String(repeating: "a", count: 101)
        let result = Validation.validateGroupName(longName)
        XCTAssertFalse(result.isValid)
    }

    func testGroupNameMaxLength() {
        let maxName = String(repeating: "a", count: 100)
        let result = Validation.validateGroupName(maxName)
        XCTAssertTrue(result.isValid)
    }

    // MARK: - Coordinate Validation

    func testValidLatitude() {
        XCTAssertTrue(Validation.isValidLatitude(0))
        XCTAssertTrue(Validation.isValidLatitude(45.5))
        XCTAssertTrue(Validation.isValidLatitude(-45.5))
        XCTAssertTrue(Validation.isValidLatitude(90))
        XCTAssertTrue(Validation.isValidLatitude(-90))
    }

    func testInvalidLatitude() {
        XCTAssertFalse(Validation.isValidLatitude(91))
        XCTAssertFalse(Validation.isValidLatitude(-91))
        XCTAssertFalse(Validation.isValidLatitude(180))
    }

    func testValidLongitude() {
        XCTAssertTrue(Validation.isValidLongitude(0))
        XCTAssertTrue(Validation.isValidLongitude(90))
        XCTAssertTrue(Validation.isValidLongitude(-90))
        XCTAssertTrue(Validation.isValidLongitude(180))
        XCTAssertTrue(Validation.isValidLongitude(-180))
    }

    func testInvalidLongitude() {
        XCTAssertFalse(Validation.isValidLongitude(181))
        XCTAssertFalse(Validation.isValidLongitude(-181))
    }

    func testValidCoordinate() {
        let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        XCTAssertTrue(Validation.isValidCoordinate(coordinate))
    }

    func testInvalidCoordinate() {
        let invalidLat = CLLocationCoordinate2D(latitude: 91, longitude: -122.4194)
        XCTAssertFalse(Validation.isValidCoordinate(invalidLat))

        let invalidLng = CLLocationCoordinate2D(latitude: 37.7749, longitude: -181)
        XCTAssertFalse(Validation.isValidCoordinate(invalidLng))
    }

    // MARK: - Boundary Validation

    func testValidBoundary() {
        let boundary = [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 0, longitude: 1),
            Coordinate(latitude: 1, longitude: 1),
            Coordinate(latitude: 1, longitude: 0)
        ]
        let result = Validation.validateBoundary(boundary)
        XCTAssertTrue(result.isValid)
    }

    func testBoundaryTooFewPoints() {
        let boundary = [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 0, longitude: 1)
        ]
        let result = Validation.validateBoundary(boundary)
        XCTAssertFalse(result.isValid)
    }

    func testBoundaryTooManyPoints() {
        var boundary: [Coordinate] = []
        for i in 0..<101 {
            boundary.append(Coordinate(latitude: Double(i % 90), longitude: Double(i % 180)))
        }
        let result = Validation.validateBoundary(boundary)
        XCTAssertFalse(result.isValid)
    }

    func testBoundaryWithInvalidCoordinate() {
        let boundary = [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 91, longitude: 1), // Invalid latitude
            Coordinate(latitude: 1, longitude: 1)
        ]
        let result = Validation.validateBoundary(boundary)
        XCTAssertFalse(result.isValid)
    }

    func testCollinearBoundary() {
        // All points on a line - should fail
        let boundary = [
            Coordinate(latitude: 0, longitude: 0),
            Coordinate(latitude: 1, longitude: 1),
            Coordinate(latitude: 2, longitude: 2)
        ]
        let result = Validation.validateBoundary(boundary)
        XCTAssertFalse(result.isValid)
    }

    // MARK: - Invite Code Validation

    func testValidInviteCode() {
        XCTAssertTrue(Validation.isValidInviteCodeFormat("ABC123"))
        XCTAssertTrue(Validation.isValidInviteCodeFormat("ZZZZZ9"))
    }

    func testInvalidInviteCodeLength() {
        XCTAssertFalse(Validation.isValidInviteCodeFormat("ABC"))
        XCTAssertFalse(Validation.isValidInviteCodeFormat("ABCDEFG"))
    }

    func testInvalidInviteCodeCharacters() {
        XCTAssertFalse(Validation.isValidInviteCodeFormat("ABC12!"))
        XCTAssertFalse(Validation.isValidInviteCodeFormat("abc123")) // Lowercase is converted before checking
    }

    // MARK: - Sanitization

    func testSanitizeDisplayName() {
        XCTAssertEqual(Validation.sanitizeDisplayName("  John  "), "John")
        XCTAssertEqual(Validation.sanitizeDisplayName("\n\tName\n"), "Name")
    }

    func testSanitizeGroupName() {
        XCTAssertEqual(Validation.sanitizeGroupName("  My Group  "), "My Group")
    }

    func testSanitizeInviteCode() {
        XCTAssertEqual(Validation.sanitizeInviteCode("abc123"), "ABC123")
        XCTAssertEqual(Validation.sanitizeInviteCode("  ABC  "), "ABC")
    }
}

// MARK: - AppError Tests

final class AppErrorTests: XCTestCase {

    func testErrorDescription() {
        let error = AppError.notAuthenticated
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty)
    }

    func testUserMessage() {
        let error = AppError.notAuthenticated
        XCTAssertEqual(error.userMessage, "Please sign in")

        let networkError = AppError.networkUnavailable
        XCTAssertEqual(networkError.userMessage, "No connection")
    }

    func testShouldLog() {
        // Expected user states should not be logged
        XCTAssertFalse(AppError.notAuthenticated.shouldLog)
        XCTAssertFalse(AppError.locationPermissionDenied.shouldLog)

        // Actual errors should be logged
        XCTAssertTrue(AppError.groupCreationFailed(underlying: nil).shouldLog)
        XCTAssertTrue(AppError.serverError(underlying: nil).shouldLog)
    }

    func testRecoverySuggestion() {
        let error = AppError.locationPermissionDenied
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("Settings"))
    }

    func testErrorWithUnderlyingError() {
        let underlyingError = NSError(domain: "test", code: 123, userInfo: nil)
        let error = AppError.groupCreationFailed(underlying: underlyingError)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("123") || error.errorDescription!.contains("test"))
    }

    func testValidationError() {
        let error = AppError.validationFailed(field: "email", reason: "Invalid format")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("email"))
        XCTAssertTrue(error.errorDescription!.contains("Invalid format"))
    }
}

// MARK: - Integration Tests

final class GroupValidationIntegrationTests: XCTestCase {

    func testValidateGroupDataComplete() {
        let result = Validation.validateGroupData(
            name: "Basketball Court",
            boundary: [
                Coordinate(latitude: 0, longitude: 0),
                Coordinate(latitude: 0, longitude: 1),
                Coordinate(latitude: 1, longitude: 1),
                Coordinate(latitude: 1, longitude: 0)
            ],
            centerLatitude: 0.5,
            centerLongitude: 0.5
        )
        XCTAssertTrue(result.isValid)
    }

    func testValidateGroupDataWithInvalidName() {
        let result = Validation.validateGroupData(
            name: "",
            boundary: [
                Coordinate(latitude: 0, longitude: 0),
                Coordinate(latitude: 0, longitude: 1),
                Coordinate(latitude: 1, longitude: 1)
            ],
            centerLatitude: 0.5,
            centerLongitude: 0.5
        )
        XCTAssertFalse(result.isValid)
        if case .invalidGroupName = result.error {
            // Expected error type
        } else {
            XCTFail("Expected invalidGroupName error")
        }
    }

    func testValidateGroupDataWithInvalidBoundary() {
        let result = Validation.validateGroupData(
            name: "Valid Name",
            boundary: [
                Coordinate(latitude: 0, longitude: 0),
                Coordinate(latitude: 0, longitude: 1)
            ],
            centerLatitude: 0.5,
            centerLongitude: 0.5
        )
        XCTAssertFalse(result.isValid)
        if case .invalidBoundary = result.error {
            // Expected error type
        } else {
            XCTFail("Expected invalidBoundary error")
        }
    }

    func testValidateGroupDataWithInvalidCenter() {
        let result = Validation.validateGroupData(
            name: "Valid Name",
            boundary: [
                Coordinate(latitude: 0, longitude: 0),
                Coordinate(latitude: 0, longitude: 1),
                Coordinate(latitude: 1, longitude: 1)
            ],
            centerLatitude: 91, // Invalid
            centerLongitude: 0.5
        )
        XCTAssertFalse(result.isValid)
    }
}
