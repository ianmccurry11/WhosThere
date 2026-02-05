//
//  AuthEdgeCaseTests.swift
//  WhosThereiosTests
//
//  Created by Claude on 2/5/26.
//

import XCTest
@testable import WhosThereios

// MARK: - JWT Analyzer Tests

final class JWTAnalyzerTests: XCTestCase {

    // MARK: - Token Creation and Decoding

    func testCreateAndDecodeTestToken() {
        let token = JWTAnalyzer.createTestToken(
            subject: "user-123",
            issuer: "test-app",
            expiresIn: 3600
        )

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.subject, "user-123")
        XCTAssertEqual(info?.issuer, "test-app")
        XCTAssertNotNil(info?.expirationDate)
        XCTAssertNotNil(info?.issuedAt)
    }

    func testDecodeTokenHeader() {
        let token = JWTAnalyzer.createTestToken()

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.header["alg"] as? String, "none")
        XCTAssertEqual(info?.header["typ"] as? String, "JWT")
    }

    func testDecodeTokenPayload() {
        let token = JWTAnalyzer.createTestToken(
            subject: "sub-123",
            issuer: "iss-test",
            additionalClaims: ["aud": "test-audience", "custom": "value"]
        )

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.payload["sub"] as? String, "sub-123")
        XCTAssertEqual(info?.payload["iss"] as? String, "iss-test")
        XCTAssertEqual(info?.payload["aud"] as? String, "test-audience")
        XCTAssertEqual(info?.payload["custom"] as? String, "value")
    }

    // MARK: - Expiration Tests

    func testValidTokenNotExpired() {
        let token = JWTAnalyzer.createTestToken(expiresIn: 3600)

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertFalse(info!.isExpired)
        XCTAssertGreaterThan(info!.timeUntilExpiration, 0)
    }

    func testExpiredTokenIsExpired() {
        let token = JWTAnalyzer.createExpiredTestToken(expiredSinceSeconds: 3600)

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertTrue(info!.isExpired)
        XCTAssertLessThan(info!.timeUntilExpiration, 0)
    }

    func testTokenExpiringSoon() {
        // Token expiring in 2 minutes (< 5 min threshold)
        let token = JWTAnalyzer.createTestToken(expiresIn: 120)

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertFalse(info!.isExpired)
        XCTAssertTrue(info!.isExpiringSoon)
    }

    func testTokenNotExpiringSoon() {
        // Token expiring in 1 hour (> 5 min threshold)
        let token = JWTAnalyzer.createTestToken(expiresIn: 3600)

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertFalse(info!.isExpiringSoon)
    }

    func testIsExpiredStaticMethod() {
        let validToken = JWTAnalyzer.createTestToken(expiresIn: 3600)
        XCTAssertFalse(JWTAnalyzer.isExpired(validToken))

        let expiredToken = JWTAnalyzer.createExpiredTestToken()
        XCTAssertTrue(JWTAnalyzer.isExpired(expiredToken))
    }

    func testIsExpiringSoonStaticMethod() {
        let soonToken = JWTAnalyzer.createTestToken(expiresIn: 120)
        XCTAssertTrue(JWTAnalyzer.isExpiringSoon(soonToken, withinMinutes: 5))

        let laterToken = JWTAnalyzer.createTestToken(expiresIn: 3600)
        XCTAssertFalse(JWTAnalyzer.isExpiringSoon(laterToken, withinMinutes: 5))
    }

    func testIsExpiringSoonCustomMinutes() {
        let token = JWTAnalyzer.createTestToken(expiresIn: 600) // 10 minutes

        // Not expiring within 5 minutes
        XCTAssertFalse(JWTAnalyzer.isExpiringSoon(token, withinMinutes: 5))

        // Expiring within 15 minutes
        XCTAssertTrue(JWTAnalyzer.isExpiringSoon(token, withinMinutes: 15))
    }

    // MARK: - Validation Tests

    func testValidateValidToken() {
        let token = JWTAnalyzer.createTestToken()
        XCTAssertTrue(JWTAnalyzer.validateStructure(token))
    }

    func testValidateEmptyString() {
        XCTAssertFalse(JWTAnalyzer.validateStructure(""))
    }

    func testValidateNoSegments() {
        XCTAssertFalse(JWTAnalyzer.validateStructure("nodots"))
    }

    func testValidateTwoSegments() {
        XCTAssertFalse(JWTAnalyzer.validateStructure("one.two"))
    }

    func testValidateFourSegments() {
        XCTAssertFalse(JWTAnalyzer.validateStructure("one.two.three.four"))
    }

    func testValidateInvalidBase64() {
        XCTAssertFalse(JWTAnalyzer.validateStructure("!!!.@@@.###"))
    }

    func testValidateNonJSONPayload() {
        // Valid base64 but not JSON
        let notJSON = Data("hello world".utf8).base64EncodedString()
        XCTAssertFalse(JWTAnalyzer.validateStructure("\(notJSON).\(notJSON).\(notJSON)"))
    }

    // MARK: - Extraction Tests

    func testExtractUserId() {
        let token = JWTAnalyzer.createTestToken(subject: "user-456")
        XCTAssertEqual(JWTAnalyzer.extractUserId(token), "user-456")
    }

    func testExtractUserIdFromInvalidToken() {
        XCTAssertNil(JWTAnalyzer.extractUserId("not-a-token"))
    }

    // MARK: - Decode Edge Cases

    func testDecodeInvalidToken() {
        XCTAssertNil(JWTAnalyzer.decode("not-a-valid-jwt"))
    }

    func testDecodeEmptyString() {
        XCTAssertNil(JWTAnalyzer.decode(""))
    }

    func testDecodeTokenWithoutExpiration() {
        // Create token without exp claim
        let header: [String: Any] = ["alg": "none", "typ": "JWT"]
        let payload: [String: Any] = ["sub": "test", "iss": "test"]

        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            XCTFail("Failed to create test data")
            return
        }

        let headerStr = JWTAnalyzer.base64URLDecode(headerData.base64EncodedString()) != nil ? headerData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "") : ""

        let payloadStr = payloadData.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let token = "\(headerStr).\(payloadStr).sig"

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertNil(info?.expirationDate)
        XCTAssertFalse(info?.isExpired ?? true) // No expiration = not expired
        XCTAssertEqual(info?.timeUntilExpiration, .infinity)
    }

    // MARK: - Base64URL Tests

    func testBase64URLDecode() {
        let original = "Hello, World!"
        let base64url = Data(original.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let decoded = JWTAnalyzer.base64URLDecode(base64url)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(String(data: decoded!, encoding: .utf8), original)
    }

    func testBase64URLDecodeWithPadding() {
        // Test various padding scenarios
        let testStrings = ["a", "ab", "abc", "abcd", "abcde"]
        for str in testStrings {
            let data = Data(str.utf8)
            let base64url = data.base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")

            let decoded = JWTAnalyzer.base64URLDecode(base64url)
            XCTAssertNotNil(decoded, "Failed to decode base64url for '\(str)'")
            XCTAssertEqual(String(data: decoded!, encoding: .utf8), str)
        }
    }

    // MARK: - Token Summary Tests

    func testTokenSummary() {
        let token = JWTAnalyzer.createTestToken(
            subject: "user-789",
            issuer: "firebase-auth",
            expiresIn: 3600
        )

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)

        let summary = info!.summary
        XCTAssertEqual(summary["Subject"], "user-789")
        XCTAssertEqual(summary["Issuer"], "firebase-auth")
        XCTAssertEqual(summary["Expired"], "No")
        XCTAssertNotNil(summary["Expires"])
        XCTAssertNotNil(summary["Expires In"])
        XCTAssertNotNil(summary["Issued At"])
    }

    func testExpiredTokenSummary() {
        let token = JWTAnalyzer.createExpiredTestToken()

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)

        let summary = info!.summary
        XCTAssertEqual(summary["Expired"], "Yes")
    }

    // MARK: - Additional Claims Tests

    func testAdditionalClaims() {
        let token = JWTAnalyzer.createTestToken(
            additionalClaims: [
                "email": "test@example.com",
                "email_verified": true,
                "name": "Test User"
            ]
        )

        let info = JWTAnalyzer.decode(token)
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.payload["email"] as? String, "test@example.com")
        XCTAssertEqual(info?.payload["name"] as? String, "Test User")
    }
}

