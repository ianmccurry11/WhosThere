//
//  ModelTests.swift
//  WhosThereiosTests
//
//  Created by Ian McCurry on 1/15/26.
//

import XCTest
import CoreLocation
@testable import WhosThereios

final class CoordinateTests: XCTestCase {

    func testCoordinateInitWithLatLng() {
        let coord = Coordinate(latitude: 40.7128, longitude: -74.0060)

        XCTAssertEqual(coord.latitude, 40.7128)
        XCTAssertEqual(coord.longitude, -74.0060)
    }

    func testCoordinateInitFromCLLocationCoordinate2D() {
        let clCoord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coord = Coordinate(from: clCoord)

        XCTAssertEqual(coord.latitude, 37.7749)
        XCTAssertEqual(coord.longitude, -122.4194)
    }

    func testCoordinateToCLLocationCoordinate2D() {
        let coord = Coordinate(latitude: 51.5074, longitude: -0.1278)
        let clCoord = coord.clLocationCoordinate

        XCTAssertEqual(clCoord.latitude, 51.5074)
        XCTAssertEqual(clCoord.longitude, -0.1278)
    }

    func testCoordinateEquatable() {
        let coord1 = Coordinate(latitude: 40.0, longitude: -74.0)
        let coord2 = Coordinate(latitude: 40.0, longitude: -74.0)
        let coord3 = Coordinate(latitude: 41.0, longitude: -74.0)

        XCTAssertEqual(coord1, coord2)
        XCTAssertNotEqual(coord1, coord3)
    }
}

final class LocationGroupTests: XCTestCase {

    func testLocationGroupInit() {
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
            memberIds: ["user123", "user456"],
            boundary: boundary,
            presenceDisplayMode: .names
        )

        XCTAssertEqual(group.name, "Test Group")
        XCTAssertTrue(group.isPublic)
        XCTAssertEqual(group.ownerId, "user123")
        XCTAssertEqual(group.memberIds.count, 2)
        XCTAssertEqual(group.boundary.count, 4)
        XCTAssertEqual(group.presenceDisplayMode, .names)
    }

    func testLocationGroupCenterCalculation() {
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.0, longitude: -74.2),
            Coordinate(latitude: 40.2, longitude: -74.2),
            Coordinate(latitude: 40.2, longitude: -74.0)
        ]

        let group = LocationGroup(
            name: "Square Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Center should be average of all coordinates
        XCTAssertEqual(group.centerLatitude, 40.1, accuracy: 0.001)
        XCTAssertEqual(group.centerLongitude, -74.1, accuracy: 0.001)
    }

    func testLocationGroupContainsPointInside() {
        // Create a square boundary
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.0, longitude: -74.1),
            Coordinate(latitude: 40.1, longitude: -74.1),
            Coordinate(latitude: 40.1, longitude: -74.0)
        ]

        let group = LocationGroup(
            name: "Test Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Point clearly inside the square
        let insidePoint = CLLocationCoordinate2D(latitude: 40.05, longitude: -74.05)
        XCTAssertTrue(group.contains(coordinate: insidePoint))
    }

    func testLocationGroupContainsPointOutside() {
        // Create a square boundary
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.0, longitude: -74.1),
            Coordinate(latitude: 40.1, longitude: -74.1),
            Coordinate(latitude: 40.1, longitude: -74.0)
        ]

        let group = LocationGroup(
            name: "Test Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        // Point clearly outside the square
        let outsidePoint = CLLocationCoordinate2D(latitude: 41.0, longitude: -75.0)
        XCTAssertFalse(group.contains(coordinate: outsidePoint))
    }

    func testLocationGroupContainsWithInsufficientBoundary() {
        // Create a boundary with only 2 points (not enough for a polygon)
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1)
        ]

        let group = LocationGroup(
            name: "Invalid Group",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        let point = CLLocationCoordinate2D(latitude: 40.05, longitude: -74.05)
        XCTAssertFalse(group.contains(coordinate: point))
    }

    func testLocationGroupBoundaryCoordinates() {
        let boundary = [
            Coordinate(latitude: 40.0, longitude: -74.0),
            Coordinate(latitude: 40.1, longitude: -74.1),
            Coordinate(latitude: 40.2, longitude: -74.0)
        ]

        let group = LocationGroup(
            name: "Triangle",
            isPublic: true,
            ownerId: "user123",
            boundary: boundary
        )

        let clCoords = group.boundaryCoordinates
        XCTAssertEqual(clCoords.count, 3)
        XCTAssertEqual(clCoords[0].latitude, 40.0)
        XCTAssertEqual(clCoords[1].latitude, 40.1)
        XCTAssertEqual(clCoords[2].latitude, 40.2)
    }

    func testLocationGroupEmptyBoundaryCenter() {
        let group = LocationGroup(
            name: "Empty Boundary",
            isPublic: true,
            ownerId: "user123",
            boundary: []
        )

        XCTAssertEqual(group.centerLatitude, 0)
        XCTAssertEqual(group.centerLongitude, 0)
    }
}

