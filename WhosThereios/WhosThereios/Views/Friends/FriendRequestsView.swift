//
//  FriendRequestsView.swift
//  WhosThereios
//
//  Created by Claude on 1/20/26.
//

import SwiftUI

struct FriendRequestsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var friendService = FriendService.shared

    @State private var selectedTab = 0
    @State private var processingRequestIds: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                Picker("Requests", selection: $selectedTab) {
                    Text("Received (\(friendService.pendingRequests.count))")
                        .tag(0)
                    Text("Sent (\(friendService.sentRequests.count))")
                        .tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    receivedRequestsList
                } else {
                    sentRequestsList
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Received Requests

    private var receivedRequestsList: some View {
        Group {
            if friendService.pendingRequests.isEmpty {
                ContentUnavailableView(
                    "No Pending Requests",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Friend requests you receive will appear here")
                )
            } else {
                List(friendService.pendingRequests) { request in
                    ReceivedRequestRow(
                        request: request,
                        isProcessing: processingRequestIds.contains(request.id ?? ""),
                        onAccept: {
                            await handleAccept(request)
                        },
                        onDecline: {
                            await handleDecline(request)
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Sent Requests

    private var sentRequestsList: some View {
        Group {
            if friendService.sentRequests.isEmpty {
                ContentUnavailableView(
                    "No Sent Requests",
                    systemImage: "paperplane",
                    description: Text("Requests you send will appear here until accepted")
                )
            } else {
                List(friendService.sentRequests) { request in
                    SentRequestRow(
                        request: request,
                        isProcessing: processingRequestIds.contains(request.id ?? ""),
                        onCancel: {
                            await handleCancel(request)
                        }
                    )
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Actions

    private func handleAccept(_ request: FriendRequest) async {
        guard let requestId = request.id else { return }
        processingRequestIds.insert(requestId)

        do {
            try await friendService.acceptRequest(request)
            HapticManager.success()
        } catch {
            HapticManager.error()
        }

        processingRequestIds.remove(requestId)
    }

    private func handleDecline(_ request: FriendRequest) async {
        guard let requestId = request.id else { return }
        processingRequestIds.insert(requestId)

        do {
            try await friendService.declineRequest(request)
            HapticManager.medium()
        } catch {
            HapticManager.error()
        }

        processingRequestIds.remove(requestId)
    }

    private func handleCancel(_ request: FriendRequest) async {
        guard let requestId = request.id else { return }
        processingRequestIds.insert(requestId)

        do {
            try await friendService.cancelRequest(request)
            HapticManager.medium()
        } catch {
            HapticManager.error()
        }

        processingRequestIds.remove(requestId)
    }
}

// MARK: - Received Request Row

struct ReceivedRequestRow: View {
    let request: FriendRequest
    let isProcessing: Bool
    let onAccept: () async -> Void
    let onDecline: () async -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(request.senderName.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundColor(.primary)
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(request.senderName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(request.senderTag)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(request.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Actions
            if isProcessing {
                ProgressView()
            } else {
                HStack(spacing: 8) {
                    Button {
                        Task { await onDecline() }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(.red)

                    Button {
                        Task { await onAccept() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sent Request Row

struct SentRequestRow: View {
    let request: FriendRequest
    let isProcessing: Bool
    let onCancel: () async -> Void

    @StateObject private var firestoreService = FirestoreService.shared
    @State private var receiverName: String?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 44, height: 44)
                .overlay {
                    if let name = receiverName {
                        Text(name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Image(systemName: "person")
                            .foregroundColor(.secondary)
                    }
                }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(receiverName ?? "Loading...")
                    .font(.body)
                    .fontWeight(.medium)

                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.orange)

                Text(request.createdAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Cancel button
            if isProcessing {
                ProgressView()
            } else {
                Button {
                    Task { await onCancel() }
                } label: {
                    Text("Cancel")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(.vertical, 4)
        .task {
            if let user = await firestoreService.fetchUserById(request.receiverId) {
                receiverName = user.displayName
            }
        }
    }
}

#Preview {
    FriendRequestsView()
}
