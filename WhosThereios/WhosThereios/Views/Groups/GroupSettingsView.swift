//
//  GroupSettingsView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI

struct GroupSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var firestoreService = FirestoreService.shared

    let group: LocationGroup

    @State private var groupName: String
    @State private var selectedEmoji: String
    @State private var presenceMode: PresenceDisplayMode
    @State private var isSaving = false
    @State private var showEmojiPicker = false

    init(group: LocationGroup) {
        self.group = group
        _groupName = State(initialValue: group.name)
        _selectedEmoji = State(initialValue: group.emoji ?? "📍")
        _presenceMode = State(initialValue: group.presenceDisplayMode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Group Info") {
                    // Emoji picker
                    HStack {
                        Text("Icon")
                        Spacer()
                        Button {
                            showEmojiPicker = true
                        } label: {
                            Text(selectedEmoji)
                                .font(.largeTitle)
                                .padding(8)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }

                    // Name editor
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Group Name", text: $groupName)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 200)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Type", value: group.isPublic ? "Public" : "Private")
                    LabeledContent("Members", value: "\(group.memberIds.count)")
                }

                Section("Privacy Settings") {
                    Picker("Show presence as", selection: $presenceMode) {
                        Text("Count only").tag(PresenceDisplayMode.count)
                        Text("Names").tag(PresenceDisplayMode.names)
                    }

                    if presenceMode == .count {
                        Text("Members will only see how many people are present, not who specifically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Members will see the names of everyone who is present.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let inviteCode = group.inviteCode {
                    Section("Invite Code") {
                        HStack {
                            Text(inviteCode)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("Copy") {
                                UIPasteboard.general.string = inviteCode
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveSettings()
                        }
                    }
                    .disabled(isSaving || groupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $selectedEmoji)
            }
        }
    }

    private func saveSettings() async {
        guard let groupId = group.id else { return }

        isSaving = true
        await firestoreService.updateGroupSettings(
            groupId: groupId,
            name: groupName.trimmingCharacters(in: .whitespaces),
            emoji: selectedEmoji,
            presenceMode: presenceMode
        )
        await firestoreService.fetchJoinedGroups()
        isSaving = false

        dismiss()
    }
}

// MARK: - Emoji Picker View

struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String

    let commonEmojis = [
        // Sports & Activities
        "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏉", "🎱", "🏓", "🏸",
        "🏒", "🏑", "🥍", "🏏", "⛳", "🥊", "🎳", "🏋️", "🚴", "🏊",
        // Places
        "📍", "🏠", "🏢", "🏫", "🏥", "🏪", "🏬", "🏭", "🏰", "⛪",
        "🕌", "🕍", "⛩️", "🗼", "🏟️", "🎪", "🎡", "🎢", "🏖️", "🏕️",
        // Nature & Weather
        "🌳", "🌲", "🌴", "🌵", "🌾", "🌻", "🌺", "🌸", "🌼", "🌷",
        "☀️", "🌙", "⭐", "🌈", "☁️", "❄️", "🔥", "💧", "🌊", "⛰️",
        // Food & Drink
        "🍕", "🍔", "🍟", "🌭", "🍿", "🥤", "🍺", "🍷", "☕", "🧋",
        // Objects
        "🎮", "🎲", "🎯", "🎨", "🎭", "🎪", "📚", "💼", "🔧", "⚙️",
        // Symbols
        "❤️", "💙", "💚", "💛", "💜", "🖤", "🤍", "💯", "✨", "🔒"
    ]

    let columns = [
        GridItem(.adaptive(minimum: 44))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(commonEmojis, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                                .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    GroupSettingsView(group: LocationGroup(
        name: "Test Court",
        isPublic: false,
        ownerId: "123",
        boundary: [],
        inviteCode: "ABC123"
    ))
}
