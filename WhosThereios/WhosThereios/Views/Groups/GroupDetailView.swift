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
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var friendService = FriendService.shared

    let group: LocationGroup

    @State private var isJoined = false
    @State private var isOwner = false
    @State private var showSettings = false
    @State private var showLeaveConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var copiedInviteCode = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var mapId = UUID()  // Force map to re-render if needed
    @State private var reportingPresence: Presence?
    @State private var profilePresence: Presence?
    @State private var friendRequestAlertMessage: String?
    @State private var showFriendRequestAlert = false

    /// Everyone here right now — the same live data the map bubble uses
    private var presences: [Presence] {
        guard let groupId = group.id else { return [] }
        return presenceService.presenceByGroup[groupId]?.presentMembers ?? []
    }

    private var isPresent: Bool {
        guard let userId = Auth.auth().currentUser?.uid else { return false }
        return presences.contains { $0.userId == userId }
    }

    /// Checking out always works; checking in only near the group
    private var canTogglePresence: Bool {
        isPresent || presenceService.manualCheckInAvailability(for: group) == .allowed
    }

    private var checkInButtonColor: Color {
        if isPresent { return .green }
        return canTogglePresence ? .blue : .gray
    }

    /// Why Check In is disabled, or nil when it isn't
    private var checkInUnavailableReason: String? {
        guard !isPresent else { return nil }
        switch presenceService.manualCheckInAvailability(for: group) {
        case .allowed:
            return nil
        case .noLocation:
            return "Finding your location…"
        case .tooFar(let meters):
            let distance = Measurement(value: meters, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .road))
            return "You need to be at \(group.name) to check in (\(distance) away)"
        }
    }

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
                    // Offline banner
                    if !networkMonitor.isConnected {
                        StatusBanner(message: "You're offline. Some actions may not work.", type: .offline)
                    }

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
                        .accessibilityLabel("Map showing \(group.name) boundary")
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
                            VStack(spacing: 8) {
                                Image(systemName: "map")
                                    .font(.largeTitle)
                                    .foregroundColor(.secondary)
                                Text("Map unavailable")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("This group's location hasn't been set up yet.")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(height: 200)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Map unavailable. This group's location hasn't been set up yet.")
                    }

                    VStack(spacing: 20) {
                        // Group Info Card
                        VStack(spacing: 12) {
                            HStack {
                                // Emoji icon
                                GroupIconView(icon: group.displayEmoji, size: 40)
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(group.name)
                                            .font(.title2)
                                            .fontWeight(.bold)

                                        Image(systemName: group.isPublic ? "globe" : "lock.fill")
                                            .foregroundColor(.secondary)
                                            .accessibilityLabel(group.isPublic ? "Public group" : "Private group")
                                    }

                                    Text(presenceService.formatPresenceDisplay(for: group))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()

                                // Favorite toggle
                                if isJoined {
                                    Button {
                                        HapticManager.light()
                                        Task {
                                            if let groupId = group.id {
                                                await firestoreService.toggleFavoriteGroup(groupId: groupId)
                                            }
                                        }
                                    } label: {
                                        Image(systemName: firestoreService.isGroupFavorited(groupId: group.id ?? "") ? "star.fill" : "star")
                                            .font(.title2)
                                            .foregroundColor(firestoreService.isGroupFavorited(groupId: group.id ?? "") ? .yellow : .secondary)
                                    }
                                    .accessibilityLabel(firestoreService.isGroupFavorited(groupId: group.id ?? "") ? "Remove from favorites" : "Add to favorites")
                                }
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
                                    .background(checkInButtonColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(!canTogglePresence)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isPresent)
                                .accessibilityLabel(isPresent ? "Checked in. Tap to check out." : "Not checked in. Tap to check in.")
                                .accessibilityHint(checkInUnavailableReason ?? "")

                                // Manual check-in only works near the group
                                if let reason = checkInUnavailableReason {
                                    HStack(spacing: 6) {
                                        Image(systemName: "location.slash")
                                            .accessibilityHidden(true)
                                        Text(reason)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                }

                                // Show auto check-out timer if active
                                if isPresent,
                                   let groupId = group.id,
                                   let remaining = presenceService.remainingAutoCheckOutTime(groupId: groupId) {
                                    HStack {
                                        Image(systemName: "timer")
                                            .foregroundColor(.orange)
                                            .accessibilityHidden(true)
                                        Text("Auto check-out in \(formatTimeRemaining(remaining))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 4)
                                    .accessibilityElement(children: .combine)
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
                                    .accessibilityLabel(copiedInviteCode ? "Copied" : "Copy invite code")
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
                                    WhoIsHereRow(presence: presence)
                                    .contextMenu {
                                        // Only show actions for other users, not yourself
                                        if presence.userId != Auth.auth().currentUser?.uid {
                                            Button {
                                                profilePresence = presence
                                            } label: {
                                                Label("View Profile", systemImage: "person.circle")
                                            }

                                            Divider()

                                            let isFriend = friendService.friends.contains(where: { $0.id == presence.userId })
                                            let hasPendingRequest = friendService.sentRequests.contains(where: { $0.receiverId == presence.userId })

                                            if isFriend {
                                                Label("Already Friends", systemImage: "person.2.fill")
                                            } else if hasPendingRequest {
                                                Label("Request Sent", systemImage: "person.badge.clock")
                                            } else {
                                                Button {
                                                    Task {
                                                        await sendFriendRequest(to: presence)
                                                    }
                                                } label: {
                                                    Label("Send Friend Request", systemImage: "person.badge.plus")
                                                }
                                            }

                                            Button(role: .destructive) {
                                                reportingPresence = presence
                                            } label: {
                                                Label("Report User", systemImage: "flag")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                        }

                        // Leaderboard Preview
                        if isJoined, let groupId = group.id {
                            LeaderboardPreviewCard(groupId: groupId, groupName: group.name)
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
                                    .background(networkMonitor.isConnected ? Color.blue : Color.gray)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                }
                                .disabled(!networkMonitor.isConnected)
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
                                        AppLogger.debug("Leave Group button tapped")
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

                if isJoined, let inviteCode = group.inviteCode,
                   let shareURL = DeepLinkService.shared.generateShareLink(inviteCode: inviteCode) {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: shareURL, subject: Text("Join \(group.name)"), message: Text("Join my group \"\(group.name)\" on Who's There!")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            Task { await AchievementService.shared.recordGroupShared() }
                        })
                    }
                }

                if isJoined && group.isPublic, let groupId = group.id,
                   let shareURL = DeepLinkService.shared.generateGroupLink(groupId: groupId) {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: shareURL, subject: Text("Join \(group.name)"), message: Text("Join \"\(group.name)\" on Who's There!")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            Task { await AchievementService.shared.recordGroupShared() }
                        })
                    }
                }
            }
        }
        .onAppear {
            AppLogger.debug("GroupDetailView appeared for: \(group.name)")
            AppLogger.debug("  - ID: \(group.id ?? "nil")")
            AppLogger.debug("  - Center: (\(group.centerLatitude), \(group.centerLongitude))")
            AppLogger.debug("  - Boundary points: \(group.boundary.count)")
            AppLogger.debug("  - Has valid coords: \(hasValidCoordinates)")

            setupState()
            // Guarantees a live listener even if this group isn't on the map/list
            presenceService.focusPresence(on: group.id)
            presenceService.requestRecheckIfNeeded(groupId: group.id)
        }
        .onDisappear {
            presenceService.focusPresence(on: nil)
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
        .sheet(item: $profilePresence) { presence in
            UserProfileView(
                userId: presence.userId,
                displayName: presence.displayName ?? "Unknown"
            )
        }
        .sheet(item: $reportingPresence) { presence in
            ReportUserView(
                reportedUserId: presence.userId,
                reportedDisplayName: presence.displayName ?? "Unknown",
                context: .presence,
                groupId: group.id
            )
        }
        .alert("Friend Request", isPresented: $showFriendRequestAlert) {
            Button("OK") {}
        } message: {
            Text(friendRequestAlertMessage ?? "")
        }
        .alert("Leave \(group.name)?", isPresented: $showLeaveConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task {
                    await leaveGroup()
                }
            }
        } message: {
            Text("You will no longer see this group or receive presence updates.")
        }
        .alert("Delete \(group.name)?", isPresented: $showDeleteConfirmation) {
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
        AppLogger.debug("setupState() called for group: \(group.name)")
        AppLogger.debug("Group ID: \(group.id ?? "nil")")

        guard let userId = Auth.auth().currentUser?.uid else {
            AppLogger.debug("No user ID found")
            return
        }

        AppLogger.debug("User ID: \(userId)")
        AppLogger.debug("Group owner ID: \(group.ownerId)")

        // Check if user is the owner
        isOwner = group.ownerId == userId

        if let groupId = group.id {
            // Check if user has joined this group, OR if they're the owner (owner is always joined)
            let inJoinedList = firestoreService.currentUser?.joinedGroupIds.contains(groupId) ?? false
            isJoined = inJoinedList || isOwner || group.memberIds.contains(userId)
        } else {
            // If group.id is nil, assume joined if we're the owner
            isJoined = isOwner
        }

        AppLogger.debug("isJoined: \(isJoined), isOwner: \(isOwner), isPresent: \(isPresent)")
    }

    private func togglePresence() async {
        guard let groupId = group.id else { return }

        if isPresent {
            await presenceService.manualCheckOut(groupId: groupId)
        } else if !(await presenceService.manualCheckIn(groupId: groupId)) {
            // Location moved out of range between showing the button and tapping it
            HapticManager.error()
        }
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

    private func sendFriendRequest(to presence: Presence) async {
        do {
            try await FriendService.shared.sendFriendRequest(toUserId: presence.userId)
            HapticManager.light()
            friendRequestAlertMessage = "Friend request sent to \(presence.displayName ?? "this user")!"
        } catch let error as FriendError {
            friendRequestAlertMessage = error.errorDescription ?? "Could not send friend request"
        } catch {
            friendRequestAlertMessage = "Could not send friend request"
        }
        showFriendRequestAlert = true
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

/// One person in the "Who's Here" list. Automatic check-ins that haven't been
/// confirmed in the last 30 minutes are faded with "confirmed 1h ago".
private struct WhoIsHereRow: View {
    let presence: Presence

    var body: some View {
        // Re-evaluates the "confirmed …" label every minute
        TimelineView(.everyMinute) { context in
            let confirmation = presence.confirmationLabel(at: context.date)

            HStack(spacing: 12) {
                Circle()
                    .fill(confirmation == nil ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)

                if let level = presence.level, level > 0 {
                    LevelBadge(level: level)
                }

                Text(presence.displayName ?? "Unknown")
                    .font(.subheadline)

                Spacer()

                if presence.isManual {
                    Text("Manual")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let confirmation {
                    Text(confirmation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .opacity(confirmation == nil ? 1 : 0.6)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText(confirmation: confirmation))
        }
    }

    private func accessibilityText(confirmation: String?) -> String {
        var text = "\(presence.displayName ?? "Unknown") is here"
        if presence.isManual {
            text += ", manual check-in"
        } else if let confirmation {
            text += ", \(confirmation)"
        }
        return text
    }
}
