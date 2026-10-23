//
//  CreateGroupView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import MapKit
import FirebaseAuth

struct CreateGroupView: View {
    @Environment(\.dismiss) private var dismiss
    private var firestoreService: FirestoreService { FirestoreService.shared }
    @ObservedObject private var networkMonitor = NetworkMonitor.shared

    @State private var groupName = ""
    @State private var isPublic = true
    @State private var presenceMode: PresenceDisplayMode = .names
    @State private var selectedColor: GroupColor = .blue
    @State private var boundaryPoints: [CLLocationCoordinate2D] = []
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var isDrawing = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var shouldDismiss = false
    @State private var selectedMarkerIndex: Int? = nil
    @State private var isDraggingMarker = false
    @State private var isSettingsExpanded = true
    @State private var colorShakeAnimation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Collapsible settings panel
                VStack(spacing: 0) {
                    // Header — always visible, acts as toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSettingsExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Group Settings")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            // Summary chips when collapsed
                            if !isSettingsExpanded {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        if !groupName.isEmpty {
                                            settingsChip(groupName)
                                        }
                                        settingsChip(isPublic ? "Public" : "Private")
                                        Circle()
                                            .fill(selectedColor.color)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(isSettingsExpanded ? 0 : -90))
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }

                    // Expandable form fields
                    if isSettingsExpanded {
                        VStack(spacing: 12) {
                            // Group Name
                            TextField("Group name (e.g., Central Park Courts)", text: $groupName)
                                .textFieldStyle(.roundedBorder)

                            // Public/Private + Presence Mode — two side-by-side pills
                            HStack(spacing: 10) {
                                // Public/Private toggle pill
                                HStack(spacing: 6) {
                                    Toggle("", isOn: $isPublic)
                                        .labelsHidden()
                                        .scaleEffect(0.85)
                                    Text(isPublic ? "Public" : "Private")
                                        .font(.subheadline)
                                        .fixedSize()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color(.secondarySystemFill))
                                .cornerRadius(8)

                                // Presence mode picker — takes remaining width
                                Picker("Presence", selection: $presenceMode) {
                                    Text("Count only").tag(PresenceDisplayMode.count)
                                    Text("Names").tag(PresenceDisplayMode.names)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: .infinity)
                            }

                            // Color row — scrollable so it never clips
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(GroupColor.allCases, id: \.self) { color in
                                        Button {
                                            HapticManager.light()
                                            selectedColor = color
                                        } label: {
                                            Circle()
                                                .fill(color.color)
                                                .frame(width: 28, height: 28)
                                                .overlay(
                                                    Circle()
                                                        .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                                )
                                                .scaleEffect(selectedColor == color ? 1.12 : 1.0)
                                                .animation(.spring(response: 0.3), value: selectedColor)
                                        }
                                        .accessibilityLabel("\(color.rawValue)\(selectedColor == color ? ", selected" : "")")
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Color(.systemBackground))

                Divider()

                // Map — takes all remaining space
                ZStack {
                    MapReader { proxy in
                        Map(position: $position, interactionModes: isDraggingMarker ? [] : [.pan, .zoom, .rotate]) {
                            UserAnnotation()

                            // Draw boundary polygon
                            if boundaryPoints.count >= 3 {
                                MapPolygon(coordinates: boundaryPoints)
                                    .stroke(selectedColor.color, lineWidth: 2)
                                    .foregroundStyle(selectedColor.color.opacity(0.2))
                            }

                            // Draw points with selection state
                            ForEach(Array(boundaryPoints.enumerated()), id: \.offset) { index, coord in
                                Annotation("", coordinate: coord) {
                                    DraggableMarkerView(
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
                                            boundaryPoints.remove(at: index)
                                            selectedMarkerIndex = nil
                                        }
                                    )
                                }
                            }

                            // Draw lines connecting points
                            if boundaryPoints.count >= 2 {
                                MapPolyline(coordinates: boundaryPoints + [boundaryPoints[0]])
                                    .stroke(selectedColor.color, lineWidth: 2)
                            }
                        }
                        .mapStyle(.standard)
                        .onTapGesture { screenCoord in
                            // Auto-collapse settings on first marker placement
                            if isSettingsExpanded && boundaryPoints.isEmpty {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isSettingsExpanded = false
                                }
                            }

                            if let coordinate = proxy.convert(screenCoord, from: .local) {
                                if let selectedIndex = selectedMarkerIndex {
                                    boundaryPoints[selectedIndex] = coordinate
                                    selectedMarkerIndex = nil
                                } else {
                                    boundaryPoints.append(coordinate)
                                }
                            }
                        }
                    }

                    // Overlays
                    VStack {
                        // Instruction bar at top of map
                        HStack {
                            Text(mapInstructionText)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.black.opacity(0.6))
                                .cornerRadius(8)

                            Spacer()

                            if !boundaryPoints.isEmpty {
                                Button {
                                    boundaryPoints = []
                                    selectedMarkerIndex = nil
                                } label: {
                                    Text("Clear")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.red.opacity(0.8))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(12)

                        Spacer()

                        // Status badges at bottom-right
                        HStack {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("\(boundaryPoints.count) points")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
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

                                if boundaryPoints.count >= 3 {
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
                            .padding(12)
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                // Offline warning
                if !networkMonitor.isConnected {
                    StatusBanner(message: "You're offline. Creating a group requires an internet connection.", type: .offline)
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task {
                                await createGroup()
                            }
                        }
                        .disabled(!canCreate)
                    }
                }
            }
            .disabled(isSaving)
            .onChange(of: shouldDismiss) { _, newValue in
                if newValue {
                    dismiss()
                }
            }
            .onShake {
                shakeToRandomizeColor()
            }
        }
    }