// MARK: - AuthRecoveryAction Tests

final class AuthRecoveryActionTests: XCTestCase {

    func testRetryEquality() {
        XCTAssertEqual(AuthRecoveryAction.retry, AuthRecoveryAction.retry)
    }

    func testReauthenticateEquality() {
        XCTAssertEqual(AuthRecoveryAction.reauthenticate, AuthRecoveryAction.reauthenticate)
    }

    func testClearAndRestartEquality() {
        XCTAssertEqual(AuthRecoveryAction.clearAndRestart, AuthRecoveryAction.clearAndRestart)
    }

    func testShowErrorEquality() {
        XCTAssertEqual(
            AuthRecoveryAction.showError("test"),
            AuthRecoveryAction.showError("test")
        )
        XCTAssertNotEqual(
            AuthRecoveryAction.showError("test1"),
            AuthRecoveryAction.showError("test2")
        )
    }

    func testWaitAndRetryEquality() {
        XCTAssertEqual(
            AuthRecoveryAction.waitAndRetry(seconds: 5),
            AuthRecoveryAction.waitAndRetry(seconds: 5)
        )
        XCTAssertNotEqual(
            AuthRecoveryAction.waitAndRetry(seconds: 5),
            AuthRecoveryAction.waitAndRetry(seconds: 10)
        )
    }

    func testDifferentActionsNotEqual() {
        XCTAssertNotEqual(AuthRecoveryAction.retry, AuthRecoveryAction.reauthenticate)
        XCTAssertNotEqual(AuthRecoveryAction.retry, AuthRecoveryAction.clearAndRestart)
        XCTAssertNotEqual(AuthRecoveryAction.reauthenticate, AuthRecoveryAction.clearAndRestart)
    }
}

// MARK: - AuthSessionState Tests

