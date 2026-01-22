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
    case blue = "blue"
    case green = "green"
    case red = "red"
    case orange = "orange"
    case purple = "purple"
    case pink = "pink"
    case teal = "teal"
    case yellow = "yellow"

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
