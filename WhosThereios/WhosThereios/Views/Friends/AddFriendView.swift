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
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var pendingRequestUserIds: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search instruction
                VStack(spacing: 8) {
                    Text("Add by Username")
                        .font(.headline)

                    Text("Search by username tag (e.g., Jake#1234)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Username#1234", text: $searchText)
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
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)

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

                // Results
                if isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if searchResults.isEmpty && !searchText.isEmpty {
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
                // Auto-search after a brief delay
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if searchText == newValue && !newValue.isEmpty {
                        await search()
                    }
                }
            }
            .onAppear {
                // Track which users have pending requests
                pendingRequestUserIds = Set(friendService.sentRequests.map { $0.receiverId })
            }
        }
    }

    private func search() async {
        guard !searchText.isEmpty else { return }

        isSearching = true
        errorMessage = nil
        successMessage = nil

        // Check if it's an exact tag search (contains #)
        if searchText.contains("#") {
            if let user = await firestoreService.searchUserByExactTag(searchText) {
                searchResults = [user]
            } else {
                searchResults = []
            }
        } else {
            // Prefix search
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
                    Text(user.displayName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.primary)
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