final class PresenceDisplayModeTests: XCTestCase {

    func testPresenceDisplayModeRawValues() {
        XCTAssertEqual(PresenceDisplayMode.count.rawValue, "count")
        XCTAssertEqual(PresenceDisplayMode.names.rawValue, "names")
    }
}

final class PresenceTests: XCTestCase {

    func testPresenceInit() {
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: true,
            isManual: false,
            displayName: "Test User"
        )

        XCTAssertEqual(presence.userId, "user123")
        XCTAssertEqual(presence.groupId, "group456")
        XCTAssertTrue(presence.isPresent)
        XCTAssertFalse(presence.isManual)
        XCTAssertEqual(presence.displayName, "Test User")
    }

    func testPresenceDefaultValues() {
        let presence = Presence(
            userId: "user123",
            groupId: "group456",
            isPresent: false
        )

        XCTAssertFalse(presence.isManual)
        XCTAssertNil(presence.displayName)
    }
}

final class GroupPresenceSummaryTests: XCTestCase {

    func testGroupPresenceSummaryIsEmpty() {
        let emptySummary = GroupPresenceSummary(
            groupId: "group123",
            presentCount: 0,
            presentMembers: []
        )

        XCTAssertTrue(emptySummary.isEmpty)
    }

    func testGroupPresenceSummaryIsNotEmpty() {
        let presence = Presence(
            userId: "user1",
            groupId: "group123",
            isPresent: true
        )

        let summary = GroupPresenceSummary(
            groupId: "group123",
            presentCount: 1,
            presentMembers: [presence]
        )

        XCTAssertFalse(summary.isEmpty)
    }
}

final class UserTests: XCTestCase {

    func testUserInit() {
        let user = User(
            id: "user123",
            displayName: "John Doe",
            email: "john@example.com",
            joinedGroupIds: ["group1", "group2"]
        )

        XCTAssertEqual(user.id, "user123")
        XCTAssertEqual(user.displayName, "John Doe")
        XCTAssertEqual(user.email, "john@example.com")
        XCTAssertEqual(user.joinedGroupIds.count, 2)
    }

    func testUserDefaultValues() {
        let user = User(displayName: "Jane Doe")

        XCTAssertNil(user.id)
        XCTAssertNil(user.email)
        XCTAssertTrue(user.joinedGroupIds.isEmpty)
    }
}

final class PresenceActiveRuleTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func presence(
        isPresent: Bool = true,
        updatedAgo: TimeInterval,
        expiresIn: TimeInterval? = nil
    ) -> Presence {
        Presence(
            userId: "user1",
            groupId: "group1",
            isPresent: isPresent,
            lastUpdated: now.addingTimeInterval(-updatedAgo),
            expiresAt: expiresIn.map { now.addingTimeInterval($0) }
        )
    }

    func testFreshPresenceIsActive() {
        XCTAssertTrue(presence(updatedAgo: 60, expiresIn: 3600).isActive(at: now))
    }

    func testCheckedOutPresenceIsNotActive() {
        XCTAssertFalse(presence(isPresent: false, updatedAgo: 60, expiresIn: 3600).isActive(at: now))
    }

    func testExpiredPresenceIsNotActive() {
        XCTAssertFalse(presence(updatedAgo: 60, expiresIn: -1).isActive(at: now))
    }

    func testPresenceExpiringExactlyNowIsNotActive() {
        XCTAssertFalse(presence(updatedAgo: 60, expiresIn: 0).isActive(at: now))
    }

    /// A check-in last written 3 days ago must not show, even with a far-off expiry
    func testThreeDayOldPresenceIsNotActive() {
        let old = presence(updatedAgo: 3 * 24 * 3600, expiresIn: 3600)
        XCTAssertFalse(old.isActive(at: now))
    }

    func testLegacyPresenceWithoutExpiryUsesMaxAge() {
        XCTAssertTrue(presence(updatedAgo: Presence.maxAge - 1).isActive(at: now))
        XCTAssertFalse(presence(updatedAgo: Presence.maxAge + 1).isActive(at: now))
    }
}

