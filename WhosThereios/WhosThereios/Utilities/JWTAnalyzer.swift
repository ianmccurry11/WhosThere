//
//  JWTAnalyzer.swift
//  WhosThereios
//
//  Created by Claude on 2/5/26.
//

import Foundation

/// Utility for decoding and analyzing JWT tokens
/// Used for auth session analysis and edge-case testing
struct JWTAnalyzer {

    // MARK: - Token Info

    /// Decoded JWT token information
    struct TokenInfo {
        let header: [String: Any]
        let payload: [String: Any]
        let expirationDate: Date?
        let issuedAt: Date?
        let subject: String?
        let issuer: String?
        let audience: String?

        var isExpired: Bool {
            guard let exp = expirationDate else { return false }
            return Date() > exp
        }

        var timeUntilExpiration: TimeInterval {
            guard let exp = expirationDate else { return .infinity }
            return exp.timeIntervalSinceNow
        }

        var isExpiringSoon: Bool {
            return timeUntilExpiration < 300 // 5 minutes
        }

        /// Human-readable summary of token info
        var summary: [String: String] {
            var info: [String: String] = [:]

            if let sub = subject { info["Subject"] = sub }
            if let iss = issuer { info["Issuer"] = iss }
            if let aud = audience { info["Audience"] = aud }

            if let exp = expirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                info["Expires"] = formatter.string(from: exp)
                info["Expired"] = isExpired ? "Yes" : "No"

                if !isExpired {
                    let minutes = Int(timeUntilExpiration / 60)
                    info["Expires In"] = "\(minutes) min"
                }
            }

            if let iat = issuedAt {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .medium
                info["Issued At"] = formatter.string(from: iat)
            }

            return info
        }
    }

    // MARK: - Decoding

    /// Decode a JWT token string into its components
    /// - Parameter token: The JWT token string (header.payload.signature)
    /// - Returns: TokenInfo if decoding succeeds, nil otherwise
    static func decode(_ token: String) -> TokenInfo? {
        let segments = token.components(separatedBy: ".")
        guard segments.count >= 2 else { return nil }

        guard let headerData = base64URLDecode(segments[0]),
              let payloadData = base64URLDecode(segments[1]) else {
            return nil
        }

        guard let header = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any],
              let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            return nil
        }

        let expirationDate: Date? = {
            guard let exp = payload["exp"] as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: exp)
        }()

        let issuedAt: Date? = {
            guard let iat = payload["iat"] as? TimeInterval else { return nil }
            return Date(timeIntervalSince1970: iat)
        }()

        let subject = payload["sub"] as? String
        let issuer = payload["iss"] as? String
        let audience = payload["aud"] as? String

        return TokenInfo(
            header: header,
            payload: payload,
            expirationDate: expirationDate,
            issuedAt: issuedAt,
            subject: subject,
            issuer: issuer,
            audience: audience
        )
    }

    // MARK: - Validation

    /// Validate that a string has valid JWT structure (3 base64url-encoded segments)
    static func validateStructure(_ token: String) -> Bool {
        let segments = token.components(separatedBy: ".")
        guard segments.count == 3 else { return false }

        // Each segment must be valid base64url
        for segment in segments {
            guard base64URLDecode(segment) != nil else { return false }
        }

        // Header and payload must be valid JSON
        guard let headerData = base64URLDecode(segments[0]),
              let payloadData = base64URLDecode(segments[1]) else {
            return false
        }

        guard (try? JSONSerialization.jsonObject(with: headerData)) != nil,
              (try? JSONSerialization.jsonObject(with: payloadData)) != nil else {
            return false
        }

        return true
    }

    /// Check if a token is expired
    static func isExpired(_ token: String) -> Bool {
        guard let info = decode(token) else { return true }
        return info.isExpired
    }

    /// Check if a token is expiring within the given number of minutes
    static func isExpiringSoon(_ token: String, withinMinutes minutes: Int = 5) -> Bool {
        guard let info = decode(token) else { return true }
        return info.timeUntilExpiration < Double(minutes * 60)
    }

    /// Extract the user ID (subject) from a token
    static func extractUserId(_ token: String) -> String? {
        return decode(token)?.subject
    }

    // MARK: - Helpers

    /// Decode base64url-encoded string to Data
    static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Pad to multiple of 4
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }

        return Data(base64Encoded: base64)
    }

    /// Create a test JWT token with given claims (for testing only)
    static func createTestToken(
        subject: String = "test-user-123",
        issuer: String = "test-issuer",
        expiresIn: TimeInterval = 3600,
        additionalClaims: [String: Any] = [:]
    ) -> String {
        let header: [String: Any] = ["alg": "none", "typ": "JWT"]
        var payload: [String: Any] = [
            "sub": subject,
            "iss": issuer,
            "iat": Date().timeIntervalSince1970,
            "exp": Date().addingTimeInterval(expiresIn).timeIntervalSince1970,
        ]

        for (key, value) in additionalClaims {
            payload[key] = value
        }

        guard let headerData = try? JSONSerialization.data(withJSONObject: header),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            return ""
        }

        let headerStr = base64URLEncode(headerData)
        let payloadStr = base64URLEncode(payloadData)
        let signature = base64URLEncode(Data("test-signature".utf8))

        return "\(headerStr).\(payloadStr).\(signature)"
    }

    /// Create an expired test token
    static func createExpiredTestToken(
        subject: String = "test-user-123",
        expiredSinceSeconds: TimeInterval = 3600
    ) -> String {
        return createTestToken(
            subject: subject,
            expiresIn: -expiredSinceSeconds
        )
    }

    /// Encode Data to base64url string
    private static func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
