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
