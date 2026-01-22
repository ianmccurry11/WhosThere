//
//  GroupDetailView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import MapKit
import FirebaseAuth

struct GroupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var firestoreService = FirestoreService.shared
    @ObservedObject private var presenceService = PresenceService.shared

    let group: LocationGroup

    @State private var presences: [Presence] = []
    @State private var isJoined = false
    @State private var isOwner = false
    @State private var isPresent = false
    @State private var showSettings = false
    @State private var showLeaveConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var copiedInviteCode = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var mapId = UUID()  // Force map to re-render if needed

    /// Check if the group has valid coordinates for display
    private var hasValidCoordinates: Bool {
        let lat = group.centerLatitude
        let lng = group.centerLongitude
        // Check that coordinates are not (0,0) and are within valid ranges
        return !(lat == 0 && lng == 0) &&
               lat >= -90 && lat <= 90 &&
               lng >= -180 && lng <= 180
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Map with boundary - only show if valid coordinates
                    if hasValidCoordinates {
                        Map(position: $mapPosition) {
                            if group.boundaryCoordinates.count >= 3 {
                                MapPolygon(coordinates: group.boundaryCoordinates)
                                    .stroke(group.displayColor, lineWidth: 3)
                                    .foregroundStyle(group.displayColor.opacity(0.2))
                            }

                            UserAnnotation()

                            // Center marker
                            Annotation(group.name, coordinate: group.center) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundColor(group.displayColor)
                            }
                        }
                        .id(mapId)  // Force re-render when needed
                        .frame(height: 200)
                        .allowsHitTesting(false)
                        .onAppear {
                            // Set camera to show the group's boundary
                            let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            let region = MKCoordinateRegion(center: group.center, span: span)
                            mapPosition = .region(region)
                        }
                    } else {
                        // Fallback when coordinates are invalid
                        ZStack {
                            Color(.systemGray5)
                            VStack {
                                Image(systemName: "map")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Map unavailable")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(height: 200)
                    }

                    VStack(spacing: 20) {
                        // Group Info Card
                        VStack(spacing: 12) {
                            HStack {
                                // Emoji icon
                                Text(group.displayEmoji)
                                    .font(.system(size: 40))
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(group.name)
                                            .font(.title2)
                                            .fontWeight(.bold)

                                        Image(systemName: group.isPublic ? "globe" : "lock.fill")
                                            .foregroundColor(.secondary)
                                    }

                                    Text(presenceService.formatPresenceDisplay(for: group))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }

                            // Check-in/out button (if joined)
                            if isJoined {
                                Button(action: {
                                    HapticManager.medium()
                                    Task {
                                        await togglePresence()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: isPresent ? "checkmark.circle.fill" : "circle")
                                            .symbolEffect(.bounce, value: isPresent)
                                        Text(isPresent ? "Checked In" : "Check In")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isPresent ? Color.green : Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPresent)

                                // Show auto check-out timer if active
                                if isPresent,
                                   let groupId = group.id,
                                   let remaining = presenceService.remainingAutoCheckOutTime(groupId: groupId) {
                                    HStack {
                                        Image(systemName: "timer")
                                            .foregroundColor(.orange)
                                        Text("Auto check-out in \(formatTimeRemaining(remaining))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)

                        // Invite Code (for private groups)
                        if !group.isPublic, let inviteCode = group.inviteCode, isJoined {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Invite Code")
                                        .font(.headline)
                                    Spacer()
                                }

                                HStack {
                                    Text(inviteCode)
                                        .font(.system(.title2, design: .monospaced))
                                        .fontWeight(.bold)

                                    Spacer()

                                    Button(action: copyInviteCode) {
                                        Image(systemName: copiedInviteCode ? "checkmark" : "doc.on.doc")
                                            .foregroundColor(copiedInviteCode ? .green : .blue)
                                    }
                                }

                                Text("Share this code to invite others to join")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                        }

                        // Group Chat Section
                        if isJoined {
                            ChatPreviewRow(group: group)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(16)
                        }

                        // Members Present Section
                        if isJoined && group.presenceDisplayMode == .names && !presences.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Who's Here")
                                    .font(.headline)

                                ForEach(presences) { presence in
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.green)
                                            .frame(width: 10, height: 10)

                                        Text(presence.displayName ?? "Unknown")
                                            .font(.subheadline)

                                        Spacer()

                                        if presence.isManual {
                                            Text("Manual")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                        }

                        // Actions
                        VStack(spacing: 12) {
                            if !isJoined {
                                Button(action: {
                                    Task {
                                        await joinGroup()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "person.badge.plus")
                                        Text("Join Group")
                                    }
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                            } else {
                                if isOwner {
                                    Button(action: { showSettings = true }) {
                                        HStack {
                                            Image(systemName: "gearshape")
                                            Text("Group Settings")
                                        }
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                    }

                                    Button(action: { showDeleteConfirmation = true }) {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("Delete Group")
                                        }
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red.opacity(0.1))
                                        .foregroundColor(.red)
                                        .cornerRadius(12)
                                    }
                                } else {
                                    Button(action: {
                                        print("Leave Group button tapped")
                                        showLeaveConfirmation = true
                                    }) {
                                        HStack {
                                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                            Text("Leave Group")
                                        }
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemGray5))
                                        .foregroundColor(.primary)
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            print("GroupDetailView appeared for: \(group.name)")
            print("  - ID: \(group.id ?? "nil")")
            print("  - Center: (\(group.centerLatitude), \(group.centerLongitude))")
            print("  - Boundary points: \(group.boundary.count)")
            print("  - Has valid coords: \(hasValidCoordinates)")

            setupState()
            Task {
                await loadPresence()
            }
        }
        .task {
            // Refresh map after a short delay to ensure it renders
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
            if hasValidCoordinates {
                mapId = UUID()  // Force map refresh
            }
        }
        .sheet(isPresented: $showSettings) {
            GroupSettingsView(group: group)
        }
        .alert("Leave LocationGroup?", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task {
                    await leaveGroup()
                }
            }
        } message: {
            Text("You will no longer see this group or receive presence updates.")
        }
        .alert("Delete LocationGroup?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await deleteGroup()
                }
            }
        } message: {
            Text("This will permanently delete the group for all members. This action cannot be undone.")
        }
    }

    private func setupState() {
        print("setupState() called for group: \(group.name)")
        print("Group ID: \(group.id ?? "nil")")

        guard let userId = Auth.auth().currentUser?.uid else {
            print("No user ID found")
            return
        }

        print("User ID: \(userId)")
        print("Group owner ID: \(group.ownerId)")

        // Check if user is the owner
        isOwner = group.ownerId == userId

        if let groupId = group.id {
            // Check if user has joined this group, OR if they're the owner (owner is always joined)
            let inJoinedList = firestoreService.currentUser?.joinedGroupIds.contains(groupId) ?? false
            isJoined = inJoinedList || isOwner || group.memberIds.contains(userId)
            isPresent = presenceService.isUserPresent(groupId: groupId, userId: userId)
        } else {
            // If group.id is nil, assume joined if we're the owner
            isJoined = isOwner
        }

        print("isJoined: \(isJoined), isOwner: \(isOwner), isPresent: \(isPresent)")
    }

    private func loadPresence() async {
        guard let groupId = group.id else { return }
        presences = await firestoreService.fetchPresenceForGroup(groupId: groupId)

        if let userId = Auth.auth().currentUser?.uid {
            isPresent = presences.contains { $0.userId == userId }
        }
    }

    private func togglePresence() async {
        guard let groupId = group.id else { return }

        if isPresent {
            await presenceService.manualCheckOut(groupId: groupId)
        } else {
            await presenceService.manualCheckIn(groupId: groupId)
        }

        isPresent.toggle()
        await loadPresence()
    }

    private func joinGroup() async {
        guard let groupId = group.id else { return }
        let result = await firestoreService.joinGroup(groupId: groupId)
        if case .success = result {
            isJoined = true
            presenceService.startMonitoring(groups: firestoreService.joinedGroups)
        }
    }

    private func leaveGroup() async {
        guard let groupId = group.id else { return }
        let result = await firestoreService.leaveGroup(groupId: groupId)
        if case .success = result {
            dismiss()
        }
    }

    private func deleteGroup() async {
        guard let groupId = group.id else { return }
        let result = await firestoreService.deleteGroup(groupId: groupId)
        if case .success = result {
            dismiss()
        }
    }

    private func copyInviteCode() {
        guard let code = group.inviteCode else { return }
        UIPasteboard.general.string = code
        copiedInviteCode = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copiedInviteCode = false
        }
    }

    private func formatTimeRemaining(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    GroupDetailView(group: LocationGroup(
        name: "Test Court",
        isPublic: true,
        ownerId: "123",
        boundary: [
            Coordinate(latitude: 37.7749, longitude: -122.4194),
            Coordinate(latitude: 37.7759, longitude: -122.4194),
            Coordinate(latitude: 37.7759, longitude: -122.4184),
            Coordinate(latitude: 37.7749, longitude: -122.4184)
        ]
    ))
}
