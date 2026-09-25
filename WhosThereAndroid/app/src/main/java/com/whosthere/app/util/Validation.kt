package com.whosthere.app.util

import com.whosthere.app.model.Coordinate
import kotlin.math.abs
import kotlin.math.sin

/**
 * Input validation utilities for the Who's There app.
 * Ported from iOS Validation.swift.
 */
object Validation {

    // region Validation Constants

    object Constants {
        // Display Name
        const val DISPLAY_NAME_MIN_LENGTH = 1
        const val DISPLAY_NAME_MAX_LENGTH = 50

        // Group Name
        const val GROUP_NAME_MIN_LENGTH = 1
        const val GROUP_NAME_MAX_LENGTH = 100

        // Emoji
        const val EMOJI_MAX_LENGTH = 10

        // Boundary
        const val BOUNDARY_MIN_POINTS = 3
        const val BOUNDARY_MAX_POINTS = 100

        // Area limits (in square meters)
        const val AREA_MIN_SQUARE_METERS: Double = 100.0          // ~10m x 10m - minimum useful size
        const val AREA_MAX_SQUARE_METERS: Double = 1_000_000.0    // 1 km^2 - about 247 acres, max size

        // Coordinate ranges
        const val LATITUDE_MIN: Double = -90.0
        const val LATITUDE_MAX: Double = 90.0
        const val LONGITUDE_MIN: Double = -180.0
        const val LONGITUDE_MAX: Double = 180.0

        // Invite Code
        const val INVITE_CODE_LENGTH = 6
        const val INVITE_CODE_CHARACTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    }

    // endregion

    // region Validation Result

    data class ValidationResult(
        val isValid: Boolean,
        val error: AppError? = null
    ) {
        companion object {
            val valid = ValidationResult(isValid = true, error = null)

            fun invalid(error: AppError): ValidationResult =
                ValidationResult(isValid = false, error = error)
        }
    }

    // endregion

    // region Display Name Validation

    /**
     * Validates a display name.
     * @param name The display name to validate.
     * @return ValidationResult indicating if the name is valid.
     */
    fun validateDisplayName(name: String): ValidationResult {
        val trimmed = name.trim()

        if (trimmed.isEmpty()) {
            return ValidationResult.invalid(
                AppError.InvalidDisplayName("Name cannot be empty")
            )
        }

        if (trimmed.length < Constants.DISPLAY_NAME_MIN_LENGTH) {
            return ValidationResult.invalid(
                AppError.InvalidDisplayName("Name must be at least ${Constants.DISPLAY_NAME_MIN_LENGTH} character")
            )
        }

        if (trimmed.length > Constants.DISPLAY_NAME_MAX_LENGTH) {
            return ValidationResult.invalid(
                AppError.InvalidDisplayName("Name must be ${Constants.DISPLAY_NAME_MAX_LENGTH} characters or less")
            )
        }

        // Check for invalid characters (only allow letters, numbers, spaces, and common punctuation)
        val allowedPattern = Regex("^[\\p{L}\\p{N}\\s\\-_.']+$")
        if (!allowedPattern.matches(trimmed)) {
            return ValidationResult.invalid(
                AppError.InvalidDisplayName("Name contains invalid characters")
            )
        }

        // Check for inappropriate language
        if (containsProfanity(trimmed) != null) {
            return ValidationResult.invalid(
                AppError.InvalidDisplayName("Name contains inappropriate language")
            )
        }

        return ValidationResult.valid
    }

    // endregion

    // region Group Name Validation

    /**
     * Validates a group name.
     * @param name The group name to validate.
     * @return ValidationResult indicating if the name is valid.
     */
    fun validateGroupName(name: String): ValidationResult {
        val trimmed = name.trim()

        if (trimmed.isEmpty()) {
            return ValidationResult.invalid(
                AppError.InvalidGroupName("Name cannot be empty")
            )
        }

        if (trimmed.length < Constants.GROUP_NAME_MIN_LENGTH) {
            return ValidationResult.invalid(
                AppError.InvalidGroupName("Name must be at least ${Constants.GROUP_NAME_MIN_LENGTH} character")
            )
        }

        if (trimmed.length > Constants.GROUP_NAME_MAX_LENGTH) {
            return ValidationResult.invalid(
                AppError.InvalidGroupName("Name must be ${Constants.GROUP_NAME_MAX_LENGTH} characters or less")
            )
        }

        // Check for inappropriate language
        if (containsProfanity(trimmed) != null) {
            return ValidationResult.invalid(
                AppError.InvalidGroupName("Name contains inappropriate language")
            )
        }

        return ValidationResult.valid
    }

    // endregion

    // region Coordinate Validation

    /**
     * Validates a latitude value.
     * @param latitude The latitude to validate.
     * @return true if valid, false otherwise.
     */
    fun isValidLatitude(latitude: Double): Boolean =
        latitude in Constants.LATITUDE_MIN..Constants.LATITUDE_MAX

