//
//  AppError.swift
//  WhosThereios
//
//  Created by Claude on 1/16/26.
//

import Foundation

/// Unified error type for the Who's There app
enum AppError: LocalizedError {

    // MARK: - Authentication Errors
    case notAuthenticated
    case authenticationFailed(underlying: Error?)
    case signOutFailed(underlying: Error?)

    // MARK: - User Errors
    case userNotFound
    case userCreationFailed(underlying: Error?)
    case userUpdateFailed(underlying: Error?)
    case invalidDisplayName(reason: String)

    // MARK: - Group Errors
    case groupNotFound
    case groupCreationFailed(underlying: Error?)
    case groupUpdateFailed(underlying: Error?)
    case groupDeletionFailed(underlying: Error?)
    case notGroupOwner
    case notGroupMember
    case alreadyGroupMember
    case invalidGroupName(reason: String)
    case invalidBoundary(reason: String)
    case invalidInviteCode

    // MARK: - Presence Errors
    case presenceUpdateFailed(underlying: Error?)
    case presenceFetchFailed(underlying: Error?)

    // MARK: - Location Errors
    case locationPermissionDenied
    case locationPermissionRestricted
    case locationUnavailable
    case geofencingNotSupported
    case tooManyGeofences

    // MARK: - Network Errors
    case networkUnavailable
    case requestTimeout
    case serverError(underlying: Error?)

    // MARK: - Validation Errors
    case validationFailed(field: String, reason: String)

    // MARK: - LocalizedError Implementation

    var errorDescription: String? {
        switch self {
        // Authentication
        case .notAuthenticated:
            return "You must be signed in to perform this action."
        case .authenticationFailed(let error):
            return "Authentication failed: \(error?.localizedDescription ?? "Unknown error")"
        case .signOutFailed(let error):
            return "Failed to sign out: \(error?.localizedDescription ?? "Unknown error")"

        // User
        case .userNotFound:
            return "User not found."
        case .userCreationFailed(let error):
            return "Failed to create user: \(error?.localizedDescription ?? "Unknown error")"
        case .userUpdateFailed(let error):
            return "Failed to update user: \(error?.localizedDescription ?? "Unknown error")"
        case .invalidDisplayName(let reason):
            return "Invalid display name: \(reason)"

        // Group
        case .groupNotFound:
            return "Group not found."
        case .groupCreationFailed(let error):
            return "Failed to create group: \(error?.localizedDescription ?? "Unknown error")"
        case .groupUpdateFailed(let error):
            return "Failed to update group: \(error?.localizedDescription ?? "Unknown error")"
        case .groupDeletionFailed(let error):
            return "Failed to delete group: \(error?.localizedDescription ?? "Unknown error")"
        case .notGroupOwner:
            return "You must be the group owner to perform this action."
        case .notGroupMember:
            return "You must be a group member to perform this action."
        case .alreadyGroupMember:
            return "You are already a member of this group."
        case .invalidGroupName(let reason):
            return "Invalid group name: \(reason)"
        case .invalidBoundary(let reason):
            return "Invalid boundary: \(reason)"
        case .invalidInviteCode:
            return "Invalid or expired invite code."

        // Presence
        case .presenceUpdateFailed(let error):
            return "Failed to update presence: \(error?.localizedDescription ?? "Unknown error")"
        case .presenceFetchFailed(let error):
            return "Failed to fetch presence: \(error?.localizedDescription ?? "Unknown error")"

        // Location
        case .locationPermissionDenied:
            return "Location permission denied. Please enable location access in Settings."
        case .locationPermissionRestricted:
            return "Location access is restricted on this device."
        case .locationUnavailable:
            return "Unable to determine your location."
        case .geofencingNotSupported:
            return "Geofencing is not supported on this device."
        case .tooManyGeofences:
            return "Too many location boundaries being monitored. iOS supports a maximum of 20."

        // Network
        case .networkUnavailable:
            return "No network connection. Please check your internet connection."
        case .requestTimeout:
            return "Request timed out. Please try again."
        case .serverError(let error):
            return "Server error: \(error?.localizedDescription ?? "Unknown error")"

        // Validation
        case .validationFailed(let field, let reason):
            return "Invalid \(field): \(reason)"
        }
    }

    var failureReason: String? {
        switch self {
        case .notAuthenticated:
            return "No authenticated user session found."
        case .locationPermissionDenied:
            return "The user denied location permission."
        case .notGroupOwner:
            return "The current user is not the owner of this group."
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue."
        case .locationPermissionDenied, .locationPermissionRestricted:
            return "Go to Settings > Privacy > Location Services to enable location access."
        case .networkUnavailable:
            return "Check your WiFi or cellular connection and try again."
        case .invalidInviteCode:
            return "Ask the group owner for a new invite code."
        default:
            return nil
        }
    }

    /// User-friendly short message for UI display
    var userMessage: String {
        switch self {
        case .notAuthenticated:
            return "Please sign in"
        case .authenticationFailed:
            return "Sign in failed"
        case .userNotFound, .groupNotFound:
            return "Not found"
        case .notGroupOwner, .notGroupMember:
            return "Permission denied"
        case .locationPermissionDenied, .locationPermissionRestricted:
            return "Location access needed"
        case .networkUnavailable:
            return "No connection"
        case .invalidInviteCode:
            return "Invalid code"
        case .invalidBoundary(let reason):
            return reason
        case .invalidGroupName(let reason):
            return reason
        case .invalidDisplayName(let reason):
            return reason
        case .groupCreationFailed:
            return "Failed to create group"
        case .groupUpdateFailed:
            return "Failed to update group"
        case .groupDeletionFailed:
            return "Failed to delete group"
        case .alreadyGroupMember:
            return "Already a member"
        default:
            return "Something went wrong"
        }
    }

    /// Whether this error should be logged for debugging
    var shouldLog: Bool {
        switch self {
        case .notAuthenticated, .locationPermissionDenied, .locationPermissionRestricted:
            return false // Expected user states, not errors
        default:
            return true
        }
    }
}

// MARK: - Result Type Alias

typealias AppResult<T> = Result<T, AppError>
