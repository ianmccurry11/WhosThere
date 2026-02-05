//
//  AuthEdgeCaseHandler.swift
//  WhosThereios
//
//  Created by Claude on 2/5/26.
//

import Foundation
import FirebaseAuth

// MARK: - Auth Recovery Action

/// Defines possible recovery actions for auth errors
enum AuthRecoveryAction: Equatable {
    case retry
    case reauthenticate
    case clearAndRestart
    case showError(String)
    case waitAndRetry(seconds: Int)
}

// MARK: - Auth Session State

/// Represents the current authentication session state
enum AuthSessionState: String {
    case valid = "Valid"
    case expiringSoon = "Expiring Soon"
    case expired = "Expired"
    case noToken = "No Token"
    case unknown = "Unknown"
}

// MARK: - Auth Session Info

/// Contains detailed information about the current auth session
struct AuthSessionInfo {
    let userId: String?
    let isAnonymous: Bool
    let providerIds: [String]
    let sessionState: AuthSessionState
    let tokenExpirationDate: Date?
    let timeUntilExpiration: TimeInterval?
    let creationDate: Date?
    let lastSignInDate: Date?
    let tokenClaims: [String: String]

    var summary: [String: String] {
        var info: [String: String] = [:]
        info["User ID"] = userId ?? "None"
        info["Anonymous"] = isAnonymous ? "Yes" : "No"
        info["Providers"] = providerIds.isEmpty ? "None" : providerIds.joined(separator: ", ")
        info["Session"] = sessionState.rawValue

        if let exp = tokenExpirationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .medium
            info["Token Expires"] = formatter.string(from: exp)
        }

        if let ttl = timeUntilExpiration {
            let minutes = Int(ttl / 60)
            if minutes > 0 {
                info["Expires In"] = "\(minutes) min"
            } else {
                info["Expires In"] = "Expired"
            }
        }

        if let created = creationDate {
            let formatter = RelativeDateTimeFormatter()
            info["Account Created"] = formatter.localizedString(for: created, relativeTo: Date())
        }

        if let lastSignIn = lastSignInDate {
            let formatter = RelativeDateTimeFormatter()
            info["Last Sign-In"] = formatter.localizedString(for: lastSignIn, relativeTo: Date())
        }

        return info
    }
}

// MARK: - AuthService Edge-Case Extension

extension AuthService {

    // MARK: - Token Analysis

