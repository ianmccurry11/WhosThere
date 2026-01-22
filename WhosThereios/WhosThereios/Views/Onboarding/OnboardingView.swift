//
//  OnboardingView.swift
//  WhosThereios
//
//  Created by Claude on 1/17/26.
//

import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @ObservedObject private var locationService = LocationService.shared

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            image: "mappin.and.ellipse",
            title: "Find Your Crew",
            description: "Create or join groups for your favorite spots - basketball courts, parks, coffee shops, or anywhere your friends gather.",
            color: .appOliveGreen
        ),
        OnboardingPage(
            image: "eye.slash.fill",
            title: "Privacy First",
            description: "We only share whether you're at a location, never your exact position. Your location data stays on your device.",
            color: .appDarkGreen
        ),
        OnboardingPage(
            image: "bell.badge.fill",
            title: "Know Who's There",
            description: "See when friends arrive at your favorite spots. No more empty courts or missed hangouts.",
            color: .appTan
        ),
        OnboardingPage(
            image: "location.fill",
            title: "Enable Location",
            description: "Allow location access to see nearby groups and check in when you arrive.",
            color: .appBrown
        ),
        OnboardingPage(
            image: "location.circle.fill",
            title: "Always Allow (Recommended)",
            description: "For automatic check-ins even when the app is closed, enable 'Always' location access. This enables background geofencing for a seamless experience.",
            color: .appOliveGreen
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom section
            VStack(spacing: 20) {
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? pages[index].color : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }

                // Action button
                Button(action: {
                    HapticManager.light()
                    if currentPage == pages.count - 2 {
                        // On "Enable Location" page, request When In Use first
                        locationService.requestAuthorization()
                        withAnimation {
                            currentPage += 1
                        }
                    } else if currentPage == pages.count - 1 {
                        // On "Always Allow" page, request Always
                        locationService.requestAlwaysAuthorization()
                        HapticManager.success()
                        completeOnboarding()
                    } else if currentPage < pages.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        HapticManager.success()
                        completeOnboarding()
                    }
                }) {
                    Text(getButtonText())
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pages[currentPage].color)
                        .cornerRadius(14)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
                .padding(.horizontal, 24)

                // Skip button (not on last page)
                if currentPage < pages.count - 1 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                } else {
                    // Placeholder to maintain layout
                    Text(" ")
                        .font(.subheadline)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemBackground))
    }

    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    private func getButtonText() -> String {
        switch currentPage {
        case pages.count - 2:
            return "Enable Location"
        case pages.count - 1:
            return "Enable Always (Recommended)"
        case pages.count - 1 where currentPage == pages.count - 1:
            return "Get Started"
        default:
            return "Continue"
        }
    }
}

// MARK: - Page Model

struct OnboardingPage {
    let image: String
    let title: String
    let description: String
    let color: Color
}

// MARK: - Page View

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimated = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .scaleEffect(isAnimated ? 1.0 : 0.5)
                    .opacity(isAnimated ? 1.0 : 0.0)

                Image(systemName: page.image)
                    .font(.system(size: 70))
                    .foregroundColor(page.color)
                    .scaleEffect(isAnimated ? 1.0 : 0.3)
                    .opacity(isAnimated ? 1.0 : 0.0)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: isAnimated)

            // Text content
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimated ? 1.0 : 0.0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.3), value: isAnimated)

                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(isAnimated ? 1.0 : 0.0)
                    .offset(y: isAnimated ? 0 : 20)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: isAnimated)
            }

            Spacer()
            Spacer()
        }
        .onAppear {
            isAnimated = true
        }
        .onDisappear {
            isAnimated = false
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
