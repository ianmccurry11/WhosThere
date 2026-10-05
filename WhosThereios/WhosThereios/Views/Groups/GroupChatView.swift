//
//  GroupChatView.swift
//  WhosThereios
//
//  Created by Claude on 1/16/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct GroupChatView: View {
    let group: LocationGroup

    @StateObject private var chatService: ChatService
    @State private var messageText = ""
    @State private var showError = false
    @State private var reportingMessage: Message?
    @FocusState private var isInputFocused: Bool

    private let currentUserId = Auth.auth().currentUser?.uid

    init(group: LocationGroup) {
        self.group = group
        self._chatService = StateObject(wrappedValue: ChatService(groupId: group.id ?? ""))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if chatService.isLoading {
                            ProgressView()
                                .padding()
                        } else if chatService.messages.isEmpty {
                            ChatEmptyStateView()
                        } else {
                            ForEach(chatService.messages) { message in
                                MessageBubble(
                                    message: message,
                                    isOwnMessage: message.senderId == currentUserId,
                                    onReport: { reportingMessage = message }
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .onChange(of: chatService.messages.count) { _, _ in
                    // Scroll to bottom when new messages arrive
                    if let lastMessage = chatService.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Message input
            MessageInputBar(
                text: $messageText,
                isFocused: $isInputFocused,
                onSend: sendMessage
            )
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            chatService.startListening()
        }
        .onDisappear {
            chatService.stopListening()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(chatService.error ?? "An error occurred")
        }
        .onChange(of: chatService.error) { _, newValue in
            showError = newValue != nil
        }
        .sheet(item: $reportingMessage) { message in
            ReportUserView(
                reportedUserId: message.senderId,
                reportedDisplayName: message.senderName,
                context: .chat,
                groupId: group.id,
                messageId: message.id,
                messageText: message.text
            )
        }
    }

    private func sendMessage() {
        let text = messageText
        messageText = ""

        Task {
            let success = await chatService.sendMessage(text)
            if !success {
                // Restore message if send failed
                messageText = text
            }
        }
    }
}

// MARK: - Chat Empty State

private struct ChatEmptyStateView: View {
    var body: some View {
        EmptyStateView(
            icon: "bubble.left.and.bubble.right",
            title: "No Messages Yet",
            message: "Be the first to say something!"
        )
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: Message
    let isOwnMessage: Bool
    var onReport: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isOwnMessage {
                Spacer(minLength: 60)
            }

            VStack(alignment: isOwnMessage ? .trailing : .leading, spacing: 4) {
                if !isOwnMessage {
                    Text(message.senderName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                Text(message.text)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isOwnMessage ? Color.appBlue : Color(.secondarySystemBackground))
                    )
                    .foregroundColor(isOwnMessage ? .white : .primary)

                Text(formatTime(message.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(isOwnMessage ? "You" : message.senderName): \(message.text), \(formatTime(message.createdAt))")
            .contextMenu {
                if !isOwnMessage {
                    Button(role: .destructive) {
                        onReport?()
                    } label: {
                        Label("Report Message", systemImage: "flag")
                    }
                }
            }

            if !isOwnMessage {
                Spacer(minLength: 60)
            }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }

        return formatter.string(from: date)
    }
}

// MARK: - Message Input Bar

private struct MessageInputBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused(isFocused)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                )

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .appBlue)
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - Chat Preview Row (for GroupDetailView)

struct ChatPreviewRow: View {
    let group: LocationGroup
    @State private var lastMessage: Message?
    @State private var unreadCount: Int = 0

    var body: some View {
        NavigationLink(destination: GroupChatView(group: group)) {
            HStack(spacing: 12) {
                // Chat icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Group Chat")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let message = lastMessage {
                        Text("\(message.senderName): \(message.text)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No messages yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.blue))
                        .accessibilityLabel("\(unreadCount) unread")
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .task {
            await loadLastMessage()
        }
    }

    private func loadLastMessage() async {
        guard let groupId = group.id else { return }

        let db = Firestore.firestore()

        do {
            let snapshot = try await db.collection("groups")
                .document(groupId)
                .collection("messages")
                .order(by: "createdAt", descending: true)
                .limit(to: 1)
                .getDocuments()

            if let doc = snapshot.documents.first {
                lastMessage = try? doc.data(as: Message.self)
            }
        } catch {
            AppLogger.debug("Error loading last message: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        GroupChatView(group: LocationGroup(
            name: "Test Group",
            emoji: "🏀",
            isPublic: true,
            ownerId: "test",
            memberIds: ["test"],
            boundary: [],
            presenceDisplayMode: .names
        ))
    }
}
