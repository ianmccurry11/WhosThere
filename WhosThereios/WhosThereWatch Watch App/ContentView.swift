//
//  ContentView.swift
//  WhosThereWatch
//
//  Created by Claude on 1/18/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var watchViewModel = WatchViewModel()

    var body: some View {
        NavigationStack {
            if watchViewModel.isLoading {
                ProgressView("Loading...")
            } else if watchViewModel.groups.isEmpty {
                EmptyGroupsView()
            } else {
                GroupListView(viewModel: watchViewModel)
            }
        }
        .onAppear {
            watchViewModel.loadGroups()
        }
    }
}

// MARK: - Empty State

struct EmptyGroupsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundColor(.secondary)

            Text("No Groups")
                .font(.headline)

            Text("Join groups on your iPhone first")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Group List

struct GroupListView: View {
    @ObservedObject var viewModel: WatchViewModel

    var body: some View {
        List {
            // Nearby section (if location available)
            if let nearestGroup = viewModel.nearestGroup {
                Section("Nearby") {
                    NearbyGroupRow(
                        group: nearestGroup,
                        isCheckedIn: viewModel.isCheckedIn(nearestGroup),
                        onToggle: {
                            viewModel.toggleCheckIn(for: nearestGroup)
                        }
                    )
                }
            }

            // All groups section
            Section("Your Groups") {
                ForEach(viewModel.groups) { group in
                    GroupRow(
                        group: group,
                        isCheckedIn: viewModel.isCheckedIn(group),
                        peopleCount: viewModel.presenceCount(for: group),
                        onToggle: {
                            viewModel.toggleCheckIn(for: group)
                        }
                    )
                }
            }
        }
        .navigationTitle("Who's There")
    }
}

// MARK: - Nearby Group Row (Prominent)

struct NearbyGroupRow: View {
    let group: WatchGroup
    let isCheckedIn: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(group.emoji)
                        .font(.title2)

                    Text(group.name)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()
                }

                HStack {
                    if isCheckedIn {
                        Label("Checked In", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Label("Tap to Check In", systemImage: "circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    if group.presentCount > 0 {
                        Text("\(group.presentCount) here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 8)
                .fill(isCheckedIn ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
        )
    }
}

// MARK: - Regular Group Row

struct GroupRow: View {
    let group: WatchGroup
    let isCheckedIn: Bool
    let peopleCount: Int
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                // Emoji
                Text(group.emoji)
                    .font(.title3)

                // Name and status
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)
                        .lineLimit(1)

                    if peopleCount > 0 {
                        Text("\(peopleCount) people")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Check-in indicator
                Image(systemName: isCheckedIn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isCheckedIn ? .green : .gray)
                    .font(.title3)
            }
        }
    }
}

#Preview {
    ContentView()
}