final class PresenceFadingTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func presence(updatedAgo: TimeInterval, isManual: Bool = false) -> Presence {
        Presence(
            userId: "user1",
            groupId: "group1",
            isPresent: true,
            isManual: isManual,
            lastUpdated: now.addingTimeInterval(-updatedAgo),
            expiresAt: now.addingTimeInterval(3600)
        )
    }

    func testRecentlyConfirmedIsNotFading() {
        let fresh = presence(updatedAgo: 10 * 60)
        XCTAssertFalse(fresh.isFading(at: now))
        XCTAssertNil(fresh.confirmationLabel(at: now))
    }

    func testQuietAutomaticCheckInFadesWithMinutesLabel() {
        let quiet = presence(updatedAgo: 45 * 60)
        XCTAssertTrue(quiet.isFading(at: now))
        XCTAssertEqual(quiet.confirmationLabel(at: now), "confirmed 45m ago")
    }

    func testOldAutomaticCheckInShowsHoursLabel() {
        XCTAssertEqual(presence(updatedAgo: 2 * 3600 + 600).confirmationLabel(at: now), "confirmed 2h ago")
    }

    func testManualCheckInNeverFades() {
        XCTAssertFalse(presence(updatedAgo: 2 * 3600, isManual: true).isFading(at: now))
    }
}

final class GroupBoundaryDistanceTests: XCTestCase {

    /// Roughly a 100m x 100m square
    private let group = LocationGroup(
        id: "group1",
        name: "Test",
        isPublic: false,
        ownerId: "owner",
        boundary: [
            Coordinate(latitude: 34.0000, longitude: -119.0000),
            Coordinate(latitude: 34.0009, longitude: -119.0000),
            Coordinate(latitude: 34.0009, longitude: -118.9989),
            Coordinate(latitude: 34.0000, longitude: -118.9989)
        ]
    )

    private func location(latitude: Double, longitude: Double, accuracy: Double) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            timestamp: Date()
        )
    }

    func testInsideIsZeroDistance() {
        let inside = CLLocationCoordinate2D(latitude: 34.0004, longitude: -118.9995)
        XCTAssertEqual(group.distanceToBoundary(from: inside), 0)
    }

    func testDistanceOutsideMatchesCoreLocation() {
        // ~50m north of the top edge
        let outside = CLLocationCoordinate2D(latitude: 34.00135, longitude: -118.9995)
        let edge = CLLocation(latitude: 34.0009, longitude: -118.9995)
        let expected = CLLocation(latitude: outside.latitude, longitude: outside.longitude).distance(from: edge)
        XCTAssertEqual(group.distanceToBoundary(from: outside), expected, accuracy: 1)
    }

    func testFixJustOutsideCountsWithinMargin() {
        // ~20m outside the top edge with a good fix: inside the 30m margin
        let fix = location(latitude: 34.00108, longitude: -118.9995, accuracy: 10)
        XCTAssertEqual(group.isAt(fix), true)
    }

    func testFixFarOutsideDoesNotCount() {
        // ~200m away
        let fix = location(latitude: 34.0027, longitude: -118.9995, accuracy: 10)
        XCTAssertEqual(group.isAt(fix), false)
    }

    func testMarginGrowsWithReportedAccuracy() {
        // ~50m outside: too far for the 30m margin, fine with a 65m indoor fix
        XCTAssertEqual(group.isAt(location(latitude: 34.00135, longitude: -118.9995, accuracy: 10)), false)
        XCTAssertEqual(group.isAt(location(latitude: 34.00135, longitude: -118.9995, accuracy: 65)), true)
    }

    func testInaccurateFixIsInconclusive() {
        XCTAssertNil(group.isAt(location(latitude: 34.0004, longitude: -118.9995, accuracy: 500)))
    }
}

final class ZoneReadingTests: XCTestCase {

    /// Same ~100m square as GroupBoundaryDistanceTests; top edge at 34.0009
    private let group = LocationGroup(
        id: "group1",
        name: "Test",
        isPublic: false,
        ownerId: "owner",
        boundary: [
            Coordinate(latitude: 34.0000, longitude: -119.0000),
            Coordinate(latitude: 34.0009, longitude: -119.0000),
            Coordinate(latitude: 34.0009, longitude: -118.9989),
            Coordinate(latitude: 34.0000, longitude: -118.9989)
        ]
    )

