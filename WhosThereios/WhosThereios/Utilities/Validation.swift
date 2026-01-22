//
//  Validation.swift
//  WhosThereios
//
//  Created by Claude on 1/16/26.
//

import Foundation
import CoreLocation

/// Input validation utilities for the Who's There app
enum Validation {

    // MARK: - Validation Constants

    enum Constants {
        // Display Name
        static let displayNameMinLength = 1
        static let displayNameMaxLength = 50

        // Group Name
        static let groupNameMinLength = 1
        static let groupNameMaxLength = 100

        // Emoji
        static let emojiMaxLength = 10

        // Boundary
        static let boundaryMinPoints = 3
        static let boundaryMaxPoints = 100

        // Area limits (in square meters)
        static let areaMinSquareMeters: Double = 100          // ~10m x 10m - minimum useful size
        static let areaMaxSquareMeters: Double = 1_000_000    // 1 km² - about 247 acres, max size

        // Coordinate ranges
        static let latitudeMin: Double = -90.0
        static let latitudeMax: Double = 90.0
        static let longitudeMin: Double = -180.0
        static let longitudeMax: Double = 180.0

        // Invite Code
        static let inviteCodeLength = 6
        static let inviteCodeCharacters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    }

    // MARK: - Validation Results

    struct ValidationResult {
        let isValid: Bool
        let error: AppError?

        static let valid = ValidationResult(isValid: true, error: nil)

        static func invalid(_ error: AppError) -> ValidationResult {
            ValidationResult(isValid: false, error: error)
        }
    }

    // MARK: - Display Name Validation

