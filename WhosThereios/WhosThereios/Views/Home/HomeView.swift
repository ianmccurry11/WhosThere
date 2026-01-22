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
    @StateObject private var authService = AuthService()

    @State private var selectedTab = 0
    @State private var showCreateGroup = false
    @State private var showProfile = false
    @State private var showFriendsList = false
    @State private var showConfetti = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Offline banner
                    if !networkMonitor.isConnected {
                        StatusBanner(message: "No internet connection", type: .offline)
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
                }
                ToolbarItem(placement: .principal) {
                    Text("Who's There")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showProfile = true }) {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    }
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
        .sheet(isPresented: $showFriendsList) {
            FriendsListView()
        }
        .task {
            await initializeData()
        }
        .onAppear {
            locationService.requestAuthorization()
        }
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

        // Load achievements
        await achievementService.loadUserData()
    }

    private func refreshData() async {
        print("refreshData() called")
        await firestoreService.fetchJoinedGroups()

        if let location = locationService.currentLocation {
            await firestoreService.fetchNearbyGroups(center: location.coordinate)
        } else {
            await firestoreService.fetchPublicGroups()
        }

        presenceService.startMonitoring(groups: firestoreService.joinedGroups)
        print("refreshData() finished - joinedGroups: \(firestoreService.joinedGroups.count)")
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

            // Create Button
            Button(action: {
                HapticManager.medium()
                onCreateTapped()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.appBrown)
                        .frame(width: 56, height: 56)
                        .shadow(color: .appBrown.opacity(0.3), radius: 8, y: 4)

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.appCream)
                        .rotationEffect(.degrees(createButtonPressed ? 90 : 0))
                }
                .scaleEffect(createButtonPressed ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: createButtonPressed)
            }
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
                .shadow(color: .black.opacity(0.1), radius: 10, y: -5)
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
            .foregroundColor(isSelected ? .appBrown : .gray)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

#Preview {
    HomeView()
}
