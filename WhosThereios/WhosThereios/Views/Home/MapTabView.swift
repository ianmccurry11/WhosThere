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

    @AppStorage("showNonJoinedGroupsOnMap") private var showNonJoinedGroups = true
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var selectedGroup: LocationGroup?
    @State private var lastFetchLocation: CLLocation?
    @State private var mapSpan: MKCoordinateSpan = .init(latitudeDelta: 0.05, longitudeDelta: 0.05)

    /// Show compact (emoji-only) pins when the visible region is wider than ~8km
    private var isZoomedOut: Bool { mapSpan.latitudeDelta > 0.08 }

    // Ghost Mode easter egg
    @State private var isGhostMode = false
    @State private var showGhostEmoji = false

    /// Minimum distance (in meters) user must move before triggering a new fetch
    private let minFetchDistance: CLLocationDistance = 100

    /// Ghost Mode activates between 12:00am and 12:05am
    private var isGhostHour: Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return comps.hour == 0 && (comps.minute ?? 0) < 5
    }

    var body: some View {
        ZStack {
            Map(position: $position) {
                // User location
                UserAnnotation()

                // Group boundaries
                ForEach(allGroups) { group in
                    // Polygon overlay for boundary
                    MapPolygon(coordinates: group.boundaryCoordinates)
                        .stroke(ghostStrokeColor(for: group), lineWidth: isGhostMode ? 1.5 : 2)
                        .foregroundStyle(ghostFillColor(for: group))

                    // Center annotation — pass "" to suppress MapKit's built-in label (name shown in bubble instead)
                    Annotation("", coordinate: group.center) {
                        Button {
                            selectedGroup = group
                        } label: {
                            if isGhostMode {
                                GhostMapAnnotation(
                                    group: group,
                                    presenceText: presenceService.formatPresenceDisplay(for: group)
                                )
                            } else {
                                GroupMapAnnotation(
                                    group: group,
                                    isJoined: isJoined(group),
                                    presenceText: presenceService.formatPresenceDisplay(for: group),
                                    isCompact: isZoomedOut
                                )
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(group.name), \(presenceService.formatPresenceDisplay(for: group))")
                    }
                }
            }
            .mapStyle(isGhostMode ? .standard(pointsOfInterest: .excludingAll) : .standard)
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange { context in
                mapSpan = context.region.span
            }

            // Show/hide non-joined groups toggle
            VStack {
                HStack {
                    Button {
                        HapticManager.light()
                        showNonJoinedGroups.toggle()
                    } label: {
                        Image(systemName: showNonJoinedGroups ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(showNonJoinedGroups ? .primary : .secondary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .appShadow, radius: 4, y: 2)
                    }
                    .accessibilityLabel(showNonJoinedGroups ? "Hide nearby groups" : "Show nearby groups")
                    .padding(.leading, 12)
                    Spacer()
                }
                Spacer()
            }
            .padding(.top, 60)

            // Location permission overlay
            if locationService.authorizationStatus == .denied ||
                locationService.authorizationStatus == .restricted {
                LocationPermissionOverlay()
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
            }

            // Ghost Mode floating emoji
            if showGhostEmoji {
                GhostFloatingEmoji()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .onAppear {
            activateGhostModeIfNeeded()
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

        if showNonJoinedGroups {
            for group in firestoreService.publicGroups {
                if let id = group.id, !seenIds.contains(id) {
                    seenIds.insert(id)
                    groups.append(group)
                }
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

    // MARK: - Ghost Mode Helpers

    private func ghostStrokeColor(for group: LocationGroup) -> Color {
        isGhostMode ? .appGhostStroke : strokeColor(for: group)
    }

    private func ghostFillColor(for group: LocationGroup) -> Color {
        isGhostMode ? .appGhostStroke.opacity(0.08) : fillColor(for: group)
    }

    private func activateGhostModeIfNeeded() {
        guard isGhostHour else { return }

        // Activate ghost mode
        withAnimation(.easeIn(duration: 1.0)) {
            isGhostMode = true
        }

        // Float a ghost emoji across the screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeIn(duration: 0.4)) {
                showGhostEmoji = true
            }
        }

        // Deactivate after 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            withAnimation(.easeOut(duration: 1.0)) {
                showGhostEmoji = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 1.0)) {
                    isGhostMode = false
                }
            }
        }
    }
}

// MARK: - Ghost Mode Views

struct GhostMapAnnotation: View {
    let group: LocationGroup
    let presenceText: String

    var body: some View {
        VStack(spacing: 4) {
            VStack(spacing: 2) {
                Text("👻")
                    .font(.caption)
                Text(presenceText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appGhostOverlay)
            )

            Circle()
                .fill(Color.appGhostStroke.opacity(0.5))
                .frame(width: 28, height: 28)
                .overlay(
                    Text("👻")
                        .font(.system(size: 14))
                )
        }
    }
}

struct GhostFloatingEmoji: View {
    @State private var xOffset: CGFloat = -80
    @State private var yOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Text("👻")
                .font(.system(size: 50))
                .shadow(color: .white.opacity(0.6), radius: 10)
                .offset(x: xOffset, y: geo.size.height * 0.35 + yOffset)
                .onAppear {
                    // Float across the screen with a gentle wave
                    withAnimation(.linear(duration: 4.0)) {
                        xOffset = geo.size.width + 80
                    }
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        yOffset = -30
                    }
                }
        }
    }
}

struct GroupMapAnnotation: View {
    let group: LocationGroup
    let isJoined: Bool
    let presenceText: String
    var isCompact: Bool = false

    var body: some View {
        if isCompact {
            // Zoomed out: emoji pin only — no bubble, no name
            ZStack {
                Circle()
                    .fill(isJoined ? group.displayColor : Color.gray)
                    .frame(width: 32, height: 32)
                    .shadow(radius: 2)
                GroupIconView(icon: group.displayEmoji, size: 16)
            }
        } else {
            // Zoomed in: full bubble with name and presence
            VStack(spacing: 4) {
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        GroupIconView(icon: group.displayEmoji, size: 12)
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

                ZStack {
                    Circle()
                        .fill(isJoined ? group.displayColor : Color.gray)
                        .frame(width: 32, height: 32)
                    GroupIconView(icon: group.displayEmoji, size: 16)
                }
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
            .accessibilityHint("Opens device settings to change location permission")
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
