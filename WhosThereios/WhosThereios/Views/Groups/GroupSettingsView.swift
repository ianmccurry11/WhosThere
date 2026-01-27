//
//  GroupSettingsView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import MapKit

struct GroupSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var firestoreService = FirestoreService.shared

    let group: LocationGroup

    @State private var groupName: String
    @State private var selectedEmoji: String
    @State private var presenceMode: PresenceDisplayMode
    @State private var isSaving = false
    @State private var showEmojiPicker = false
    @State private var showBoundaryEditor = false

    // Boundary editing state
    @State private var boundaryPoints: [CLLocationCoordinate2D] = []
    @State private var hasModifiedBoundary = false

    init(group: LocationGroup) {
        self.group = group
        _groupName = State(initialValue: group.name)
        _selectedEmoji = State(initialValue: group.emoji ?? "📍")
        _presenceMode = State(initialValue: group.presenceDisplayMode)
        _boundaryPoints = State(initialValue: group.boundaryCoordinates)
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

                    // Name editor with softer styling
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Group Name", text: $groupName)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .frame(maxWidth: 200)
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Type", value: group.isPublic ? "Public" : "Private")
                    LabeledContent("Members", value: "\(group.memberIds.count)")
                }

                // Boundary Section
                Section("Location Boundary") {
                    // Preview map showing current boundary
                    if boundaryPoints.count >= 3 {
                        Map(initialPosition: mapPosition) {
                            MapPolygon(coordinates: boundaryPoints)
                                .stroke(group.displayColor, lineWidth: 2)
                                .foregroundStyle(group.displayColor.opacity(0.2))
                        }
                        .frame(height: 150)
                        .cornerRadius(8)
                        .allowsHitTesting(false)
                    }

                    Button {
                        showBoundaryEditor = true
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Edit Boundary")
                            Spacer()
                            if hasModifiedBoundary {
                                Text("Modified")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
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
            .sheet(isPresented: $showBoundaryEditor) {
                BoundaryEditorView(
                    boundaryPoints: $boundaryPoints,
                    groupColor: group.displayColor,
                    onSave: {
                        hasModifiedBoundary = true
                    }
                )
            }
        }
    }

    private var mapPosition: MapCameraPosition {
        guard !boundaryPoints.isEmpty else {
            return .automatic
        }

        let latitudes = boundaryPoints.map { $0.latitude }
        let longitudes = boundaryPoints.map { $0.longitude }
        let centerLat = (latitudes.min()! + latitudes.max()!) / 2
        let centerLon = (longitudes.min()! + longitudes.max()!) / 2
        let latSpan = (latitudes.max()! - latitudes.min()!) * 1.5
        let lonSpan = (longitudes.max()! - longitudes.min()!) * 1.5

        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: max(latSpan, 0.005), longitudeDelta: max(lonSpan, 0.005))
        ))
    }

    private func saveSettings() async {
        guard let groupId = group.id else { return }

        isSaving = true

        // Update basic settings
        await firestoreService.updateGroupSettings(
            groupId: groupId,
            name: groupName.trimmingCharacters(in: .whitespaces),
            emoji: selectedEmoji,
            presenceMode: presenceMode
        )

        // Update boundary if modified
        if hasModifiedBoundary {
            let coordinates = boundaryPoints.map { Coordinate(from: $0) }
            await firestoreService.updateGroupBoundary(groupId: groupId, boundary: coordinates)
        }

        await firestoreService.fetchJoinedGroups()
        isSaving = false

        dismiss()
    }
}

// MARK: - Boundary Editor View

