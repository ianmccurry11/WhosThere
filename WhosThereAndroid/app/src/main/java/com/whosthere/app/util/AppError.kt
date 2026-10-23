package com.whosthere.app.util

/**
 * Unified error type for the Who's There app.
 * Ported from iOS AppError.swift as a Kotlin sealed class.
 */
sealed class AppError : Exception() {

    // region Authentication Errors

    object NotAuthenticated : AppError()
    data class AuthenticationFailed(val underlying: Throwable? = null) : AppError()
    data class SignOutFailed(val underlying: Throwable? = null) : AppError()

    // endregion

    // region User Errors

    object UserNotFound : AppError()
    data class UserCreationFailed(val underlying: Throwable? = null) : AppError()
    data class UserUpdateFailed(val underlying: Throwable? = null) : AppError()
    data class InvalidDisplayName(val reason: String) : AppError()

    // endregion

    // region Group Errors

    object GroupNotFound : AppError()
    data class GroupCreationFailed(val underlying: Throwable? = null) : AppError()
    data class GroupUpdateFailed(val underlying: Throwable? = null) : AppError()
    data class GroupDeletionFailed(val underlying: Throwable? = null) : AppError()
    object NotGroupOwner : AppError()
    object NotGroupMember : AppError()
    object AlreadyGroupMember : AppError()
    data class InvalidGroupName(val reason: String) : AppError()
    data class InvalidBoundary(val reason: String) : AppError()
    object InvalidInviteCode : AppError()

    // endregion

    // region Presence Errors

    data class PresenceUpdateFailed(val underlying: Throwable? = null) : AppError()
    data class PresenceFetchFailed(val underlying: Throwable? = null) : AppError()

    // endregion

    // region Location Errors

    object LocationPermissionDenied : AppError()
    object LocationPermissionRestricted : AppError()
    object LocationUnavailable : AppError()
    object GeofencingNotSupported : AppError()
    object TooManyGeofences : AppError()

    // endregion

    // region Network Errors

    object NetworkUnavailable : AppError()
    object RequestTimeout : AppError()
    data class ServerError(val underlying: Throwable? = null) : AppError()

    // endregion

    // region Store Errors

    data class PurchaseFailed(val underlying: Throwable? = null) : AppError()
    object PurchaseCancelled : AppError()
    object PurchasePending : AppError()
    data class RestoreFailed(val underlying: Throwable? = null) : AppError()

    // endregion

    // region Validation Errors

    data class ValidationFailed(val field: String, val reason: String) : AppError()

    // endregion

    // region Properties

    /** Detailed error description for logging */
    val errorDescription: String
        get() = when (this) {
            // Authentication
            is NotAuthenticated ->
                "You must be signed in to perform this action."
            is AuthenticationFailed ->
                "Authentication failed: ${underlying?.message ?: "Unknown error"}"
            is SignOutFailed ->
                "Failed to sign out: ${underlying?.message ?: "Unknown error"}"

            // User
            is UserNotFound ->
                "User not found."
            is UserCreationFailed ->
                "Failed to create user: ${underlying?.message ?: "Unknown error"}"
            is UserUpdateFailed ->
                "Failed to update user: ${underlying?.message ?: "Unknown error"}"
            is InvalidDisplayName ->
                "Invalid display name: $reason"

            // Group
            is GroupNotFound ->
                "Group not found."
            is GroupCreationFailed ->
                "Failed to create group: ${underlying?.message ?: "Unknown error"}"
            is GroupUpdateFailed ->
                "Failed to update group: ${underlying?.message ?: "Unknown error"}"
            is GroupDeletionFailed ->
                "Failed to delete group: ${underlying?.message ?: "Unknown error"}"
            is NotGroupOwner ->
                "You must be the group owner to perform this action."
            is NotGroupMember ->
                "You must be a group member to perform this action."
            is AlreadyGroupMember ->
                "You are already a member of this group."
            is InvalidGroupName ->
                "Invalid group name: $reason"
            is InvalidBoundary ->
                "Invalid boundary: $reason"
            is InvalidInviteCode ->
                "Invalid or expired invite code."

            // Presence
            is PresenceUpdateFailed ->
                "Failed to update presence: ${underlying?.message ?: "Unknown error"}"
            is PresenceFetchFailed ->
                "Failed to fetch presence: ${underlying?.message ?: "Unknown error"}"

            // Location
            is LocationPermissionDenied ->
                "Location permission denied. Please enable location access in Settings."
            is LocationPermissionRestricted ->
                "Location access is restricted on this device."
            is LocationUnavailable ->
                "Unable to determine your location."
            is GeofencingNotSupported ->
                "Geofencing is not supported on this device."
            is TooManyGeofences ->
                "Too many location boundaries being monitored. Android supports a maximum of 100."

            // Network
            is NetworkUnavailable ->
                "No network connection. Please check your internet connection."
            is RequestTimeout ->
                "Request timed out. Please try again."
            is ServerError ->
                "Server error: ${underlying?.message ?: "Unknown error"}"

            // Store
            is PurchaseFailed ->
                "Purchase failed: ${underlying?.message ?: "Unknown error"}"
            is PurchaseCancelled ->
                "Purchase was cancelled."
            is PurchasePending ->
                "Purchase is pending approval."
            is RestoreFailed ->
                "Failed to restore purchases: ${underlying?.message ?: "Unknown error"}"

            // Validation
            is ValidationFailed ->
                "Invalid $field: $reason"
        }

    /** User-friendly short message for UI display */
    val userMessage: String
        get() = when (this) {
            is NotAuthenticated -> "Please sign in"
            is AuthenticationFailed -> "Sign in failed"
            is UserNotFound, is GroupNotFound -> "Not found"
            is NotGroupOwner, is NotGroupMember -> "Permission denied"
            is LocationPermissionDenied, is LocationPermissionRestricted -> "Location access needed"
            is NetworkUnavailable -> "No connection"
            is InvalidInviteCode -> "Invalid code"
            is InvalidBoundary -> reason
            is InvalidGroupName -> reason
            is InvalidDisplayName -> reason
            is GroupCreationFailed -> "Failed to create group"
            is GroupUpdateFailed -> "Failed to update group"
            is GroupDeletionFailed -> "Failed to delete group"
            is AlreadyGroupMember -> "Already a member"
            is PurchaseFailed -> "Purchase failed"
            is PurchaseCancelled -> "Purchase cancelled"
            is PurchasePending -> "Purchase pending approval"
            is RestoreFailed -> "Restore failed"
            else -> "Something went wrong"
        }

    /** Whether this error should be logged for debugging */
    val shouldLog: Boolean
        get() = when (this) {
            is NotAuthenticated,
            is LocationPermissionDenied,
            is LocationPermissionRestricted,
            is PurchaseCancelled -> false // Expected user states, not errors
            else -> true
        }

    // endregion

    override val message: String
        get() = errorDescription
}

// Result type alias matching the iOS AppResult<T> pattern.
// Kotlin's Result<T> uses Throwable, so AppError (which extends Exception) works directly.
typealias AppResult<T> = Result<T>
