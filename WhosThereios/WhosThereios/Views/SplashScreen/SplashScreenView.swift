//
//  SplashScreenView.swift
//  WhosThereios
//
//  Created by Claude on 1/17/26.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var showTagline = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // App icon/logo
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)

                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                }
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)

                // App name
                Text("Who's There")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Tagline
                if showTagline {
                    Text("Find your crew")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .onAppear {
            isAnimating = true
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                showTagline = true
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