    /// A fix `metersNorth` of the top edge
    private func fix(metersNorth: Double, accuracy: Double) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 34.0009 + metersNorth / 111_320, longitude: -118.9995),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: -1,
            timestamp: Date()
        )
    }

    func testWithinMarginIsInside() {
        XCTAssertEqual(group.zoneReading(for: fix(metersNorth: 25, accuracy: 10)), .inside)
    }

    func testHysteresisBandIsNearby() {
        // 50m out: past the 30m margin but not past 75m + 10m
        XCTAssertEqual(group.zoneReading(for: fix(metersNorth: 50, accuracy: 10)), .nearby)
    }

    func testFarAwayIsOutside() {
        XCTAssertEqual(group.zoneReading(for: fix(metersNorth: 100, accuracy: 10)), .outside)
    }

    func testPoorAccuracyWidensBothThresholds() {
        // 100m out with a 40m fix: 75 + 40 = 115m needed to be clearly gone
        XCTAssertEqual(group.zoneReading(for: fix(metersNorth: 100, accuracy: 40)), .nearby)
    }

    func testUselessFixIsUnknown() {
        XCTAssertEqual(group.zoneReading(for: fix(metersNorth: 0, accuracy: 300)), .unknown)
    }
}

final class AutoPresenceDeciderTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func decide(
        _ reading: ZoneReading,
        _ state: AutoPresenceState,
        exitSignal: Bool = false
    ) -> AutoPresenceAction {
        AutoPresenceDecider.decide(reading: reading, state: state, hasExitSignal: exitSignal, now: now)
    }

    func testArrivingChecksIn() {
        XCTAssertEqual(decide(.inside, AutoPresenceState()), .checkIn)
    }

    func testAlreadyInsideRecentlyWrittenDoesNothing() {
        let state = AutoPresenceState(isAutoCheckedIn: true, lastWrite: now.addingTimeInterval(-60))
        XCTAssertEqual(decide(.inside, state), .none)
    }

    func testAlreadyInsideLongAgoRefreshes() {
        let state = AutoPresenceState(isAutoCheckedIn: true, lastWrite: now.addingTimeInterval(-15 * 60))
        XCTAssertEqual(decide(.inside, state), .refresh)
    }

    func testManualCheckInIsTakenOverWhenInside() {
        XCTAssertEqual(decide(.inside, AutoPresenceState(isManuallyCheckedIn: true)), .checkIn)
    }

    func testManualCheckOutBlocksAutoCheckInUntilLeaving() {
        let suppressed = AutoPresenceState(isSuppressed: true)
        XCTAssertEqual(decide(.inside, suppressed), .none)
        XCTAssertEqual(decide(.nearby, suppressed), .none)
        XCTAssertEqual(decide(.outside, suppressed), .clearSuppression)
    }

    func testNearbyNeverChangesAnything() {
        XCTAssertEqual(decide(.nearby, AutoPresenceState()), .none)
        XCTAssertEqual(decide(.nearby, AutoPresenceState(isAutoCheckedIn: true), exitSignal: true), .none)
    }

    func testSingleOutsideReadingWaits() {
        let state = AutoPresenceState(isAutoCheckedIn: true, outsideSince: now)
        XCTAssertEqual(decide(.outside, state), .none)
    }

    func testOutsideForTwoMinutesChecksOut() {
        let state = AutoPresenceState(isAutoCheckedIn: true, outsideSince: now.addingTimeInterval(-121))
        XCTAssertEqual(decide(.outside, state), .checkOut)
    }

    func testExitSignalPlusOutsideChecksOutImmediately() {
        let state = AutoPresenceState(isAutoCheckedIn: true, outsideSince: now)
        XCTAssertEqual(decide(.outside, state, exitSignal: true), .checkOut)
    }

    func testManualCheckInIsNeverAutoCheckedOut() {
        let state = AutoPresenceState(isAutoCheckedIn: false, isManuallyCheckedIn: true, outsideSince: now.addingTimeInterval(-600))
        XCTAssertEqual(decide(.outside, state, exitSignal: true), .none)
    }

    func testUnknownFixDoesNothing() {
        XCTAssertEqual(decide(.unknown, AutoPresenceState()), .none)
        XCTAssertEqual(decide(.unknown, AutoPresenceState(isAutoCheckedIn: true), exitSignal: true), .none)
    }
}
