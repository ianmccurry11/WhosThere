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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Form fields
                VStack(spacing: 16) {
                    // Group Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Group Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("e.g., Central Park Courts", text: $groupName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Public/Private Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Public Group")
                                .font(.subheadline)
                            Text(isPublic ? "Anyone can find and join" : "Invite only")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $isPublic)
                            .labelsHidden()
                    }

                    // Presence Display Mode
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Show presence as")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Picker("Presence Mode", selection: $presenceMode) {
                            Text("Count only").tag(PresenceDisplayMode.count)
                            Text("Names").tag(PresenceDisplayMode.names)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Group Color Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Boundary Color")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            ForEach(GroupColor.allCases, id: \.self) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3), value: selectedColor)
                                    .onTapGesture {
                                        HapticManager.light()
                                        selectedColor = color
                                    }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))

                Divider()

                // Map for drawing boundary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Draw Boundary")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        if !boundaryPoints.isEmpty {
                            Button("Clear") {
                                boundaryPoints = []
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)

                    Text(selectedMarkerIndex != nil ? "Tap map to move selected marker, or tap marker to deselect" : "Tap to add points. Tap a marker to select and move it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    // Map with tap gesture
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
                                                    // Deselect if already selected
                                                    selectedMarkerIndex = nil
                                                } else {
                                                    // Select this marker
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
                                if let coordinate = proxy.convert(screenCoord, from: .local) {
                                    if let selectedIndex = selectedMarkerIndex {
                                        // Move the selected marker to the new position
                                        boundaryPoints[selectedIndex] = coordinate
                                        selectedMarkerIndex = nil
                                    } else {
                                        // Add a new point
                                        boundaryPoints.append(coordinate)
                                    }
                                }
                            }
                        }

                        // Point count indicator and selection info
                        VStack {
                            HStack {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("\(boundaryPoints.count) points")
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

                                    // Show boundary validation status
                                    if boundaryPoints.count >= 3 {
                                        let validation = boundaryValidationMessage
                                        Text(validation.message)
                                            .font(.caption2)
                                            .foregroundColor(validation.isValid ? .white : .white)
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
                    .frame(maxHeight: .infinity)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .background(Color(.systemGroupedBackground))

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
                    Button("Create") {
                        Task {
                            await createGroup()
                        }
                    }
                    .disabled(!canCreate || isSaving)
                }
            }
            .onChange(of: shouldDismiss) { _, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }

    private var canCreate: Bool {
        !groupName.trimmingCharacters(in: .whitespaces).isEmpty && boundaryPoints.count >= 3 && boundaryValidationMessage.isValid
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
            print("Group created successfully with ID: \(groupId)")
            await firestoreService.fetchJoinedGroups()
            isSaving = false
            shouldDismiss = true
        case .failure(let error):
            print("Group creation failed: \(error.errorDescription ?? "Unknown")")
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
    }
}

#Preview {
    CreateGroupView()
}