    /// Validates a display name
    /// - Parameter name: The display name to validate
    /// - Returns: ValidationResult indicating if the name is valid
    static func validateDisplayName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid(.invalidDisplayName(reason: "Name cannot be empty"))
        }

        if trimmed.count < Constants.displayNameMinLength {
            return .invalid(.invalidDisplayName(reason: "Name must be at least \(Constants.displayNameMinLength) character"))
        }

        if trimmed.count > Constants.displayNameMaxLength {
            return .invalid(.invalidDisplayName(reason: "Name must be \(Constants.displayNameMaxLength) characters or less"))
        }

        // Check for invalid characters (only allow letters, numbers, spaces, and common punctuation)
        let allowedCharacterSet = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(CharacterSet(charactersIn: "-_.'"))

        if trimmed.unicodeScalars.contains(where: { !allowedCharacterSet.contains($0) }) {
            return .invalid(.invalidDisplayName(reason: "Name contains invalid characters"))
        }

        return .valid
    }

    // MARK: - Group Name Validation

    /// Validates a group name
    /// - Parameter name: The group name to validate
    /// - Returns: ValidationResult indicating if the name is valid
    static func validateGroupName(_ name: String) -> ValidationResult {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty {
            return .invalid(.invalidGroupName(reason: "Name cannot be empty"))
        }

        if trimmed.count < Constants.groupNameMinLength {
            return .invalid(.invalidGroupName(reason: "Name must be at least \(Constants.groupNameMinLength) character"))
        }

        if trimmed.count > Constants.groupNameMaxLength {
            return .invalid(.invalidGroupName(reason: "Name must be \(Constants.groupNameMaxLength) characters or less"))
        }

        return .valid
    }

    // MARK: - Coordinate Validation

    /// Validates a latitude value
    /// - Parameter latitude: The latitude to validate
    /// - Returns: true if valid, false otherwise
    static func isValidLatitude(_ latitude: Double) -> Bool {
        latitude >= Constants.latitudeMin && latitude <= Constants.latitudeMax
    }

    /// Validates a longitude value
    /// - Parameter longitude: The longitude to validate
    /// - Returns: true if valid, false otherwise
    static func isValidLongitude(_ longitude: Double) -> Bool {
        longitude >= Constants.longitudeMin && longitude <= Constants.longitudeMax
    }

    /// Validates a coordinate
    /// - Parameter coordinate: The coordinate to validate
    /// - Returns: true if valid, false otherwise
    static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        isValidLatitude(coordinate.latitude) && isValidLongitude(coordinate.longitude)
    }

    // MARK: - Boundary Validation

    /// Validates a boundary (array of coordinates forming a polygon)
    /// - Parameter boundary: Array of Coordinate objects
    /// - Returns: ValidationResult indicating if the boundary is valid
    static func validateBoundary(_ boundary: [Coordinate]) -> ValidationResult {
        if boundary.count < Constants.boundaryMinPoints {
            return .invalid(.invalidBoundary(reason: "Boundary must have at least \(Constants.boundaryMinPoints) points"))
        }

        if boundary.count > Constants.boundaryMaxPoints {
            return .invalid(.invalidBoundary(reason: "Boundary cannot have more than \(Constants.boundaryMaxPoints) points"))
        }

        // Validate each coordinate
        for (index, coord) in boundary.enumerated() {
            if !isValidLatitude(coord.latitude) {
                return .invalid(.invalidBoundary(reason: "Point \(index + 1) has invalid latitude"))
            }
            if !isValidLongitude(coord.longitude) {
                return .invalid(.invalidBoundary(reason: "Point \(index + 1) has invalid longitude"))
            }
        }

        // Check for duplicate consecutive points
        for i in 0..<(boundary.count - 1) {
            if boundary[i].latitude == boundary[i + 1].latitude &&
               boundary[i].longitude == boundary[i + 1].longitude {
                return .invalid(.invalidBoundary(reason: "Boundary contains duplicate consecutive points"))
            }
        }

        // Check that polygon has non-zero area (not all points collinear)
        if !hasNonZeroArea(boundary) {
            return .invalid(.invalidBoundary(reason: "Boundary points form a line, not an area"))
        }

        // Validate area size
        let areaResult = validateBoundaryArea(boundary)
        if !areaResult.isValid {
            return areaResult
        }

        return .valid
    }

    /// Validates that the boundary area is within acceptable limits
    /// - Parameter boundary: Array of Coordinate objects
    /// - Returns: ValidationResult indicating if the area size is valid
    static func validateBoundaryArea(_ boundary: [Coordinate]) -> ValidationResult {
        let areaInSquareMeters = calculatePolygonArea(boundary)

        if areaInSquareMeters < Constants.areaMinSquareMeters {
            return .invalid(.invalidBoundary(reason: "Area is too small. Minimum size is about 10m x 10m."))
        }

        if areaInSquareMeters > Constants.areaMaxSquareMeters {
            let maxKm = Constants.areaMaxSquareMeters / 1_000_000
            return .invalid(.invalidBoundary(reason: "Area is too large. Maximum size is \(Int(maxKm)) km² (about 247 acres)."))
        }

        return .valid
    }

    /// Calculates the area of a polygon in square meters using the Shoelace formula
    /// with geodesic correction for Earth's curvature
    /// - Parameter boundary: Array of Coordinate objects
    /// - Returns: Area in square meters
    static func calculatePolygonArea(_ boundary: [Coordinate]) -> Double {
        guard boundary.count >= 3 else { return 0 }

        // Use the Shoelace formula with latitude correction
        // This provides reasonable accuracy for small to medium polygons
        var area: Double = 0
        let n = boundary.count

        for i in 0..<n {
            let j = (i + 1) % n

            // Convert to radians
            let lat1 = boundary[i].latitude * .pi / 180
            let lat2 = boundary[j].latitude * .pi / 180
            let lon1 = boundary[i].longitude * .pi / 180
            let lon2 = boundary[j].longitude * .pi / 180

            // Spherical excess formula component
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        // Earth's radius in meters
        let earthRadius: Double = 6_371_000

        // Calculate absolute area
        area = abs(area * earthRadius * earthRadius / 2)

        return area
    }

    /// Validates a boundary using CLLocationCoordinate2D array
    /// - Parameter coordinates: Array of CLLocationCoordinate2D
    /// - Returns: ValidationResult indicating if the boundary is valid
    static func validateBoundary(_ coordinates: [CLLocationCoordinate2D]) -> ValidationResult {
        let boundary = coordinates.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
        return validateBoundary(boundary)
    }

    /// Checks if a polygon has non-zero area using the shoelace formula
    private static func hasNonZeroArea(_ boundary: [Coordinate]) -> Bool {
        guard boundary.count >= 3 else { return false }

        var area: Double = 0
        let n = boundary.count

        for i in 0..<n {
            let j = (i + 1) % n
            area += boundary[i].latitude * boundary[j].longitude
            area -= boundary[j].latitude * boundary[i].longitude
        }

        return abs(area) > 0.0000001 // Small epsilon for floating point comparison
    }

    // MARK: - Invite Code Validation

    /// Validates an invite code format
    /// - Parameter code: The invite code to validate
    /// - Returns: true if the format is valid, false otherwise
    static func isValidInviteCodeFormat(_ code: String) -> Bool {
        let uppercased = code.uppercased()

        guard uppercased.count == Constants.inviteCodeLength else {
            return false
        }

        let validCharacters = CharacterSet(charactersIn: Constants.inviteCodeCharacters)
        return uppercased.unicodeScalars.allSatisfy { validCharacters.contains($0) }
    }

    // MARK: - Group Data Validation

    /// Validates all group data before creation
    /// - Parameters:
    ///   - name: Group name
    ///   - boundary: Boundary coordinates
    ///   - centerLatitude: Center latitude
    ///   - centerLongitude: Center longitude
    /// - Returns: ValidationResult indicating if all data is valid
    static func validateGroupData(
        name: String,
        boundary: [Coordinate],
        centerLatitude: Double,
        centerLongitude: Double
    ) -> ValidationResult {
        // Validate name
        let nameResult = validateGroupName(name)
        if !nameResult.isValid {
            return nameResult
        }

        // Validate boundary
        let boundaryResult = validateBoundary(boundary)
        if !boundaryResult.isValid {
            return boundaryResult
        }

        // Validate center coordinates
        if !isValidLatitude(centerLatitude) {
            return .invalid(.invalidBoundary(reason: "Center latitude is invalid"))
        }

        if !isValidLongitude(centerLongitude) {
            return .invalid(.invalidBoundary(reason: "Center longitude is invalid"))
        }

        return .valid
    }

    // MARK: - Sanitization

    /// Sanitizes a display name by trimming whitespace
    /// - Parameter name: The name to sanitize
    /// - Returns: Sanitized name
    static func sanitizeDisplayName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sanitizes a group name by trimming whitespace
    /// - Parameter name: The name to sanitize
    /// - Returns: Sanitized name
    static func sanitizeGroupName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sanitizes an invite code by uppercasing and trimming
    /// - Parameter code: The code to sanitize
    /// - Returns: Sanitized code
    static func sanitizeInviteCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
