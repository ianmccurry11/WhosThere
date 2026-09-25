//
//  ProfileView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var firestoreService = FirestoreService.shared
    @ObservedObject private var presenceService = PresenceService.shared
    @ObservedObject private var achievementService = AchievementService.shared
    @ObservedObject private var levelService = LevelService.shared
    @ObservedObject var authService: AuthService
    var startEditingName: Bool = false

    @State private var displayName = ""
    @State private var isEditingName = false
    @FocusState private var isNameFieldFocused: Bool
    @State private var showSignOutConfirmation = false
    @State private var showClearPresenceConfirmation = false
    @State private var selectedAutoCheckOutMinutes: Int = 60
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    #if DEBUG
    @State private var showAnalyticsDashboard = false
    @State private var versionTapCount = 0
    #endif

    var body: some View {
        NavigationStack {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 60, height: 60)

                            Text(initials)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.blue)
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 4) {
                            if isEditingName {
                                TextField("Display Name", text: $displayName)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($isNameFieldFocused)
                                    .onSubmit {
                                        Task {
                                            await saveName()
                                        }
                                    }
                            } else {
                                Text(firestoreService.currentUser?.displayName ?? "User")
                                    .font(.headline)

                                // Show username tag
                                if let user = firestoreService.currentUser {
                                    Text("#\(user.discriminator)")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }

                            if let email = Auth.auth().currentUser?.email, !email.isEmpty {
                                Text(email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Button(isEditingName ? "Save" : "Edit") {
                            if isEditingName {
                                Task {
                                    await saveName()
                                }
                            } else {
                                beginEditingName()
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 8)
                }

                // Achievements Section
                Section {
                    NavigationLink(destination: AchievementsView()) {
                        HStack(spacing: 16) {
                            // Badge icon
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "trophy.fill")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Achievements")
                                    .font(.headline)

                                HStack(spacing: 8) {
                                    Text("\(achievementService.totalPoints) pts")
                                        .font(.caption)
                                        .foregroundColor(.purple)

                                    Text("\(achievementService.earnedAchievements.count)/\(AchievementType.allCases.count) badges")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // Recent badges preview
                            HStack(spacing: -8) {
                                ForEach(achievementService.earnedAchievements.prefix(3)) { achievement in
                                    Text(achievement.achievementType.emoji)
                                        .font(.title3)
                                        .background(
                                            Circle()
                                                .fill(Color(.systemBackground))
                                                .frame(width: 28, height: 28)
                                        )
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Level & XP Section
                Section {
                    VStack(spacing: 8) {
                        HStack {
                            LevelBadge(level: levelService.currentLevel.level)
                            Text(levelService.currentLevel.tierName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(levelService.totalXP) XP")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }

                        // Progress bar to next level
                        if !levelService.currentLevel.isMaxLevel {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(
                                            width: geo.size.width * CGFloat(levelService.currentLevel.progressToNextLevel),
                                            height: 6
                                        )
                                }
                            }
                            .frame(height: 6)

                            HStack {
                                Text("\(levelService.currentLevel.xpToNextLevel) XP to Level \(levelService.currentLevel.level + 1)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        } else {
                            HStack {
                                Text("Max level reached!")
                                    .font(.caption2)
                                    .foregroundColor(.purple)
                                Spacer()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Current Status Section
                Section("Current Status") {
                    let joinedGroups = firestoreService.joinedGroups

                    if joinedGroups.isEmpty {
                        Text("You haven't joined any groups yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(joinedGroups) { group in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(group.name)
                                        .font(.subheadline)

                                    if let groupId = group.id,
                                       let userId = Auth.auth().currentUser?.uid,
                                       presenceService.isUserPresent(groupId: groupId, userId: userId) {
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color.green)
                                                .frame(width: 8, height: 8)
                                                .accessibilityHidden(true)
                                            Text("You're here")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    } else {
                                        Text("Not present")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Text(presenceService.formatPresenceDisplay(for: group))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                // Quick Actions
                Section("Quick Actions") {
                    Button(action: { showClearPresenceConfirmation = true }) {
                        HStack {
                            Image(systemName: "location.slash")
                            Text("Check out from all locations")
                        }
                    }
                    .disabled(firestoreService.joinedGroups.isEmpty)
                    .accessibilityHint("Marks you as not present at all your groups")
                }

                // Location & Timer Settings
                Section {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(presenceService.hasAlwaysLocationPermission ? .green : .orange)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Location Permission")
                                .font(.subheadline)
                            Text(presenceService.hasAlwaysLocationPermission ? "Always" : "When In Use")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if !presenceService.hasAlwaysLocationPermission {
                            Button("Change") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    }

                    if !presenceService.hasAlwaysLocationPermission {
                        Picker("Auto check-out timer", selection: $selectedAutoCheckOutMinutes) {
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("1 hour").tag(60)
                            Text("2 hours").tag(120)
                            Text("4 hours").tag(240)
                        }
                        .onChange(of: selectedAutoCheckOutMinutes) { _, newValue in
                            Task {
                                await firestoreService.updateAutoCheckOutMinutes(newValue)
                            }
                        }

                        Text("When you check in manually, you'll be automatically checked out after this time since the app can't track your location in the background.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Location Settings")
                } footer: {
                    if presenceService.hasAlwaysLocationPermission {
                        Text("With 'Always' permission, your presence updates automatically when you enter or leave a group's area.")
                    }
                }

                // Account Section
                Section("Account") {
                    Button(action: { showSignOutConfirmation = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .foregroundColor(.red)
                    }

                    Button(action: { showDeleteAccountConfirmation = true }) {
                        HStack {
                            if isDeletingAccount {
                                ProgressView()
                                    .tint(.red)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text("Delete Account")
                        }
                        .foregroundColor(.red)
                    }
                    .disabled(isDeletingAccount)
                }

                // Share & Support
                Section {
                    ShareLink(item: URL(string: "https://apps.apple.com/app/id6758129477")!) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                            Text("Share Who's There")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        Task { await AchievementService.shared.recordAppShared() }
                    })

                    Button {
                        requestAppReview()
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("Rate Who's There")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Enjoying the app?")
                }

                // Legal
                Section {
                    Link(destination: URL(string: "https://ianmccurry11.github.io/whosthere-privacy/")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // App Info
                Section {
                    #if DEBUG
                    versionRow
                    #else
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    #endif
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Sign Out?", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                authService.signOut()
                dismiss()
            }
        } message: {
            Text("You will need to sign in again to use Who's There.")
        }
        .alert("Check Out Everywhere?", isPresented: $showClearPresenceConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Check Out", role: .destructive) {
                Task {
                    await firestoreService.clearAllPresence()
                }
            }
        } message: {
            Text("This will mark you as not present at all locations.")
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    let success = await authService.deleteAccount()
                    isDeletingAccount = false
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This will permanently delete your account, all your groups, messages, achievements, and friends. This action cannot be undone.")
        }
        .onAppear {
            // Load saved auto check-out time
            selectedAutoCheckOutMinutes = firestoreService.currentUser?.autoCheckOutMinutes ?? 60

            // Track screen view
            AnalyticsService.shared.trackScreenView("profile")

            // Auto-start name editing if opened from the nudge banner
            if startEditingName && !isEditingName {
                beginEditingName()
            }
        }
        #if DEBUG
        .sheet(isPresented: $showAnalyticsDashboard) {
            AnalyticsDashboardView()
        }
        #endif
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    #if DEBUG
    private var versionRow: some View {
        HStack {
            Text("Version")
            Spacer()
            Text(appVersion)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            versionTapCount += 1
            if versionTapCount >= 5 {
                versionTapCount = 0
                showAnalyticsDashboard = true
                HapticManager.medium()
            }
        }
    }
    #endif

    private var initials: String {
        guard let name = firestoreService.currentUser?.displayName else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func beginEditingName() {
        displayName = firestoreService.currentUser?.displayName ?? ""
        isEditingName = true
        // Delay focus slightly so the TextField has time to appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNameFieldFocused = true
        }
    }

    private func requestAppReview() {
        guard let url = URL(string: "https://apps.apple.com/app/id6758129477?action=write-review") else { return }
        UIApplication.shared.open(url)
    }

    private func saveName() async {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            isEditingName = false
            return
        }

        _ = await firestoreService.updateDisplayName(trimmed)
        isEditingName = false
    }
}

#Preview {
    ProfileView(authService: AuthService())
}
