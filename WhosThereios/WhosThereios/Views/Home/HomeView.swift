//
//  HomeView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import CoreLocation

struct HomeView: View {
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var firestoreService = FirestoreService.shared
    @ObservedObject private var presenceService = PresenceService.shared
    @ObservedObject private var achievementService = AchievementService.shared
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var friendService = FriendService.shared
    @ObservedObject private var deepLinkService = DeepLinkService.shared
    @ObservedObject private var levelService = LevelService.shared
    @StateObject private var authService = AuthService()

    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var showCreateGroup = false
    @State private var showProfile = false
    @State private var showProfileForNameEdit = false
    @State private var showFriendsList = false
    @State private var showConfetti = false
    @State private var notificationGroup: LocationGroup?
    @State private var deepLinkPreviewGroup: LocationGroup?
    @State private var dismissedNameBanner = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Offline banner
                    if !networkMonitor.isConnected {
                        StatusBanner(message: "No internet connection", type: .offline)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Name nudge banner
                    if showNameNudge {
                        HStack(spacing: 12) {
                            Image(systemName: "person.text.rectangle")
                                .font(.body)

                            Text("Set your name so friends can find you")
                                .font(.subheadline)

                            Spacer()

                            Button("Set Name") {
                                showProfileForNameEdit = true
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)

                            Button {
                                withAnimation {
                                    dismissedNameBanner = true
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.appBlue)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    TabView(selection: $selectedTab) {
                        MapTabView()
                            .tag(0)

                        ListTabView()
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .animation(.easeInOut(duration: 0.3), value: networkMonitor.isConnected)
                .animation(.easeInOut(duration: 0.3), value: showNameNudge)

                // Custom Tab Bar
                CustomTabBar(
                    selectedTab: $selectedTab,
                    onCreateTapped: { showCreateGroup = true },
                    onProfileTapped: { showProfile = true }
                )

                // Achievement unlocked toast
                if let achievement = achievementService.newlyUnlockedAchievement {
                    VStack {
                        AchievementUnlockedToast(achievement: achievement)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, networkMonitor.isConnected ? 60 : 100)
                        Spacer()
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: achievementService.newlyUnlockedAchievement != nil)
                    .onAppear {
                        showConfetti = true
                    }
                }

                // Level-up toast
                if let newLevel = levelService.newlyReachedLevel {
                    VStack {
                        LevelUpToast(level: newLevel)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .padding(.top, networkMonitor.isConnected ? 60 : 100)
                        Spacer()
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: levelService.newlyReachedLevel)
                }
            }
            .confetti(isActive: $showConfetti)
            .ignoresSafeArea(edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showFriendsList = true }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "person.2")
                                .font(.title3)

                            // Badge for pending requests
                            if friendService.pendingRequests.count > 0 {
                                Text("\(min(friendService.pendingRequests.count, 99))")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Circle().fill(.red))
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .accessibilityLabel("Friends")
                    .accessibilityHint(friendService.pendingRequests.isEmpty ? "View your friends list" : "\(friendService.pendingRequests.count) pending friend requests")
                }
                ToolbarItem(placement: .principal) {
                    Text("Who's There")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showProfile = true }) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("Profile")
                    .accessibilityHint("View your profile and settings")
                }
            }
        }
        .sheet(isPresented: $showCreateGroup, onDismiss: {
            // Refresh data after creating a group
            Task {
                await refreshData()
            }
        }) {
            CreateGroupView()
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(authService: authService)
        }
        .sheet(isPresented: $showProfileForNameEdit) {
            ProfileView(authService: authService, startEditingName: true)
        }
        .sheet(isPresented: $showFriendsList) {
            FriendsListView()
        }
        .sheet(item: $notificationGroup) { group in
            GroupDetailView(group: group)
        }
        .task {
            await initializeData()
        }
        .onAppear {
            locationService.requestAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openGroup)) { notification in
            if let groupId = notification.userInfo?["groupId"] as? String {
                Task {
                    if let group = await firestoreService.fetchGroupById(groupId) {
                        notificationGroup = group
                    }
                }
            }
        }
        .onChange(of: deepLinkService.pendingGroupId) { _, groupId in
            guard let groupId else { return }
            deepLinkService.pendingGroupId = nil
            Task {
                if let group = await firestoreService.fetchGroupById(groupId) {
                    deepLinkPreviewGroup = group
                }
            }
        }
        .onChange(of: deepLinkService.pendingInviteCode) { _, code in
            guard let code else { return }
            deepLinkService.pendingInviteCode = nil
            Task {
                if let group = await firestoreService.findGroupByInviteCode(code) {
                    deepLinkPreviewGroup = group
                }
            }
        }
        .sheet(item: $deepLinkPreviewGroup) { group in
            GroupPreviewSheet(
                group: group,
                onJoin: {
                    if let groupId = group.id {
                        _ = await firestoreService.joinGroup(groupId: groupId)
                        await firestoreService.fetchJoinedGroups()
                    }
                },
                onOpen: {
                    notificationGroup = group
                }
            )
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await presenceService.checkExpiredTimersOnForeground()
                }
                presenceService.startHeartbeat()
            case .background:
                presenceService.stopHeartbeat()
            default:
                break
            }
        }
    }

    private var showNameNudge: Bool {
        guard !dismissedNameBanner,
              let user = firestoreService.currentUser else { return false }
        return user.hasDefaultName
    }

    private func initializeData() async {
        await firestoreService.fetchCurrentUser()
        await firestoreService.fetchJoinedGroups()

        if let location = locationService.currentLocation {
            await firestoreService.fetchNearbyGroups(center: location.coordinate)
        } else {
            await firestoreService.fetchPublicGroups()
        }

        presenceService.startMonitoring(groups: firestoreService.joinedGroups)

        // Load achievements and level data
        await achievementService.loadUserData()

        // Check and award daily login XP
        await levelService.checkAndAwardDailyLoginXP()
    }

    private func refreshData() async {
        AppLogger.debug("refreshData() called")
        await firestoreService.fetchJoinedGroups()

        if let location = locationService.currentLocation {
            await firestoreService.fetchNearbyGroups(center: location.coordinate)
        } else {
            await firestoreService.fetchPublicGroups()
        }

        presenceService.startMonitoring(groups: firestoreService.joinedGroups)
        AppLogger.debug("refreshData() finished - joinedGroups: \(firestoreService.joinedGroups.count)")
    }
}

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var onCreateTapped: () -> Void
    var onProfileTapped: () -> Void
    @State private var createButtonPressed = false

    var body: some View {
        HStack(spacing: 0) {
            // Map Tab
            TabBarButton(
                icon: "map.fill",
                label: "Map",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }

            // Create Button — bold CTA color
            Button(action: {
                HapticManager.medium()
                onCreateTapped()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.appCoral)
                        .frame(width: 56, height: 56)
                        .shadow(color: .appCoral.opacity(0.4), radius: 10, y: 4)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(createButtonPressed ? 90 : 0))
                }
                .scaleEffect(createButtonPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: createButtonPressed)
            }
            .accessibilityLabel("Create Group")
            .accessibilityHint("Create a new location group")
            .offset(y: -20)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                createButtonPressed = pressing
            }, perform: {})

            // List Tab
            TabBarButton(
                icon: "list.bullet",
                label: "List",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .shadow(color: .appShadow, radius: 10, y: -5)
        )
    }
}

struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .appBlue : .gray)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .accessibilityLabel("\(label) tab")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

#Preview {
    HomeView()
}