    /**
     * Validates a longitude value.
     * @param longitude The longitude to validate.
     * @return true if valid, false otherwise.
     */
    fun isValidLongitude(longitude: Double): Boolean =
        longitude in Constants.LONGITUDE_MIN..Constants.LONGITUDE_MAX

    /**
     * Validates a coordinate pair.
     * @param latitude The latitude to validate.
     * @param longitude The longitude to validate.
     * @return true if valid, false otherwise.
     */
    fun isValidCoordinate(latitude: Double, longitude: Double): Boolean =
        isValidLatitude(latitude) && isValidLongitude(longitude)

    // endregion

    // region Boundary Validation

    /**
     * Validates a boundary (array of coordinates forming a polygon).
     * @param boundary Array of Coordinate objects.
     * @return ValidationResult indicating if the boundary is valid.
     */
    fun validateBoundary(boundary: List<Coordinate>): ValidationResult {
        if (boundary.size < Constants.BOUNDARY_MIN_POINTS) {
            return ValidationResult.invalid(
                AppError.InvalidBoundary("Boundary must have at least ${Constants.BOUNDARY_MIN_POINTS} points")
            )
        }

        if (boundary.size > Constants.BOUNDARY_MAX_POINTS) {
            return ValidationResult.invalid(
                AppError.InvalidBoundary("Boundary cannot have more than ${Constants.BOUNDARY_MAX_POINTS} points")
            )
        }

        // Validate each coordinate
        for ((index, coord) in boundary.withIndex()) {
            if (!isValidLatitude(coord.latitude)) {
                return ValidationResult.invalid(
                    AppError.InvalidBoundary("Point ${index + 1} has invalid latitude")
                )
            }
            if (!isValidLongitude(coord.longitude)) {
                return ValidationResult.invalid(
                    AppError.InvalidBoundary("Point ${index + 1} has invalid longitude")
                )
            }
        }

        // Check for duplicate consecutive points
        for (i in 0 until boundary.size - 1) {
            if (boundary[i].latitude == boundary[i + 1].latitude &&
                boundary[i].longitude == boundary[i + 1].longitude
            ) {
                return ValidationResult.invalid(
                    AppError.InvalidBoundary("Boundary contains duplicate consecutive points")
                )
            }
        }

        // Check that polygon has non-zero area (not all points collinear)
        if (!hasNonZeroArea(boundary)) {
            return ValidationResult.invalid(
                AppError.InvalidBoundary("Boundary points form a line, not an area")
            )
        }

        // Validate area size
        val areaResult = validateBoundaryArea(boundary)
        if (!areaResult.isValid) {
            return areaResult
        }

        return ValidationResult.valid
    }

    // endregion

    // region Polygon Area Calculation (Shoelace Formula)

    /**
     * Validates that the boundary area is within acceptable limits.
     * @param boundary Array of Coordinate objects.
     * @return ValidationResult indicating if the area size is valid.
     */
    fun validateBoundaryArea(boundary: List<Coordinate>): ValidationResult {
        val areaInSquareMeters = calculatePolygonArea(boundary)

        if (areaInSquareMeters < Constants.AREA_MIN_SQUARE_METERS) {
            return ValidationResult.invalid(
                AppError.InvalidBoundary("Area is too small. Minimum size is about 10m x 10m.")
            )
        }

        if (areaInSquareMeters > Constants.AREA_MAX_SQUARE_METERS) {
            val maxKm = (Constants.AREA_MAX_SQUARE_METERS / 1_000_000).toInt()
            return ValidationResult.invalid(
                AppError.InvalidBoundary("Area is too large. Maximum size is $maxKm km\u00B2 (about 247 acres).")
            )
        }

        return ValidationResult.valid
    }

