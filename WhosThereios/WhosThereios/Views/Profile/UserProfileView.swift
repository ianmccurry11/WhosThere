//
//  UserProfileView.swift
//  WhosThereios
//

import SwiftUI

/// Public profile sheet shown when viewing another user from a group or friends list.
struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss

    let userId: String
    /// Shown immediately while the full profile loads
    let displayName: String

    @State private var user: User?
    @State private var achievements: [UserAchievement] = []
    @State private var stats: UserStats?
    @State private var isLoading = true

    // MARK: - Computed

    private var totalPoints: Int {
        achievements.reduce(0) { $0 + $1.achievementType.points }
    }

    private var level: UserLevel {
        UserLevel.calculate(from: user?.totalXP ?? totalPoints)
    }

    private var initials: String {
        let name = user?.displayName ?? displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        VStack(spacing: 16) {
                            // Placeholder avatar
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 140, height: 20)
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 14)
                        }
                        .padding(.top, 40)
                        .accessibilityLabel("Loading profile")
                    } else {
                        profileHeader
                        levelCard
                        if !achievements.isEmpty {
                            achievementsSection
                        }
                        if let stats {
                            statsSection(stats)
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 80, height: 80)
                .overlay(
                    Text(initials)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                )
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(user?.displayName ?? displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                if let tag = user?.discriminator {
                    Text("#\(tag)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 6) {
                    LevelBadge(level: level.level)
                    Text(level.tierName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Level Card

    private var levelCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Level \(level.level)")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(level.tierName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Text("\(user?.totalXP ?? totalPoints) XP · \(achievements.count) badge\(achievements.count == 1 ? "" : "s") earned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Level badge circle
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Text("\(level.level)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .accessibilityHidden(true)
            }

            // Progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
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
                            .frame(
                                width: geo.size.width * CGFloat(level.progressToNextLevel),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                HStack {
                    if level.xpForNextLevel != nil {
                        Text("\(level.xpToNextLevel) XP to Level \(level.level + 1)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Max level reached!")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                    Spacer()
                }
            }
            .accessibilityLabel("Level \(level.level), \(Int(level.progressToNextLevel * 100))% to next level")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Achievements Section

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements (\(achievements.count))")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5),
                spacing: 10
            ) {
                ForEach(achievements) { achievement in
                    VStack(spacing: 3) {
                        Text(achievement.achievementType.emoji)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                        Text(achievement.achievementType.displayName)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityLabel(achievement.achievementType.displayName)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Stats Section

    private func statsSection(_ stats: UserStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stats")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 0) {
                statItem(
                    value: stats.totalCheckIns,
                    label: "Check-ins",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                Divider().frame(height: 44)
                statItem(
                    value: stats.currentStreak,
                    label: "Day Streak",
                    icon: "flame.fill",
                    color: .orange
                )
                Divider().frame(height: 44)
                statItem(
                    value: stats.friendCount,
                    label: "Friends",
                    icon: "person.2.fill",
                    color: .blue
                )
                Divider().frame(height: 44)
                statItem(
                    value: stats.groupsJoined,
                    label: "Groups",
                    icon: "mappin.circle.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func statItem(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
            Text("\(value)")
                .font(.headline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Data Loading

    private func loadData() async {
        async let userFetch = FirestoreService.shared.fetchUserById(userId)
        async let achievementsFetch = FirestoreService.shared.fetchUserAchievements(userId: userId)
        async let statsFetch = FirestoreService.shared.fetchUserStats(userId: userId)

        let (fetchedUser, fetchedAchievements, fetchedStats) = await (userFetch, achievementsFetch, statsFetch)

        user = fetchedUser
        achievements = fetchedAchievements
        stats = fetchedStats
        isLoading = false
    }
}

#Preview {
    UserProfileView(userId: "preview-user", displayName: "Alex Smith")
}
