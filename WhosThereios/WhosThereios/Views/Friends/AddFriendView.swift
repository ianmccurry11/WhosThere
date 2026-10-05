//
//  AddFriendView.swift
//  WhosThereios
//
//  Created by Claude on 1/20/26.
//

import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firestoreService = FirestoreService.shared
    @StateObject private var friendService = FriendService.shared

    @State private var searchText = ""
    @State private var searchResults: [User] = []
    @State private var suggestedUsers: [User] = []
    @State private var isSearching = false
    @State private var isLoadingSuggestions = true
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingRequestUserIds: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search by username (e.g., Jake#1234)", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { await search() }
                        }

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 12)

                // Messages
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 8)
                }

                if let success = successMessage {
                    Text(success)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 8)
                }

                // Content
                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if !searchText.isEmpty {
                    // Search results mode
                    if searchResults.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No Results",
                            systemImage: "person.slash",
                            description: Text("No users found matching \"\(searchText)\"")
                        )
                        Spacer()
                    } else {
                        List(searchResults) { user in
                            SearchResultRow(
                                user: user,
                                isPending: pendingRequestUserIds.contains(user.id ?? ""),
                                isFriend: friendService.friends.contains { $0.id == user.id },
                                onSendRequest: {
                                    await sendRequest(to: user)
                                }
                            )
                        }
                        .listStyle(.plain)
                    }
                } else {
                    // Suggestions mode
                    suggestionsSection
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Search") {
                        Task { await search() }
                    }
                    .disabled(searchText.isEmpty)
                }
            }
            .onChange(of: searchText) { _, newValue in
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if searchText == newValue && !newValue.isEmpty {
                        await search()
                    }
                }
            }
            .task {
                pendingRequestUserIds = Set(friendService.sentRequests.map { $0.receiverId })
                suggestedUsers = await friendService.fetchPeopleYouMayKnow()
                isLoadingSuggestions = false
            }
        }
    }

    // MARK: - Suggestions Section

    @ViewBuilder
    private var suggestionsSection: some View {
        if isLoadingSuggestions {
            Spacer()
            ProgressView("Finding people you may know...")
            Spacer()
        } else if suggestedUsers.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("No Suggestions Yet")
                    .font(.headline)
                Text("Join more groups to discover people you may know.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            Spacer()
        } else {
            List {
                Section {
                    ForEach(suggestedUsers) { user in
                        SuggestionRow(
                            user: user,
                            sharedGroups: friendService.sharedGroupCount(with: user.id ?? ""),
                            isNearby: friendService.isUserNearby(user.id ?? ""),
                            isPending: pendingRequestUserIds.contains(user.id ?? ""),
                            onSendRequest: {
                                await sendRequest(to: user)
                            }
                        )
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                        Text("People You May Know")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .textCase(nil)
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Search

    private func search() async {
        guard !searchText.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        successMessage = nil

        if searchText.contains("#") {
            if let user = await firestoreService.searchUserByExactTag(searchText) {
                searchResults = [user]
            } else {
                searchResults = []
            }
        } else {
            searchResults = await firestoreService.searchUsersByName(searchText)
        }

        isSearching = false
    }

    private func sendRequest(to user: User) async {
        guard let userId = user.id else { return }

        errorMessage = nil
        successMessage = nil

        do {
            try await friendService.sendFriendRequest(toUserId: userId)
            pendingRequestUserIds.insert(userId)
            successMessage = "Friend request sent to \(user.displayName)"
            HapticManager.success()
        } catch {
            errorMessage = error.localizedDescription
            HapticManager.error()
        }
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    let user: User
    let sharedGroups: Int
    let isNearby: Bool
    let isPending: Bool
    let onSendRequest: () async -> Void

    @State private var isSending = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.appBlue.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(user.profileEmoji ?? String(user.displayName.prefix(1).uppercased()))
                    .font(user.profileEmoji != nil ? .title3 : .headline)
            }

            // Name + info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    if isNearby {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("Here now")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption2)
                    Text("\(sharedGroups) shared group\(sharedGroups == 1 ? "" : "s")")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Action
            if isPending {
                Label("Pending", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Button {
                    Task {
                        isSending = true
                        await onSendRequest()
                        isSending = false
                    }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Add", systemImage: "person.badge.plus")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .disabled(isSending)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.displayName), \(sharedGroups) shared groups\(isNearby ? ", nearby" : "")")
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let user: User
    let isPending: Bool
    let isFriend: Bool
    let onSendRequest: () async -> Void

    @State private var isSending = false

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(user.profileEmoji ?? String(user.displayName.prefix(1).uppercased()))
                        .font(user.profileEmoji != nil ? .title3 : .headline)
                }

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                Text("#\(user.discriminator)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Action button
            if isFriend {
                Label("Friends", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if isPending {
                Label("Pending", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Button {
                    Task {
                        isSending = true
                        await onSendRequest()
                        isSending = false
                    }
                } label: {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label("Add", systemImage: "person.badge.plus")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .disabled(isSending)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AddFriendView()
}
