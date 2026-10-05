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

    @AppStorage("nearbyRadiusKm") private var nearbyRadiusKm: Double = 50
    @State private var searchText = ""
    @State private var selectedGroup: LocationGroup?
    @State private var showJoinByCode = false
    @State private var inviteCode = ""

    private static let radiusSteps: [Double] = [1, 2, 5, 10, 25, 50]

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
                    .accessibilityLabel("Join by invite code")
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Favorite Groups Section
                if !favoriteGroups.isEmpty {
                    GroupSection(
                        title: "Favorites",
                        groups: favoriteGroups,
                        showFavoriteToggle: true,
                        onGroupTap: { group in
                            selectedGroup = group
                        }
                    )
                }

                // Joined Groups Section (excluding favorites)
                if !nonFavoriteJoinedGroups.isEmpty {
                    GroupSection(
                        title: "Your Groups",
                        groups: nonFavoriteJoinedGroups,
                        showFavoriteToggle: true,
                        onGroupTap: { group in
                            selectedGroup = group
                        }
                    )
                }

                // Public Groups Section
                if !filteredPublicGroups.isEmpty || !publicGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        // Section header with radius picker
                        HStack {
                            Text("Public Groups Nearby")
                                .font(.headline)

                            Spacer()

                            Menu {
                                ForEach(Self.radiusSteps, id: \.self) { km in
                                    Button {
                                        nearbyRadiusKm = km
                                    } label: {
                                        HStack {
                                            Text(km < 50 ? "\(Int(km)) km" : "50+ km")
                                            if nearbyRadiusKm == km {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "line.3.horizontal.decrease.circle")
                                        .font(.subheadline)
                                    Text(nearbyRadiusKm < 50 ? "\(Int(nearbyRadiusKm)) km" : "All")
                                        .font(.subheadline)
                                }
                                .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Filter radius: \(nearbyRadiusKm < 50 ? "\(Int(nearbyRadiusKm)) kilometers" : "All distances")")
                            .accessibilityHint("Tap to change the search radius")
                        }
                        .padding(.horizontal)

                        if filteredPublicGroups.isEmpty {
                            Text("No public groups within \(Int(nearbyRadiusKm)) km")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredPublicGroups) { group in
                                    GroupRowButton(group: group, onTap: {
                                        HapticManager.light()
                                        selectedGroup = group
                                    })
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Empty State
                if joinedGroups.isEmpty && filteredPublicGroups.isEmpty && publicGroups.isEmpty {
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

    private var favoriteGroups: [LocationGroup] {
        let favoriteIds = Set(firestoreService.currentUser?.favoriteGroupIds ?? [])
        return joinedGroups.filter { group in
            guard let id = group.id else { return false }
            return favoriteIds.contains(id)
        }
    }

    private var nonFavoriteJoinedGroups: [LocationGroup] {
        let favoriteIds = Set(firestoreService.currentUser?.favoriteGroupIds ?? [])
        return joinedGroups.filter { group in
            guard let id = group.id else { return true }
            return !favoriteIds.contains(id)
        }
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

    private var filteredPublicGroups: [LocationGroup] {
        guard nearbyRadiusKm < 50 else { return publicGroups }
        let radiusMeters = nearbyRadiusKm * 1000
        return publicGroups.filter { group in
            guard let distance = locationService.distanceToGroup(group) else { return true }
            return distance <= radiusMeters
        }
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
    var showFavoriteToggle: Bool = false
    let onGroupTap: (LocationGroup) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)

            LazyVStack(spacing: 12) {
                ForEach(groups) { group in
                    GroupRowButton(group: group, showFavoriteToggle: showFavoriteToggle, onTap: {
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
    var showFavoriteToggle: Bool = false
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        GroupRowView(group: group, showFavoriteToggle: showFavoriteToggle)
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
    var showFavoriteToggle: Bool = false
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

                GroupIconView(icon: group.displayEmoji, size: 28)
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
                            .accessibilityLabel("Private group")
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

            // Favorite toggle
            if showFavoriteToggle, isJoined {
                Button {
                    HapticManager.light()
                    Task {
                        if let groupId = group.id {
                            await firestoreService.toggleFavoriteGroup(groupId: groupId)
                        }
                    }
                } label: {
                    Image(systemName: isFavorited ? "star.fill" : "star")
                        .font(.body)
                        .foregroundColor(isFavorited ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorited ? "Remove from favorites" : "Add to favorites")
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .appShadow.opacity(0.5), radius: 5, y: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(group.name)\(!group.isPublic ? ", private group" : ""), \(presenceService.formatPresenceDisplay(for: group))\(distanceText.map { ", \($0)" } ?? "")")
        .accessibilityHint("Tap to view group details")
    }

    private var isJoined: Bool {
        guard let groupId = group.id else { return false }
        return firestoreService.currentUser?.joinedGroupIds.contains(groupId) ?? false
    }

    private var isFavorited: Bool {
        guard let groupId = group.id else { return false }
        return firestoreService.isGroupFavorited(groupId: groupId)
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
        EmptyStateView(
            icon: "map",
            title: "No Groups Yet",
            message: "Create a group for your favorite spot or join a public group nearby."
        )
    }
}

#Preview {
    ListTabView()
}
