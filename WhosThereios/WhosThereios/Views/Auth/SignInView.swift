//
//  SignInView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @ObservedObject var authService: AuthService
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Background gradient with new color palette
            LinearGradient(
                gradient: Gradient(colors: [Color.appDarkGreen, Color.appOliveGreen]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // App Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)

                    Text("Who's There")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)

                    Text("See who's at your favorite spots")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Features list
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "person.3.fill", text: "Join groups for your favorite locations")
                    FeatureRow(icon: "location.fill", text: "Know who's there without sharing your location")
                    FeatureRow(icon: "hand.tap.fill", text: "Check in automatically or manually")
                }
                .padding(.horizontal, 32)

                Spacer()

                // Sign In Button
                VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                            let appleRequest = authService.startSignInWithAppleFlow()
                            request.nonce = appleRequest.nonce
                        },
                        onCompletion: { result in
                            Task {
                                switch result {
                                case .success(let authorization):
                                    await authService.handleSignInWithApple(authorization: authorization)
                                case .failure(let error):
                                    authService.errorMessage = error.localizedDescription
                                }
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 55)
                    .cornerRadius(12)
                    .padding(.horizontal, 32)
                    .disabled(authService.isLoading)

                    if authService.isLoading {
                        ProgressView()
                            .tint(.white)
                    }

                    if let error = authService.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                Spacer()
                    .frame(height: 40)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 30)

            Text(text)
                .font(.body)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    SignInView(authService: AuthService())
}
