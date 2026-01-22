//
//  MapTabView.swift
//  WhosThereios
//
//  Created by Ian McCurry on 1/13/26.
//

import SwiftUI
import MapKit

struct MapTabView: View {
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var firestoreService = FirestoreService.shared
    @ObservedObject private var presenceService = PresenceService.shared

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedGroup: LocationGroup?
    @State private var lastFetchLocation: CLLocation?

    /// Minimum distance (in meters) user must move before triggering a new fetch
    private let minFetchDistance: CLLocationDistance = 100

    var body: some View {
        ZStack {
            Map(position: $position) {
                // User location
                UserAnnotation()

                // Group boundaries
                ForEach(allGroups) { group in
                    // Polygon overlay for boundary
                    MapPolygon(coordinates: group.boundaryCoordinates)
                        .stroke(strokeColor(for: group), lineWidth: 2)
                        .foregroundStyle(fillColor(for: group))

                    // Center annotation - using Button for reliable tap handling
                    Annotation(group.name, coordinate: group.center) {
                        Button {
                            selectedGroup = group
                        } label: {
                            GroupMapAnnotation(
                                group: group,
                                isJoined: isJoined(group),
                                presenceText: presenceService.formatPresenceDisplay(for: group)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }

            // Location permission overlay
            if locationService.authorizationStatus == .denied ||
                locationService.authorizationStatus == .restricted {
                LocationPermissionOverlay()
            }
        }
        .sheet(item: $selectedGroup) { group in
            GroupDetailView(group: group)
        }
        .onChange(of: locationService.currentLocation) { _, newLocation in
            guard let newLocation = newLocation else { return }

            // Only fetch if user has moved significantly (100m+) or this is the first location
            let shouldFetch: Bool
            if let lastLocation = lastFetchLocation {
                shouldFetch = newLocation.distance(from: lastLocation) > minFetchDistance
            } else {
                shouldFetch = true
            }

            guard shouldFetch else { return }

            lastFetchLocation = newLocation
            Task {
                await firestoreService.fetchNearbyGroups(center: newLocation.coordinate)
            }
        }
    }

    private var allGroups: [LocationGroup] {
        var groups: [LocationGroup] = []
        var seenIds = Set<String>()

        for group in firestoreService.joinedGroups {
            if let id = group.id, !seenIds.contains(id) {
                seenIds.insert(id)
                groups.append(group)
            }
        }

        for group in firestoreService.publicGroups {
            if let id = group.id, !seenIds.contains(id) {
                seenIds.insert(id)
                groups.append(group)
            }
        }

        return groups
    }

    private func isJoined(_ group: LocationGroup) -> Bool {
        guard let groupId = group.id else { return false }
        return firestoreService.currentUser?.joinedGroupIds.contains(groupId) ?? false
    }

    private func strokeColor(for group: LocationGroup) -> Color {
        isJoined(group) ? group.displayColor : .gray
    }

    private func fillColor(for group: LocationGroup) -> Color {
        isJoined(group) ? group.displayColor.opacity(0.2) : .gray.opacity(0.1)
    }
}

struct GroupMapAnnotation: View {
    let group: LocationGroup
    let isJoined: Bool
    let presenceText: String

    var body: some View {
        VStack(spacing: 4) {
            // Bubble showing presence
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(group.displayEmoji)
                        .font(.caption)
                    Text(group.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                Text(presenceText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 2)
            )

            // Pin
            ZStack {
                Circle()
                    .fill(isJoined ? group.displayColor : Color.gray)
                    .frame(width: 32, height: 32)
                Text(group.displayEmoji)
                    .font(.system(size: 16))
            }
        }
    }
}

struct LocationPermissionOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Location Access Required")
                .font(.headline)

            Text("Who's There needs location access to show you nearby groups and track your presence.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
        .padding()
    }
}

#Preview {
    MapTabView()
}
