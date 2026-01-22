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

    private var authStateHandler: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

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

        do {
            let result = try await Auth.auth().signInAnonymously()
            self.user = result.user
            self.isAuthenticated = true

            // Create user document
            if let userId = self.user?.uid {
                await FirestoreService.shared.createUserIfNeeded(
                    userId: userId,
                    displayName: "Player \(String(userId.prefix(4)))",
                    email: nil
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            user = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign in with Apple

    func startSignInWithAppleFlow() -> ASAuthorizationAppleIDRequest {
        let nonce = randomNonceString()
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
            return
        }

        isLoading = true
        errorMessage = nil

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: credential)
            self.user = result.user
            self.isAuthenticated = true

            // Extract display name
            var displayName = "User"
            if let fullName = appleIDCredential.fullName {
                let givenName = fullName.givenName ?? ""
                let familyName = fullName.familyName ?? ""
                if !givenName.isEmpty || !familyName.isEmpty {
                    displayName = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
                }
            }
            if displayName == "User", let email = appleIDCredential.email {
                displayName = email.components(separatedBy: "@").first ?? "User"
            }
            if displayName == "User" {
                displayName = result.user.displayName ?? "User \(String(result.user.uid.prefix(4)))"
            }

            // Create user document
            await FirestoreService.shared.createUserIfNeeded(
                userId: result.user.uid,
                displayName: displayName,
                email: result.user.email ?? appleIDCredential.email
            )
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Nonce Generation

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
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
