//
//  StatusBanner.swift
//  WhosThereios
//
//  Created by Claude on 1/17/26.
//

import SwiftUI

// MARK: - Status Banner

struct StatusBanner: View {
    let message: String
    let type: BannerType
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    enum BannerType {
        case error
        case warning
        case success
        case info
        case offline

        var backgroundColor: Color {
            switch self {
            case .error: return .red
            case .warning: return .appTan
            case .success: return .appOliveGreen
            case .info: return .appBrown
            case .offline: return .gray
            }
        }

        var icon: String {
            switch self {
            case .error: return "exclamationmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .offline: return "wifi.slash"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.body)

            Text(message)
                .font(.subheadline)
                .lineLimit(2)

            Spacer()

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.backgroundColor)
    }
}

// MARK: - Offline Banner

struct OfflineBanner: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        if !networkMonitor.isConnected {
            StatusBanner(
                message: "No internet connection",
                type: .offline
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Error Toast

struct ErrorToast: View {
    let message: String
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            VStack {
                StatusBanner(message: message, type: .error)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                    .padding(.horizontal)
                    .padding(.top, 60)

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary.opacity(0.6))

            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let label = actionLabel, let action = action {
                Button(action: action) {
                    Text(label)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.appBrown)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 40)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}

// MARK: - Skeleton Loader

struct SkeletonLoader: View {
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: isAnimating ? 200 : -200)
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

struct SkeletonCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SkeletonLoader()
                    .frame(width: 50, height: 50)
                    .cornerRadius(25)

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonLoader()
                        .frame(height: 16)
                        .frame(maxWidth: 150)

                    SkeletonLoader()
                        .frame(height: 12)
                        .frame(maxWidth: 100)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview("Status Banner") {
    VStack(spacing: 0) {
        StatusBanner(message: "Something went wrong", type: .error)
        StatusBanner(message: "Please check your input", type: .warning)
        StatusBanner(message: "Group created!", type: .success)
        StatusBanner(message: "New feature available", type: .info)
        StatusBanner(message: "No internet connection", type: .offline)
    }
}

#Preview("Empty State") {
    EmptyStateView(
        icon: "mappin.slash",
        title: "No Groups Nearby",
        message: "There aren't any groups in your area yet. Be the first to create one!",
        actionLabel: "Create Group"
    ) {
        print("Create tapped")
    }
}

#Preview("Loading") {
    VStack(spacing: 20) {
        LoadingView()

        SkeletonCard()
        SkeletonCard()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
