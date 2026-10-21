//
//  Group.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import FirebaseFirestore
import CoreLocation
import SwiftUI

enum PresenceDisplayMode: String, Codable {
    case count = "count"
    case names = "names"
}

enum GroupColor: String, Codable, CaseIterable {
    // Free colors
    case blue = "blue"
    case green = "green"
    case red = "red"
    case orange = "orange"
    case purple = "purple"
    case pink = "pink"
    case teal = "teal"
    case yellow = "yellow"

    // Premium colors
    case gold = "gold"
    case indigo = "indigo"
    case mint = "mint"
    case lavender = "lavender"
    case coral = "coral"
    case slate = "slate"

    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .red: return .red
        case .orange: return .orange
        case .purple: return .purple
        case .pink: return .pink
        case .teal: return .teal
        case .yellow: return .yellow
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .indigo: return .indigo
        case .mint: return .mint
        case .lavender: return Color(red: 0.71, green: 0.49, blue: 0.86)
        case .coral: return Color(red: 1.0, green: 0.50, blue: 0.31)
        case .slate: return Color(red: 0.44, green: 0.50, blue: 0.56)
        }
    }

    var displayName: String {
        rawValue.capitalized
    }

}

struct Coordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

struct LocationGroup: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var emoji: String?
    var isPublic: Bool
    var ownerId: String
    var memberIds: [String]
    var boundary: [Coordinate]
    var centerLatitude: Double
    var centerLongitude: Double
    var presenceDisplayMode: PresenceDisplayMode
    var createdAt: Date
    var inviteCode: String?
    var groupColor: GroupColor?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case emoji
        case isPublic
        case ownerId
        case memberIds
        case boundary
        case centerLatitude
        case centerLongitude
        case presenceDisplayMode
        case createdAt
        case inviteCode
        case groupColor
    }

    /// Returns the group's color or blue as default
    var displayColor: Color {
        groupColor?.color ?? .blue
    }

    /// Returns the emoji icon or a default based on public/private status
    var displayEmoji: String {
        emoji ?? (isPublic ? "📍" : "🔒")
    }

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }

    var boundaryCoordinates: [CLLocationCoordinate2D] {
        boundary.map { $0.clLocationCoordinate }
    }

    init(
        id: String? = nil,
        name: String,
        emoji: String? = nil,
        isPublic: Bool,
        ownerId: String,
        memberIds: [String] = [],
        boundary: [Coordinate],
        presenceDisplayMode: PresenceDisplayMode = .names,
        createdAt: Date = Date(),
        inviteCode: String? = nil,
        groupColor: GroupColor? = .blue
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.isPublic = isPublic
        self.ownerId = ownerId
        self.memberIds = memberIds
        self.boundary = boundary
        self.presenceDisplayMode = presenceDisplayMode
        self.createdAt = createdAt
        self.inviteCode = inviteCode
        self.groupColor = groupColor

        // Calculate center from boundary
        let latSum = boundary.reduce(0) { $0 + $1.latitude }
        let lngSum = boundary.reduce(0) { $0 + $1.longitude }
        self.centerLatitude = boundary.isEmpty ? 0 : latSum / Double(boundary.count)
        self.centerLongitude = boundary.isEmpty ? 0 : lngSum / Double(boundary.count)
    }

    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        guard boundary.count >= 3 else { return false }

        let point = coordinate
        let polygon = boundaryCoordinates

        var isInside = false
        var j = polygon.count - 1

        for i in 0..<polygon.count {
            let xi = polygon[i].longitude
            let yi = polygon[i].latitude
            let xj = polygon[j].longitude
            let yj = polygon[j].latitude

            let intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
                (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)

            if intersect {
                isInside.toggle()
            }
            j = i
        }

        return isInside
    }
}

// MARK: - Distance to Boundary

extension LocationGroup {
    /// Meters from a coordinate to the nearest edge of the group's boundary,
    /// or 0 when the coordinate is inside. Lets presence checks allow a margin
    /// for GPS error instead of requiring the fix to land exactly in the box.
    func distanceToBoundary(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        guard boundary.count >= 3 else { return .infinity }
        if contains(coordinate: coordinate) { return 0 }

        // Flatten to local meters around the point; accurate at group scale
        let metersPerDegreeLatitude = 111_320.0
        let metersPerDegreeLongitude = metersPerDegreeLatitude * cos(coordinate.latitude * .pi / 180)
        let points = boundary.map { vertex in
            (x: (vertex.longitude - coordinate.longitude) * metersPerDegreeLongitude,
             y: (vertex.latitude - coordinate.latitude) * metersPerDegreeLatitude)
        }

        var nearest = CLLocationDistance.infinity
        for index in points.indices {
            let start = points[index]
            let end = points[(index + 1) % points.count]
            nearest = min(nearest, Self.distanceFromOrigin(toSegmentFrom: start, to: end))
        }
        return nearest
    }

    /// Where a location fix puts the user relative to this group, allowing for
    /// GPS error: within max(30m, accuracy) counts as inside; beyond
    /// 75m + accuracy is clearly outside; in between is "nearby".
    func zoneReading(for location: CLLocation) -> ZoneReading {
        let accuracy = location.horizontalAccuracy
        guard accuracy >= 0, accuracy <= PresencePolicy.maxUsableAccuracy else { return .unknown }

        let distance = distanceToBoundary(from: location.coordinate)
        if distance <= max(PresencePolicy.confirmMargin, accuracy) {
            return .inside
        }
        if distance > PresencePolicy.exitMargin + accuracy {
            return .outside
        }
        return .nearby
    }

    /// Whether a location fix puts the user at this group, or nil when the fix
    /// is too inaccurate to say either way.
    func isAt(_ location: CLLocation) -> Bool? {
        switch zoneReading(for: location) {
        case .unknown: return nil
        case .inside: return true
        case .nearby, .outside: return false
        }
    }

    private static func distanceFromOrigin(
        toSegmentFrom start: (x: Double, y: Double),
        to end: (x: Double, y: Double)
    ) -> Double {
        let segmentX = end.x - start.x
        let segmentY = end.y - start.y
        let lengthSquared = segmentX * segmentX + segmentY * segmentY
        guard lengthSquared > 0 else { return hypot(start.x, start.y) }

        // Project the origin onto the segment, clamped to its endpoints
        let projection = max(0, min(1, -(start.x * segmentX + start.y * segmentY) / lengthSquared))
        return hypot(start.x + projection * segmentX, start.y + projection * segmentY)
    }
}
