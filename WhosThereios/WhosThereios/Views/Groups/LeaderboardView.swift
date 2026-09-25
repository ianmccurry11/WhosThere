//
//  LeaderboardView.swift
//  WhosThereios
//
//  Created by Claude on 3/19/26.
//

import SwiftUI
import FirebaseAuth

// MARK: - Full Leaderboard View

struct LeaderboardView: View {
    let groupId: String
    let groupName: String

    @State private var timeframe: LeaderboardTimeframe = .monthly
    @State private var entries: [LeaderboardEntry] = []
    @State private var isLoading = true

    private let currentUserId = Auth.auth().currentUser?.uid

    var body: some View {
        VStack(spacing: 0) {
            // Timeframe picker
            Picker("Timeframe", selection: $timeframe) {
                ForEach(LeaderboardTimeframe.allCases, id: \.self) { tf in
                    Text(tf.rawValue).tag(tf)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "trophy",
                    title: "No Check-Ins Yet",
                    message: timeframe == .monthly
                        ? "Be the first to check in this month!"
                        : "Check in to start climbing the leaderboard."
                )
                Spacer()
            } else {
                // Top 3 podium
                if entries.count >= 3 {
                    PodiumView(entries: Array(entries.prefix(3)), currentUserId: currentUserId)
                        .padding()
                }

                // Full ranked list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(entries.enumerated()), id: \.element.userId) { index, entry in
                            LeaderboardRow(
                                rank: index + 1,
                                entry: entry,
                                isCurrentUser: entry.userId == currentUserId,
                                timeframe: timeframe
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadLeaderboard()
        }
        .onChange(of: timeframe) { _, _ in
            Task { await loadLeaderboard() }
        }
    }

    private func loadLeaderboard() async {
        isLoading = true
        entries = await FirestoreService.shared.fetchLeaderboard(groupId: groupId, timeframe: timeframe)
        isLoading = false
    }
}

// MARK: - Podium View (Top 3)

private struct PodiumView: View {
    let entries: [LeaderboardEntry]
    let currentUserId: String?

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            if entries.count >= 2 {
                PodiumSpot(rank: 2, entry: entries[1], height: 70, isCurrentUser: entries[1].userId == currentUserId)
            }
            if entries.count >= 1 {
                PodiumSpot(rank: 1, entry: entries[0], height: 90, isCurrentUser: entries[0].userId == currentUserId)
            }
            if entries.count >= 3 {
                PodiumSpot(rank: 3, entry: entries[2], height: 55, isCurrentUser: entries[2].userId == currentUserId)
            }
        }
    }
}

private struct PodiumSpot: View {
    let rank: Int
    let entry: LeaderboardEntry
    let height: CGFloat
    let isCurrentUser: Bool

    private var medalEmoji: String {
        switch rank {
        case 1: return "👑"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(medalEmoji)
                .font(.title2)

            Text(entry.profileEmoji ?? "😀")
                .font(.title)

            Text(entry.displayName)
                .font(.caption)
                .fontWeight(isCurrentUser ? .bold : .regular)
                .lineLimit(1)

            RoundedRectangle(cornerRadius: 8)
                .fill(rank == 1 ? Color.appAmber.opacity(0.3) : Color(.secondarySystemBackground))
                .frame(height: height)
                .overlay(
                    Text("\(entry.allTimeCheckIns)")
                        .font(.headline)
                        .fontWeight(.bold)
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Leaderboard Row

struct LeaderboardRow: View {
    let rank: Int
    let entry: LeaderboardEntry
    let isCurrentUser: Bool
    let timeframe: LeaderboardTimeframe

    private var medalEmoji: String? {
        switch rank {
        case 1: return "👑"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return nil
        }
    }

    private var checkInCount: Int {
        switch timeframe {
        case .monthly: return entry.effectiveMonthlyCheckIns
        case .allTime: return entry.allTimeCheckIns
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Rank
            if let medal = medalEmoji {
                Text(medal)
                    .font(.body)
                    .frame(width: 30)
            } else {
                Text("#\(rank)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }

            // Profile emoji
            Text(entry.profileEmoji ?? "😀")
                .font(.title3)

            // Name + level
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.subheadline)
                    .fontWeight(isCurrentUser ? .bold : .regular)

                if entry.level > 0 {
                    Text("Level \(entry.level)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Check-in count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(checkInCount)")
                    .font(.headline)
                    .fontWeight(.bold)

                Text(checkInCount == 1 ? "visit" : "visits")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCurrentUser ? Color.appBlue.opacity(0.1) : Color(.systemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Rank \(rank), \(entry.displayName), \(checkInCount) visits")
    }
}

// MARK: - Leaderboard Preview Card (for GroupDetailView)

struct LeaderboardPreviewCard: View {
    let groupId: String
    let groupName: String

    @State private var topEntries: [LeaderboardEntry] = []
    @State private var isLoading = true

    private let currentUserId = Auth.auth().currentUser?.uid

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.appAmber)
                Text("Leaderboard")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    LeaderboardView(groupId: groupId, groupName: groupName)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.appBlue)
                }
            }

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if topEntries.isEmpty {
                Text("No check-ins yet this month")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(topEntries.prefix(3).enumerated()), id: \.element.userId) { index, entry in
                    HStack(spacing: 10) {
                        // Medal/rank
                        Text(index == 0 ? "👑" : index == 1 ? "🥈" : "🥉")
                            .font(.body)

                        Text(entry.profileEmoji ?? "😀")
                            .font(.body)

                        Text(entry.displayName)
                            .font(.subheadline)
                            .fontWeight(entry.userId == currentUserId ? .bold : .regular)
                            .lineLimit(1)

                        Spacer()

                        Text("\(entry.effectiveMonthlyCheckIns)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.appBlue)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .task {
            topEntries = await FirestoreService.shared.fetchLeaderboard(groupId: groupId, timeframe: .monthly)
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        LeaderboardView(groupId: "test", groupName: "Test Group")
    }
}
