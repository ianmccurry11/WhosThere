//
//  FriendsListView.swift
//  WhosThereios
//
//  Created by Claude on 1/20/26.
//

import SwiftUI

struct FriendsListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendService = FriendService.shared

    @State private var showAddFriend = false
    @State private var showRequests = false
    @State private var friendToRemove: Friend?
    @State private var showRemoveConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                // Pending Requests Banner
                if !friendService.pendingRequests.isEmpty {
                    Section {
                        Button {
                            showRequests = true
                        } label: {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                    .foregroundColor(.orange)
                                Text("\(friendService.pendingRequests.count) pending request\(friendService.pendingRequests.count == 1 ? "" : "s")")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Friends at a Location
                if !friendService.friendsAtLocation.isEmpty {
                    Section {
                        ForEach(friendService.friendsAtLocation) { presence in
                            FriendAtLocationRow(presence: presence)
                        }
                    } header: {
                        Label("At a Location", systemImage: "mappin.circle.fill")
                    }
                }

                // All Friends
                Section {
                    if friendService.friends.isEmpty {
                        ContentUnavailableView(
                            "No Friends Yet",
                            systemImage: "person.2",
                            description: Text("Add friends to see when they're at your shared locations")
                        )
                    } else {
                        ForEach(friendService.friendsNotAtLocation) { friend in
                            FriendRow(friend: friend)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        friendToRemove = friend
                                        showRemoveConfirmation = true
                                    } label: {
                                        Label("Remove", systemImage: "person.badge.minus")
                                    }
                                }
                        }

                        // Also show friends at location here for completeness
                        ForEach(friendService.friendsAtLocation) { presence in
                            if let friend = friendService.friends.first(where: { $0.id == presence.friendId }) {
                                FriendRow(friend: friend, isAtLocation: true)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            friendToRemove = friend
                                            showRemoveConfirmation = true
                                        } label: {
                                            Label("Remove", systemImage: "person.badge.minus")
                                        }
                                    }
                            }
                        }
                    }
                } header: {
                    if !friendService.friends.isEmpty {
                        Label("All Friends (\(friendService.friends.count))", systemImage: "person.2")
                    }
                }
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView()
            }
            .sheet(isPresented: $showRequests) {
                FriendRequestsView()
            }
            .confirmationDialog(
                "Remove Friend",
                isPresented: $showRemoveConfirmation,
                presenting: friendToRemove
            ) { friend in
                Button("Remove \(friend.displayName ?? "friend")", role: .destructive) {
                    Task {
                        if let friendId = friend.id {
                            try? await friendService.removeFriend(friendId)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { friend in
                Text("Are you sure you want to remove \(friend.displayName ?? "this friend")? You'll need to send a new friend request to add them back.")
            }
            .refreshable {
                await friendService.loadFriends()
            }
        }
    }
}

// MARK: - Friend Row

struct FriendRow: View {
    let friend: Friend
    var isAtLocation: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(friend.displayName?.prefix(1).uppercased() ?? "?")
                        .font(.headline)
                        .foregroundColor(.primary)
                }

            // Name and tag
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.displayName ?? "Unknown")
                    .font(.body)
                    .fontWeight(.medium)

                Text("#\(friend.discriminator ?? "0000")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            if isAtLocation {
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Friend at Location Row

struct FriendAtLocationRow: View {
    let presence: FriendPresenceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Avatar with green ring
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Text(presence.displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .overlay {
                        Circle()
                            .stroke(.green, lineWidth: 3)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(presence.displayName)
                        .font(.body)
                        .fontWeight(.semibold)

                    // Show locations
                    ForEach(presence.currentGroups) { group in
                        HStack(spacing: 4) {
                            Text(group.groupEmoji)
                                .font(.caption)
                            Text(group.groupName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FriendsListView()
}
