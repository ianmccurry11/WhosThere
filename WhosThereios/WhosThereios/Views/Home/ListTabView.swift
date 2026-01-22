//
//  ListTabView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import CoreLocation

struct ListTabView: View {
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var firestoreService = FirestoreService.shared
    @ObservedObject private var presenceService = PresenceService.shared

    @State private var searchText = ""
    @State private var selectedGroup: LocationGroup?
    @State private var showJoinByCode = false
    @State private var inviteCode = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Search and Join by Code
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search groups...", text: $searchText)
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    Button(action: { showJoinByCode = true }) {
                        Image(systemName: "qrcode")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Joined Groups Section
                if !joinedGroups.isEmpty {
                    GroupSection(
                        title: "Your Groups",
                        groups: joinedGroups,
                        onGroupTap: { group in
                            selectedGroup = group
                        }
                    )
                }

                // Public Groups Section
                if !publicGroups.isEmpty {
                    GroupSection(
                        title: "Public Groups Nearby",
                        groups: publicGroups,
                        onGroupTap: { group in
                            selectedGroup = group
                        }
                    )
                }

                // Empty State
                if joinedGroups.isEmpty && publicGroups.isEmpty {
                    EmptyGroupsView()
                }

                Spacer(minLength: 100)
            }
        }
        .refreshable {
            await refreshData()
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailView(group: group)
        }
        .alert("Join by Invite Code", isPresented: $showJoinByCode) {
            TextField("Enter code", text: $inviteCode)
                .textInputAutocapitalization(.characters)
            Button("Cancel", role: .cancel) {
                inviteCode = ""
            }
            Button("Join") {
                Task {
                    await joinByCode()
                }
            }
        } message: {
            Text("Enter the 6-character invite code to join a private group.")
        }
    }

    private var joinedGroups: [LocationGroup] {
        let groups = firestoreService.joinedGroups
        if searchText.isEmpty {
            return groups
        }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var publicGroups: [LocationGroup] {
        let joined = Set(firestoreService.currentUser?.joinedGroupIds ?? [])
        let groups = firestoreService.publicGroups.filter { group in
            guard let id = group.id else { return false }
            return !joined.contains(id)
        }
        if searchText.isEmpty {
            return groups
        }
        return groups.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func refreshData() async {
        await firestoreService.fetchCurrentUser()
        await firestoreService.fetchJoinedGroups()
        if let location = locationService.currentLocation {
            await firestoreService.fetchNearbyGroups(center: location.coordinate)
        }
    }

    private func joinByCode() async {
        guard !inviteCode.isEmpty else { return }

        if let group = await firestoreService.findGroupByInviteCode(inviteCode.uppercased()),
           let groupId = group.id {
            _ = await firestoreService.joinGroup(groupId: groupId)
        }

        inviteCode = ""
    }
}

struct GroupSection: View {
    let title: String
    let groups: [LocationGroup]
    let onGroupTap: (LocationGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            LazyVStack(spacing: 12) {
                ForEach(groups) { group in
                    GroupRowButton(group: group, onTap: {
                        HapticManager.light()
                        onGroupTap(group)
                    })
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Group Row Button (with animation)

struct GroupRowButton: View {
    let group: LocationGroup
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        GroupRowView(group: group)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

// MARK: - Group Row View

struct GroupRowView: View {
    let group: LocationGroup
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var firestoreService = FirestoreService.shared
    @ObservedObject private var presenceService = PresenceService.shared

    var body: some View {
        HStack(spacing: 16) {
            // Icon - show emoji if available
            ZStack {
                Circle()
                    .fill(isJoined ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                    .frame(width: 50, height: 50)

                Text(group.displayEmoji)
                    .font(.title2)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.headline)

                    // Show lock icon for private groups
                    if !group.isPublic {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(presenceService.formatPresenceDisplay(for: group))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let distance = distanceText {
                    Text(distance)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private var isJoined: Bool {
        guard let groupId = group.id else { return false }
        return firestoreService.currentUser?.joinedGroupIds.contains(groupId) ?? false
    }

    private var distanceText: String? {
        guard let distance = locationService.distanceToGroup(group) else { return nil }

        if distance < 1000 {
            return "\(Int(distance))m away"
        } else {
            let km = distance / 1000
            return String(format: "%.1f km away", km)
        }
    }
}

struct EmptyGroupsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Groups Yet")
                .font(.headline)

            Text("Create a group for your favorite spot or join a public group nearby.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 48)
    }
}

#Preview {
    ListTabView()
}
