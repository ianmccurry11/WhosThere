//
//  AchievementsView.swift
//  WhosThereios
//
//  Created by Claude on 1/16/26.
//

import SwiftUI

struct AchievementsView: View {
    @ObservedObject private var achievementService = AchievementService.shared

    @State private var selectedCategory: AchievementCategory?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Points summary
                    PointsSummaryCard(
                        totalPoints: achievementService.totalPoints,
                        earnedCount: achievementService.earnedAchievements.count,
                        totalCount: AchievementType.allCases.count
                    )
                    .padding(.horizontal)

                    // Category filter
                    CategoryFilterView(selectedCategory: $selectedCategory)

                    // Achievements grid
                    LazyVStack(spacing: 16) {
                        ForEach(filteredCategories, id: \.self) { category in
                            AchievementCategorySection(
                                category: category,
                                achievements: achievementService.achievementsByCategory()[category] ?? []
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await achievementService.loadUserData()
        }
    }

    private var filteredCategories: [AchievementCategory] {
        if let selected = selectedCategory {
            return [selected]
        }
        return AchievementCategory.allCases
    }
}

// MARK: - Points Summary Card

struct PointsSummaryCard: View {
    let totalPoints: Int
    let earnedCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(totalPoints)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Badges Earned")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(earnedCount)/\(totalCount)")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
        )
    }

    private var progressPercentage: CGFloat {
        guard totalCount > 0 else { return 0 }
        return CGFloat(earnedCount) / CGFloat(totalCount)
    }
}

// MARK: - Category Filter

struct CategoryFilterView: View {
    @Binding var selectedCategory: AchievementCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                FilterChip(
                    title: "All",
                    isSelected: selectedCategory == nil
                ) {
                    selectedCategory = nil
                }

                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    FilterChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                )
        }
    }
}

// MARK: - Category Section

struct AchievementCategorySection: View {
    let category: AchievementCategory
    let achievements: [AchievementType]

    @ObservedObject private var achievementService = AchievementService.shared
    @State private var selectedAchievement: AchievementType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.displayName)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(achievements, id: \.self) { achievement in
                    AchievementCard(
                        achievement: achievement,
                        isEarned: achievementService.hasEarned(achievement),
                        progress: achievementService.getProgress(for: achievement)
                    )
                    .onTapGesture {
                        selectedAchievement = achievement
                    }
                }
            }
        }
        .sheet(item: $selectedAchievement) { achievement in
            AchievementDetailSheet(
                achievement: achievement,
                isEarned: achievementService.hasEarned(achievement),
                progress: achievementService.getProgress(for: achievement)
            )
            .presentationDetents([.height(280)] as Set<PresentationDetent>)
            .presentationDragIndicator(Visibility.visible)
        }
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: AchievementType
    let isEarned: Bool
    let progress: (current: Int, target: Int)?

    var body: some View {
        VStack(spacing: 8) {
            // Emoji/Icon
            ZStack {
                Circle()
                    .fill(isEarned ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 56, height: 56)

                Text(achievement.emoji)
                    .font(.system(size: 28))
                    .opacity(isEarned ? 1 : 0.4)
                    .grayscale(isEarned ? 0 : 1)
            }

            // Name
            Text(achievement.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundColor(isEarned ? .primary : .secondary)

            // Progress or Points
            if isEarned {
                Text("+\(achievement.points) pts")
                    .font(.caption2)
                    .foregroundColor(.blue)
            } else if let progress = progress {
                ProgressView(value: Double(progress.current), total: Double(progress.target))
                    .tint(.blue)

                Text("\(progress.current)/\(progress.target)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Locked")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEarned ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Achievement Unlocked Toast

struct AchievementUnlockedToast: View {
    let achievement: AchievementType

    var body: some View {
        HStack(spacing: 12) {
            Text(achievement.emoji)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                Text("Achievement Unlocked!")
                    .font(.caption)
                    .foregroundColor(.blue)

                Text(achievement.displayName)
                    .font(.headline)

                Text("+\(achievement.points) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        )
        .padding(.horizontal)
    }
}

// MARK: - Achievement Detail Sheet

struct AchievementDetailSheet: View {
    let achievement: AchievementType
    let isEarned: Bool
    let progress: (current: Int, target: Int)?

    var body: some View {
        VStack(spacing: 20) {
            // Emoji and status
            ZStack {
                Circle()
                    .fill(isEarned ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)

                Text(achievement.emoji)
                    .font(.system(size: 44))
                    .opacity(isEarned ? 1 : 0.4)
                    .grayscale(isEarned ? 0 : 1)
            }

            // Name and category
            VStack(spacing: 4) {
                Text(achievement.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(achievement.category.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(.systemGray5)))
            }

            // Description - how to obtain
            Text(achievement.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Progress or earned status
            if isEarned {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Earned!")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    Text("+\(achievement.points) pts")
                        .foregroundColor(.blue)
                }
                .font(.subheadline)
            } else if let progress = progress {
                VStack(spacing: 8) {
                    ProgressView(value: Double(progress.current), total: Double(progress.target))
                        .tint(.blue)
                        .frame(width: 200)

                    Text("\(progress.current) / \(progress.target)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("Worth \(achievement.points) points")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }

            Spacer()
        }
        .padding(.top, 24)
    }
}

// MARK: - Recent Achievements Row (for Profile)

struct RecentAchievementsRow: View {
    @ObservedObject private var achievementService = AchievementService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.headline)

                Spacer()

                NavigationLink(destination: AchievementsView()) {
                    HStack(spacing: 4) {
                        Text("See All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }

            HStack(spacing: 8) {
                // Points badge
                VStack(spacing: 4) {
                    Text("\(achievementService.totalPoints)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("Points")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 70)

                Divider()
                    .frame(height: 40)

                // Recent badges
                if achievementService.earnedAchievements.isEmpty {
                    Text("No badges yet - start checking in!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(achievementService.earnedAchievements.prefix(5)) { achievement in
                                VStack(spacing: 4) {
                                    Text(achievement.achievementType.emoji)
                                        .font(.title2)
                                    Text(achievement.achievementType.displayName)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 60)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }
}

#Preview {
    AchievementsView()
}
