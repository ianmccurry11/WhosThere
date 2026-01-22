//
//  ContentView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService()
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Main content
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else if authService.isAuthenticated {
                    HomeView()
                } else {
                    SignInView(authService: authService)
                }
            }
            .animation(.easeInOut, value: authService.isAuthenticated)
            .animation(.easeInOut, value: hasCompletedOnboarding)

            // Splash screen overlay
            if showSplash {
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            // Show splash for 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showSplash = false
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