    /// Easter egg: shake the device to cycle to a random boundary color
    private func shakeToRandomizeColor() {
        let available = GroupColor.allCases
        var newColor = available.randomElement() ?? .blue
        // Avoid picking the same color
        while newColor == selectedColor && available.count > 1 {
            newColor = available.randomElement() ?? .blue
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            selectedColor = newColor
            colorShakeAnimation = true
        }
        HapticManager.medium()

        // Reset animation flag
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            colorShakeAnimation = false
        }
    }

    private var mapInstructionText: String {
        if selectedMarkerIndex != nil {
            return "Tap map to move marker"
        } else if boundaryPoints.isEmpty {
            return "Tap to place boundary points"
        } else if boundaryPoints.count < 3 {
            return "Add \(3 - boundaryPoints.count) more point\(boundaryPoints.count == 2 ? "" : "s")"
        } else {
            return "Tap to add more, or tap a marker to adjust"
        }
    }

    private func settingsChip(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(.systemGray5))
            .cornerRadius(6)
            .lineLimit(1)
    }

    private var canCreate: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty && boundaryPoints.count >= 3 && boundaryValidationMessage.isValid && networkMonitor.isConnected
    }

    /// Real-time validation of boundary area
    private var boundaryValidationMessage: (isValid: Bool, message: String) {
        guard boundaryPoints.count >= 3 else {
            return (false, "Need at least 3 points")
        }

        let coordinates = boundaryPoints.map { Coordinate(from: $0) }
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

    private func createGroup() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            errorMessage = "You must be signed in to create a group"
            return
        }

        isSaving = true
        errorMessage = nil

        let coordinates = boundaryPoints.map { Coordinate(from: $0) }

        var group = LocationGroup(
            name: groupName.trimmingCharacters(in: .whitespaces),
            isPublic: isPublic,
            ownerId: userId,
            memberIds: [userId],
            boundary: coordinates,
            presenceDisplayMode: presenceMode,
            groupColor: selectedColor
        )

        // Generate invite code for private groups
        if !isPublic {
            group.inviteCode = firestoreService.generateInviteCode()
        }

        let result = await firestoreService.createGroup(group)

        switch result {
        case .success(let groupId):
            AppLogger.debug("Group created successfully with ID: \(groupId)")
            await firestoreService.fetchJoinedGroups()
            isSaving = false
            shouldDismiss = true
        case .failure(let error):
            AppLogger.debug("Group creation failed: \(error.errorDescription ?? "Unknown")")
            errorMessage = error.userMessage
            isSaving = false
        }
    }
}

// MARK: - Draggable Marker View

struct DraggableMarkerView: View {
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteButton = false

    var body: some View {
        ZStack {
            // Main marker
            Circle()
                .fill(isSelected ? Color.orange : Color.blue)
                .frame(width: isSelected ? 20 : 14, height: isSelected ? 20 : 14)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                )
                .shadow(color: isSelected ? .orange.opacity(0.5) : .clear, radius: 4)

            // Index number for selected marker
            if isSelected {
                Text("\(index + 1)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }

            // Delete button (appears on long press)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boundary point \(index + 1)\(isSelected ? ", selected" : "")")
        .accessibilityHint(isSelected ? "Tap to deselect. Long press to delete." : "Tap to select. Long press to delete.")
    }
}

#Preview {
    CreateGroupView()
}
