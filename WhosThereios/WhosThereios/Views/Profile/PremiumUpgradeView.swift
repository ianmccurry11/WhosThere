//
//  PremiumUpgradeView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 2/22/26.
//

import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var storeService = StoreService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Who's There Premium")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Unlock exclusive customization features")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 24)

                    // Features list
                    VStack(spacing: 0) {
                        PremiumFeatureRow(
                            icon: "paintpalette.fill",
                            iconColor: .purple,
                            title: "Premium Group Colors",
                            description: "6 exclusive boundary colors: Gold, Indigo, Mint, Lavender, Coral, and Slate"
                        )

                        Divider().padding(.leading, 60)

                        PremiumFeatureRow(
                            icon: "face.smiling.inverse",
                            iconColor: .orange,
                            title: "Custom Profile Emoji",
                            description: "Replace your initials with a custom emoji avatar"
                        )

                        Divider().padding(.leading, 60)

                        PremiumFeatureRow(
                            icon: "paintbrush.fill",
                            iconColor: .blue,
                            title: "Profile Accent Color",
                            description: "Choose a custom accent color for your profile"
                        )

                        Divider().padding(.leading, 60)

                        PremiumFeatureRow(
                            icon: "crown.fill",
                            iconColor: Color(red: 1.0, green: 0.84, blue: 0.0),
                            title: "Premium Badge",
                            description: "Show off your premium status with a gold badge"
                        )
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Purchase button
                    VStack(spacing: 12) {
                        if storeService.isLoadingProducts {
                            HStack {
                                ProgressView()
                                Text("Loading…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            Button {
                                Task {
                                    await storeService.purchase()
                                    if storeService.isPremium {
                                        HapticManager.success()
                                        dismiss()
                                    }
                                }
                            } label: {
                                HStack {
                                    if storeService.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text(purchaseButtonText)
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [Color.appBlue, Color.appBlue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(14)
                                .opacity(storeService.products.isEmpty ? 0.4 : 1.0)
                            }
                            .disabled(storeService.isLoading || storeService.products.isEmpty)
                            .padding(.horizontal)
                        }

                        if storeService.errorMessage != nil && !storeService.isLoadingProducts {
                            Button {
                                Task { await storeService.loadProducts() }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .font(.subheadline)
                                    .foregroundColor(.appBlue)
                            }
                        }

                        Button {
                            Task {
                                await storeService.restorePurchases()
                                if storeService.isPremium {
                                    HapticManager.success()
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("Restore Purchase")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .disabled(storeService.isLoading || storeService.isLoadingProducts)

                        if let error = storeService.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Text("One-time purchase. No subscription.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var purchaseButtonText: String {
        if let product = storeService.products.first {
            return "Unlock Premium — \(product.displayPrice)"
        }
        return "Unlock Premium — $0.99"
    }
}

// MARK: - Feature Row

struct PremiumFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.body)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Profile Emoji Picker

struct ProfileEmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String) -> Void

    private let emojis = [
        "😀", "😎", "🤩", "🥳", "😇", "🤠", "🦊", "🐱", "🐶", "🐼",
        "🦁", "🐯", "🦄", "🐸", "🐙", "🦋", "🌟", "🔥", "💎", "🎯",
        "🎮", "🎨", "🎸", "🏀", "⚽", "🏈", "🎾", "🏆", "👑", "🚀",
        "🌈", "⭐", "💜", "💙", "💚", "💛", "🧡", "❤️", "🖤", "🤍"
    ]

    private let columns = [GridItem(.adaptive(minimum: 50))]

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Choose your profile emoji")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            onSelect(emoji)
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Profile Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PremiumUpgradeView()
}