final class AuthSessionStateTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(AuthSessionState.valid.rawValue, "Valid")
        XCTAssertEqual(AuthSessionState.expiringSoon.rawValue, "Expiring Soon")
        XCTAssertEqual(AuthSessionState.expired.rawValue, "Expired")
        XCTAssertEqual(AuthSessionState.noToken.rawValue, "No Token")
        XCTAssertEqual(AuthSessionState.unknown.rawValue, "Unknown")
    }
}

// MARK: - AuthSessionInfo Tests

final class AuthSessionInfoTests: XCTestCase {

    func testAnonymousSessionSummary() {
        let info = AuthSessionInfo(
            userId: "anon-123",
            isAnonymous: true,
            providerIds: [],
            sessionState: .valid,
            tokenExpirationDate: Date().addingTimeInterval(3600),
            timeUntilExpiration: 3600,
            creationDate: Date().addingTimeInterval(-86400),
            lastSignInDate: Date().addingTimeInterval(-3600),
            tokenClaims: ["sub": "anon-123"]
        )

        let summary = info.summary
        XCTAssertEqual(summary["User ID"], "anon-123")
        XCTAssertEqual(summary["Anonymous"], "Yes")
        XCTAssertEqual(summary["Providers"], "None")
        XCTAssertEqual(summary["Session"], "Valid")
        XCTAssertNotNil(summary["Token Expires"])
        XCTAssertNotNil(summary["Expires In"])
    }

    func testAuthenticatedSessionSummary() {
        let info = AuthSessionInfo(
            userId: "user-456",
            isAnonymous: false,
            providerIds: ["apple.com"],
            sessionState: .valid,
            tokenExpirationDate: Date().addingTimeInterval(3600),
            timeUntilExpiration: 3600,
            creationDate: Date(),
            lastSignInDate: Date(),
            tokenClaims: ["sub": "user-456", "email": "test@test.com"]
        )

        let summary = info.summary
        XCTAssertEqual(summary["Anonymous"], "No")
        XCTAssertEqual(summary["Providers"], "apple.com")
    }

    func testExpiredSessionSummary() {
        let info = AuthSessionInfo(
            userId: "user-789",
            isAnonymous: false,
            providerIds: [],
            sessionState: .expired,
            tokenExpirationDate: Date().addingTimeInterval(-600),
            timeUntilExpiration: -600,
            creationDate: nil,
            lastSignInDate: nil,
            tokenClaims: [:]
        )

        let summary = info.summary
        XCTAssertEqual(summary["Session"], "Expired")
        XCTAssertEqual(summary["Expires In"], "Expired")
    }

    func testNoUserSummary() {
        let info = AuthSessionInfo(
            userId: nil,
            isAnonymous: true,
            providerIds: [],
            sessionState: .noToken,
            tokenExpirationDate: nil,
            timeUntilExpiration: nil,
            creationDate: nil,
            lastSignInDate: nil,
            tokenClaims: [:]
        )

        let summary = info.summary
        XCTAssertEqual(summary["User ID"], "None")
        XCTAssertEqual(summary["Session"], "No Token")
        XCTAssertNil(summary["Token Expires"])
        XCTAssertNil(summary["Expires In"])
    }

    func testMultipleProviders() {
        let info = AuthSessionInfo(
            userId: "user-multi",
            isAnonymous: false,
            providerIds: ["apple.com", "google.com"],
            sessionState: .valid,
            tokenExpirationDate: nil,
            timeUntilExpiration: nil,
            creationDate: nil,
            lastSignInDate: nil,
            tokenClaims: [:]
        )

        let summary = info.summary
        XCTAssertEqual(summary["Providers"], "apple.com, google.com")
    }
}

// MARK: - AuthEdgeCaseError Tests

final class AuthEdgeCaseErrorTests: XCTestCase {

    func testNoCurrentUserError() {
        let error = AuthEdgeCaseError.noCurrentUser
        XCTAssertEqual(error.errorDescription, "No authenticated user found")
    }

    func testTokenDecodeFailedError() {
        let error = AuthEdgeCaseError.tokenDecodeFailed
        XCTAssertEqual(error.errorDescription, "Failed to decode authentication token")
    }

    func testTokenExpiredError() {
        let error = AuthEdgeCaseError.tokenExpired
        XCTAssertEqual(error.errorDescription, "Authentication token has expired")
    }

    func testUpgradeNotAvailableError() {
        let error = AuthEdgeCaseError.upgradeNotAvailable
        XCTAssertEqual(error.errorDescription, "Account upgrade is not available for this user")
    }

    func testLinkingFailedError() {
        let error = AuthEdgeCaseError.linkingFailed("credential mismatch")
        XCTAssertEqual(error.errorDescription, "Account linking failed: credential mismatch")
    }

    func testLinkingFailedDifferentReasons() {
        let error1 = AuthEdgeCaseError.linkingFailed("timeout")
        let error2 = AuthEdgeCaseError.linkingFailed("already linked")

        XCTAssertEqual(error1.errorDescription, "Account linking failed: timeout")
        XCTAssertEqual(error2.errorDescription, "Account linking failed: already linked")
    }
}
