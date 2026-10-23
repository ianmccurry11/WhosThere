//
//  GroupPreviewSheet.swift
//  WhosThereios
//
//  Created by Claude on 3/19/26.
//

import SwiftUI
import MapKit

/// Sheet shown when a user opens a deep link to a group.
/// Displays a preview of the group with an option to join or open if already a member.
struct GroupPreviewSheet: View {
    let group: LocationGroup
    let onJoin: () async -> Void
    let onOpen: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var firestoreService = FirestoreService.shared
    @State private var isJoining = false
    @State private var joinError: String?
    @State private var mapPosition: MapCameraPosition = .automatic

    private var isAlreadyMember: Bool {
        guard let groupId = group.id else { return false }
        return firestoreService.currentUser?.joinedGroupIds.contains(groupId) ?? false
    }

    private var hasValidCoordinates: Bool {
        let lat = group.centerLatitude
        let lng = group.centerLongitude
        return !(lat == 0 && lng == 0) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Map preview
                if hasValidCoordinates {
                    Map(position: $mapPosition) {
                        if group.boundaryCoordinates.count >= 3 {
                            MapPolygon(coordinates: group.boundaryCoordinates)
                                .stroke(group.displayColor, lineWidth: 2)
                                .foregroundStyle(group.displayColor.opacity(0.2))
                        }
                        Annotation(group.name, coordinate: group.center) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundColor(group.displayColor)
                        }
                    }
                    .frame(height: 180)
                    .cornerRadius(16)
                    .allowsHitTesting(false)
                    .onAppear {
                        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        mapPosition = .region(MKCoordinateRegion(center: group.center, span: span))
                    }
                }

                // Group info
                VStack(spacing: 12) {
                    GroupIconView(icon: group.displayEmoji, size: 56)

                    Text(group.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        Label(group.isPublic ? "Public" : "Private", systemImage: group.isPublic ? "globe" : "lock.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Label("\(group.memberIds.count) member\(group.memberIds.count == 1 ? "" : "s")", systemImage: "person.2")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Error message
                if let error = joinError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                // Action button
                if isAlreadyMember {
                    Button {
                        dismiss()
                        onOpen()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.right.circle.fill")
                            Text("Open Group")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appBlue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }

                    Text("You're already a member of this group")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button {
                        Task {
                            isJoining = true
                            joinError = nil
                            await onJoin()
                            isJoining = false
                            dismiss()
                        }
                    } label: {
                        HStack {
                            if isJoining {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.badge.plus")
                                Text("Join Group")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.appBlue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isJoining)
                }
            }
            .padding()
            .navigationTitle("Group Invite")
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