    /**
     * Calculates the area of a polygon in square meters using the Shoelace formula
     * with geodesic correction for Earth's curvature.
     *
     * The Shoelace formula sums cross-products of consecutive vertex pairs to
     * compute the signed area of a polygon. Here it operates on lat/lon converted
     * to radians, then scales by Earth's radius squared to produce square meters.
     * Accurate for small-to-medium polygons; for continent-scale areas, a full
     * spherical-excess integration would be needed.
     *
     * @param boundary Array of Coordinate objects.
     * @return Area in square meters.
     */
    fun calculatePolygonArea(boundary: List<Coordinate>): Double {
        if (boundary.size < 3) return 0.0

        // Use the Shoelace formula with latitude correction
        // This provides reasonable accuracy for small to medium polygons
        var area = 0.0
        val n = boundary.size

        for (i in 0 until n) {
            val j = (i + 1) % n

            // Convert to radians
            val lat1 = boundary[i].latitude * Math.PI / 180.0
            val lat2 = boundary[j].latitude * Math.PI / 180.0
            val lon1 = boundary[i].longitude * Math.PI / 180.0
            val lon2 = boundary[j].longitude * Math.PI / 180.0

            // Spherical excess formula component
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        // Earth's radius in meters
        val earthRadius = 6_371_000.0

        // Calculate absolute area
        area = abs(area * earthRadius * earthRadius / 2.0)

        return area
    }

    /**
     * Checks if a polygon has non-zero area using the shoelace formula.
     */
    private fun hasNonZeroArea(boundary: List<Coordinate>): Boolean {
        if (boundary.size < 3) return false

        var area = 0.0
        val n = boundary.size

        for (i in 0 until n) {
            val j = (i + 1) % n
            area += boundary[i].latitude * boundary[j].longitude
            area -= boundary[j].latitude * boundary[i].longitude
        }

        return abs(area) > 0.0000001 // Small epsilon for floating point comparison
    }

    // endregion

    // region Invite Code Validation

    /**
     * Validates an invite code format.
     * @param code The invite code to validate.
     * @return true if the format is valid, false otherwise.
     */
    fun isValidInviteCodeFormat(code: String): Boolean {
        val uppercased = code.uppercase()

        if (uppercased.length != Constants.INVITE_CODE_LENGTH) {
            return false
        }

        return uppercased.all { it in Constants.INVITE_CODE_CHARACTERS }
    }

    // endregion

    // region Group Data Validation

    /**
     * Validates all group data before creation.
     * @param name Group name.
     * @param boundary Boundary coordinates.
     * @param centerLatitude Center latitude.
     * @param centerLongitude Center longitude.
     * @return ValidationResult indicating if all data is valid.
     */
    fun validateGroupData(
        name: String,
        boundary: List<Coordinate>,
        centerLatitude: Double,
        centerLongitude: Double
    ): ValidationResult {
        // Validate name
        val nameResult = validateGroupName(name)
        if (!nameResult.isValid) {
            return nameResult
        }

        // Validate boundary
        val boundaryResult = validateBoundary(boundary)
        if (!boundaryResult.isValid) {
            return boundaryResult
        }

        // Validate center coordinates
        if (!isValidLatitude(centerLatitude)) {
            return ValidationResult.invalid(
                AppError.InvalidBoundary("Center latitude is invalid")
            )
        }

        if (!isValidLongitude(centerLongitude)) {
            return ValidationResult.invalid(
                AppError.InvalidBoundary("Center longitude is invalid")
            )
        }

        return ValidationResult.valid
    }

    // endregion

    // region Profanity Filter

    /**
     * Checks if a string contains inappropriate language.
     * @param text The text to check.
     * @return The offending word if found, null if clean.
     */
    fun containsProfanity(text: String): String? {
        val normalized = normalizeProfanity(text)
        for (word in ProfanityList.words) {
            // Check for whole-word matches using word boundaries
            // This prevents false positives like "class" matching "ass"
            val pattern = "\\b${Regex.escape(word)}\\b"
            val regex = Regex(pattern, RegexOption.IGNORE_CASE)
            if (regex.containsMatchIn(normalized)) {
                return word
            }
        }
        return null
    }

    /**
     * Normalizes common character substitutions used to bypass filters.
     * e.g., "@ss" -> "ass", "sh1t" -> "shit"
     */
    private fun normalizeProfanity(text: String): String {
        var result = text.lowercase()

        val substitutions = mapOf(
            '@' to 'a',
            '0' to 'o',
            '1' to 'i',
            '3' to 'e',
            '$' to 's',
            '5' to 's',
            '!' to 'i'
        )

        result = result.map { substitutions[it] ?: it }.joinToString("")

        // Collapse repeated characters: "fuuuck" -> "fuck"
        val collapsed = StringBuilder()
        var lastChar: Char? = null
        var repeatCount = 0

        for (char in result) {
            if (char == lastChar) {
                repeatCount++
                if (repeatCount < 2) {
                    collapsed.append(char)
                }
            } else {
                collapsed.append(char)
                repeatCount = 0
            }
            lastChar = char
        }

        return collapsed.toString()
    }

    // endregion

    // region Input Sanitization

    /**
     * Sanitizes a display name by trimming whitespace.
     * @param name The name to sanitize.
     * @return Sanitized name.
     */
    fun sanitizeDisplayName(name: String): String = name.trim()

    /**
     * Sanitizes a group name by trimming whitespace.
     * @param name The name to sanitize.
     * @return Sanitized name.
     */
    fun sanitizeGroupName(name: String): String = name.trim()

    /**
     * Sanitizes an invite code by uppercasing and trimming.
     * @param code The code to sanitize.
     * @return Sanitized code.
     */
    fun sanitizeInviteCode(code: String): String = code.trim().uppercase()

    // endregion
}