    /// Get the current Firebase ID token
    func getIDToken(forceRefresh: Bool = false) async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw AuthEdgeCaseError.noCurrentUser
        }
        return try await withCheckedThrowingContinuation { continuation in
            user.getIDTokenForcingRefresh(forceRefresh) { token, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let token = token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: AuthEdgeCaseError.tokenDecodeFailed)
                }
            }
        }
    }

    /// Analyze the current token using JWTAnalyzer
    func analyzeCurrentToken() async -> JWTAnalyzer.TokenInfo? {
        guard let token = try? await getIDToken() else { return nil }
        return JWTAnalyzer.decode(token)
    }

    /// Check if the current token is expiring soon
    func isTokenExpiringSoon(withinMinutes minutes: Int = 5) async -> Bool {
        guard let token = try? await getIDToken() else { return true }
        return JWTAnalyzer.isExpiringSoon(token, withinMinutes: minutes)
    }

    /// Get the token expiration date
    func getTokenExpirationDate() async -> Date? {
        guard let token = try? await getIDToken() else { return nil }
        return JWTAnalyzer.decode(token)?.expirationDate
    }

    // MARK: - Session Management

    /// Get detailed session information
    func getSessionInfo() async -> AuthSessionInfo {
        let user = Auth.auth().currentUser

        var sessionState: AuthSessionState = .unknown
        var tokenExpiration: Date?
        var timeUntilExp: TimeInterval?
        var claims: [String: String] = [:]

        if let user = user {
            if let token = try? await getIDToken(),
               let info = JWTAnalyzer.decode(token) {
                tokenExpiration = info.expirationDate
                timeUntilExp = info.timeUntilExpiration

                if info.isExpired {
                    sessionState = .expired
                } else if info.isExpiringSoon {
                    sessionState = .expiringSoon
                } else {
                    sessionState = .valid
                }

                // Extract safe claims
                for (key, value) in info.payload {
                    if let strValue = value as? String {
                        claims[key] = strValue
                    } else if let numValue = value as? NSNumber {
                        claims[key] = numValue.stringValue
                    }
                }
            } else {
                sessionState = .noToken
            }
        } else {
            sessionState = .noToken
        }

        return AuthSessionInfo(
            userId: user?.uid,
            isAnonymous: user?.isAnonymous ?? true,
            providerIds: user?.providerData.map { $0.providerID } ?? [],
            sessionState: sessionState,
            tokenExpirationDate: tokenExpiration,
            timeUntilExpiration: timeUntilExp,
            creationDate: user?.metadata.creationDate,
            lastSignInDate: user?.metadata.lastSignInDate,
            tokenClaims: claims
        )
    }

    /// Force refresh the current token
    func refreshToken() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthEdgeCaseError.noCurrentUser
        }

        let startTime = Date()
        do {
            _ = try await getIDToken(forceRefresh: true)
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logAuthOperation(method: "tokenRefresh", durationMs: duration, success: true)
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logAuthOperation(method: "tokenRefresh", durationMs: duration, success: false, error: error)
            throw error
        }
    }

    /// Refresh token if it's expiring soon
    func refreshTokenIfNeeded() async throws {
        guard let token = try? await getIDToken() else {
            throw AuthEdgeCaseError.noCurrentUser
        }

        if JWTAnalyzer.isExpiringSoon(token) {
            try await refreshToken()
        }
    }

    // MARK: - Error Recovery

    /// Determine the best recovery action for an auth error
    func recoverFromAuthError(_ error: Error) -> AuthRecoveryAction {
        let nsError = error as NSError

        // Firebase Auth error codes
        switch nsError.code {
        case AuthErrorCode.networkError.rawValue:
            return .waitAndRetry(seconds: 5)

        case AuthErrorCode.tooManyRequests.rawValue:
            return .waitAndRetry(seconds: 30)

        case AuthErrorCode.userTokenExpired.rawValue,
             AuthErrorCode.invalidUserToken.rawValue:
            return .reauthenticate

        case AuthErrorCode.userDisabled.rawValue:
            return .showError("This account has been disabled. Please contact support.")

        case AuthErrorCode.userNotFound.rawValue:
            return .clearAndRestart

        case AuthErrorCode.requiresRecentLogin.rawValue:
            return .reauthenticate

        case AuthErrorCode.invalidCredential.rawValue,
             AuthErrorCode.wrongPassword.rawValue:
            return .showError("Invalid credentials. Please try again.")

        case AuthErrorCode.accountExistsWithDifferentCredential.rawValue:
            return .showError("An account already exists with a different sign-in method.")

        case AuthErrorCode.credentialAlreadyInUse.rawValue:
            return .showError("This credential is already associated with another account.")

        default:
            // Generic retry for unknown errors
            return .retry
        }
    }

    /// Execute a recovery action
    func executeRecovery(_ action: AuthRecoveryAction) async {
        switch action {
        case .retry:
            // Re-attempt the last operation (caller handles this)
            break

        case .reauthenticate:
            // Sign out and let user re-authenticate
            signOut()
            errorMessage = "Your session has expired. Please sign in again."

        case .clearAndRestart:
            // Clear everything and start fresh
            signOut()
            errorMessage = "Please sign in to continue."

        case .showError(let message):
            errorMessage = message

        case .waitAndRetry(let seconds):
            errorMessage = "Please wait \(seconds) seconds and try again."
        }

        analyticsService.trackError(
            errorType: "auth_recovery",
            context: "AuthService.executeRecovery",
            message: String(describing: action)
        )
    }

    // MARK: - Account Upgrade

    /// Check if the current user is anonymous and can be upgraded
    var canUpgradeAccount: Bool {
        return Auth.auth().currentUser?.isAnonymous == true
    }

    /// Reload the current user's data from Firebase
    func reloadUser() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthEdgeCaseError.noCurrentUser
        }

        try await user.reload()

        await MainActor.run {
            self.user = Auth.auth().currentUser
            self.isAuthenticated = Auth.auth().currentUser != nil
        }
    }
}

// MARK: - Auth Edge-Case Errors

enum AuthEdgeCaseError: LocalizedError {
    case noCurrentUser
    case tokenDecodeFailed
    case tokenExpired
    case upgradeNotAvailable
    case linkingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCurrentUser:
            return "No authenticated user found"
        case .tokenDecodeFailed:
            return "Failed to decode authentication token"
        case .tokenExpired:
            return "Authentication token has expired"
        case .upgradeNotAvailable:
            return "Account upgrade is not available for this user"
        case .linkingFailed(let reason):
            return "Account linking failed: \(reason)"
        }
    }
}