struct BoundaryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var boundaryPoints: [CLLocationCoordinate2D]
    let groupColor: Color
    let onSave: () -> Void

    @State private var editingPoints: [CLLocationCoordinate2D] = []
    @State private var selectedMarkerIndex: Int? = nil
    @State private var position: MapCameraPosition = .automatic
    @State private var isDraggingMarker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instructions
                VStack(spacing: 4) {
                    Text(selectedMarkerIndex != nil ? "Tap map to move selected marker, or tap marker to deselect" : "Tap to add points. Tap a marker to select and move it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Long-press a marker to delete it")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))

                // Map with boundary editing
                ZStack {
                    MapReader { proxy in
                        Map(position: $position, interactionModes: isDraggingMarker ? [] : [.pan, .zoom, .rotate]) {
                            UserAnnotation()

                            // Draw boundary polygon
                            if editingPoints.count >= 3 {
                                MapPolygon(coordinates: editingPoints)
                                    .stroke(groupColor, lineWidth: 2)
                                    .foregroundStyle(groupColor.opacity(0.2))
                            }

                            // Draw points with selection state
                            ForEach(Array(editingPoints.enumerated()), id: \.offset) { index, coord in
                                Annotation("", coordinate: coord) {
                                    BoundaryMarkerView(
                                        index: index,
                                        isSelected: selectedMarkerIndex == index,
                                        onTap: {
                                            if selectedMarkerIndex == index {
                                                selectedMarkerIndex = nil
                                            } else {
                                                selectedMarkerIndex = index
                                            }
                                        },
                                        onDelete: {
                                            editingPoints.remove(at: index)
                                            selectedMarkerIndex = nil
                                        }
                                    )
                                }
                            }

                            // Draw lines connecting points
                            if editingPoints.count >= 2 {
                                MapPolyline(coordinates: editingPoints + [editingPoints[0]])
                                    .stroke(groupColor, lineWidth: 2)
                            }
                        }
                        .mapStyle(.standard)
                        .onTapGesture { screenCoord in
                            if let coordinate = proxy.convert(screenCoord, from: .local) {
                                if let selectedIndex = selectedMarkerIndex {
                                    editingPoints[selectedIndex] = coordinate
                                    selectedMarkerIndex = nil
                                } else {
                                    editingPoints.append(coordinate)
                                }
                            }
                        }
                    }

                    // Status overlay
                    VStack {
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(editingPoints.count) points")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)

                                if selectedMarkerIndex != nil {
                                    Text("Marker selected")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .cornerRadius(6)
                                }

                                if editingPoints.count >= 3 {
                                    let validation = boundaryValidationMessage
                                    Text(validation.message)
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(validation.isValid ? Color.green : Color.orange)
                                        .cornerRadius(6)
                                }
                            }
                            .padding()
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Edit Boundary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear") {
                        editingPoints = []
                        selectedMarkerIndex = nil
                    }
                    .foregroundColor(.red)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        boundaryPoints = editingPoints
                        onSave()
                        dismiss()
                    }
                    .disabled(!boundaryValidationMessage.isValid)
                }
            }
            .onAppear {
                editingPoints = boundaryPoints
                if !boundaryPoints.isEmpty {
                    let latitudes = boundaryPoints.map { $0.latitude }
                    let longitudes = boundaryPoints.map { $0.longitude }
                    let centerLat = (latitudes.min()! + latitudes.max()!) / 2
                    let centerLon = (longitudes.min()! + longitudes.max()!) / 2
                    let latSpan = (latitudes.max()! - latitudes.min()!) * 1.5
                    let lonSpan = (longitudes.max()! - longitudes.min()!) * 1.5

                    position = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                        span: MKCoordinateSpan(latitudeDelta: max(latSpan, 0.01), longitudeDelta: max(lonSpan, 0.01))
                    ))
                }
            }
        }
    }

    private var boundaryValidationMessage: (isValid: Bool, message: String) {
        guard editingPoints.count >= 3 else {
            return (false, "Need at least 3 points")
        }

        let coordinates = editingPoints.map { Coordinate(from: $0) }
        let result = Validation.validateBoundary(coordinates)

        if result.isValid {
            let area = Validation.calculatePolygonArea(coordinates)
            let areaFormatted: String
            if area < 1000 {
                areaFormatted = String(format: "%.0f m²", area)
            } else if area < 1_000_000 {
                areaFormatted = String(format: "%.1f km²", area / 1_000_000)
            } else {
                areaFormatted = String(format: "%.2f km²", area / 1_000_000)
            }
            return (true, "Area: \(areaFormatted) ✓")
        } else {
            return (false, result.error?.userMessage ?? "Invalid boundary")
        }
    }
}

// MARK: - Boundary Marker View

struct BoundaryMarkerView: View {
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteButton = false

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.orange : Color.blue)
                .frame(width: isSelected ? 20 : 14, height: isSelected ? 20 : 14)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                )
                .shadow(color: isSelected ? .orange.opacity(0.5) : .clear, radius: 4)

            if isSelected {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }

            if showDeleteButton {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.red)
                        .background(Color.white.clipShape(Circle()))
                }
                .offset(x: 18, y: -18)
            }
        }
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            withAnimation {
                showDeleteButton.toggle()
            }
        }
        .onChange(of: isSelected) { _, newValue in
            if !newValue {
                showDeleteButton = false
            }
        }
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
