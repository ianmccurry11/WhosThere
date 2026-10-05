//
//  AuthService.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import Foundation
import Combine
import FirebaseAuth
import AuthenticationServices
import CryptoKit

@MainActor
class AuthService: NSObject, ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isNewUser = false

    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    var analyticsService: AnalyticsService { AnalyticsService.shared }
    var networkInspector: NetworkInspector { NetworkInspector.shared }

    override init() {
        super.init()
        setupAuthStateListener()
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    private func setupAuthStateListener() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    // Anonymous sign in for development/testing
    func signInAnonymously() async {
        isLoading = true
        errorMessage = nil

        analyticsService.trackSignInAttempted(method: "anonymous")

        let startTime = Date()
        do {
            let result = try await Auth.auth().signInAnonymously()
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logAuthOperation(method: "signIn", durationMs: duration, success: true)

            self.user = result.user
            self.isAuthenticated = true

            // Create user document
            if let userId = self.user?.uid {
                self.isNewUser = await FirestoreService.shared.createUserIfNeeded(
                    userId: userId,
                    displayName: "Player \(String(userId.prefix(4)))",
                    email: nil
                )
            } else {
                self.isNewUser = false
            }

            analyticsService.trackSignInSuccess(method: "anonymous", isNewUser: isNewUser)
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logAuthOperation(method: "signIn", durationMs: duration, success: false, error: error)
            self.errorMessage = error.localizedDescription
            analyticsService.trackSignInFailure(method: "anonymous", errorCode: String(describing: error))
        }

        isLoading = false
    }

    func signOut() {
        let startTime = Date()
        do {
            try Auth.auth().signOut()
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logAuthOperation(method: "signOut", durationMs: duration, success: true)
            user = nil
            isAuthenticated = false
            analyticsService.trackSignOut()
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logAuthOperation(method: "signOut", durationMs: duration, success: false, error: error)
            errorMessage = error.localizedDescription
            analyticsService.trackError(errorType: "sign_out_failed", context: "AuthService.signOut", message: error.localizedDescription)
        }
    }

    // MARK: - Account Deletion

    /// Deletes the current user's account and all associated data from Firestore and Firebase Auth.
    /// Required by Apple App Store Guideline 5.1.1(v).
    func deleteAccount() async -> Bool {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "No user signed in"
            return false
        }

        isLoading = true
        errorMessage = nil

        let userId = user.uid

        do {
            // 1. Delete user's Firestore data
            await FirestoreService.shared.deleteAllUserData(userId: userId)

            // 2. Clear FCM token
            await NotificationService.shared.clearFCMToken()

            // 3. Delete Firebase Auth account
            try await user.delete()

            // 4. Clear local state
            self.user = nil
            self.isAuthenticated = false
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier ?? "")

            analyticsService.trackSignOut()

            isLoading = false
            return true
        } catch {
            isLoading = false
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            analyticsService.trackError(errorType: "account_deletion_failed", context: "AuthService.deleteAccount", message: error.localizedDescription)
            return false
        }
    }

    // MARK: - Sign in with Apple

    func startSignInWithAppleFlow() -> ASAuthorizationAppleIDRequest {
        let nonce = generateNonce()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        return request
    }

    func handleSignInWithApple(authorization: ASAuthorization) async {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce,
              let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            errorMessage = "Unable to fetch identity token"
            analyticsService.trackSignInFailure(method: "apple", errorCode: "invalid_token")
            return
        }

        isLoading = true
        errorMessage = nil

        analyticsService.trackSignInAttempted(method: "apple")

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        let startTime = Date()
        do {
            let result = try await Auth.auth().signIn(with: credential)
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logAuthOperation(method: "signIn", durationMs: duration, success: true)
            self.user = result.user
            self.isAuthenticated = true

            // Extract display name from Apple credential (only provided on first sign-in)
            var displayName = "User"
            if let fullName = appleIDCredential.fullName {
                let givenName = fullName.givenName ?? ""
                let familyName = fullName.familyName ?? ""
                if !givenName.isEmpty || !familyName.isEmpty {
                    displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                }
            }
            // Fall back to email prefix if name not provided
            if displayName == "User", let email = appleIDCredential.email {
                displayName = email.components(separatedBy: "@").first ?? "User"
            }
            // Fall back to Firebase display name (persisted from first Apple sign-in)
            if displayName == "User" {
                displayName = result.user.displayName ?? "User \(String(result.user.uid.prefix(4)))"
            }

            // Create user document
            let isNew = await FirestoreService.shared.createUserIfNeeded(
                userId: result.user.uid,
                displayName: displayName,
                email: result.user.email ?? appleIDCredential.email
            )

            // Prompt new users to set a preferred display name (username).
            self.isNewUser = isNew

            analyticsService.trackSignInSuccess(method: "apple", isNewUser: isNew)
        } catch {
            let duration = Date().timeIntervalSince(startTime) * 1000
            networkInspector.logAuthOperation(method: "signIn", durationMs: duration, success: false, error: error)
            self.errorMessage = error.localizedDescription
            analyticsService.trackSignInFailure(method: "apple", errorCode: String(describing: error))
        }

        isLoading = false
    }

    // MARK: - Nonce Generation

    private func generateNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)

        if errorCode != errSecSuccess {
            // Fallback: use UUID-based nonce instead of crashing
            errorMessage = "Secure random generation failed. Please try again."
            AppLogger.debug("SecRandomCopyBytes failed with OSStatus \(errorCode), using UUID fallback")
            let uuid = UUID().uuidString + UUID().uuidString
            return String(uuid.replacingOccurrences(of: "-", with: "").prefix(length))
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }

        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}
