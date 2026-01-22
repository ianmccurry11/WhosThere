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
    @ObservedObject var authService: AuthService

    @State private var displayName = ""
    @State private var isEditingName = false
    @State private var showSignOutConfirmation = false
    @State private var showClearPresenceConfirmation = false
    @State private var selectedAutoCheckOutMinutes: Int = 60

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

                        VStack(alignment: .leading, spacing: 4) {
                            if isEditingName {
                                TextField("Display Name", text: $displayName)
                                    .textFieldStyle(.roundedBorder)
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
                                displayName = firestoreService.currentUser?.displayName ?? ""
                                isEditingName = true
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
                }

                // Location & Timer Settings
                Section {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(presenceService.hasAlwaysLocationPermission ? .green : .orange)
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
                }

                // App Info
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
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
        .onAppear {
            // Load saved auto check-out time
            selectedAutoCheckOutMinutes = firestoreService.currentUser?.autoCheckOutMinutes ?? 60
        }
    }

    private var initials: String {
        guard let name = firestoreService.currentUser?.displayName else { return "?" }
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
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
