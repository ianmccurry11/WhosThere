//
//  AnalyticsDashboardView.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

/// Admin dashboard for viewing and validating analytics events
struct AnalyticsDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var analyticsService = AnalyticsService.shared
    @ObservedObject private var achievementService = AchievementService.shared

    @State private var selectedTab = 0
    @State private var showExportSheet = false
    @State private var showFailureInjection = false
    @State private var exportedJSON = ""
    @State private var filterText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Session Info Header
                sessionInfoHeader

                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    Text("Events").tag(0)
                    Text("Counts").tag(1)
                    Text("Network").tag(2)
                    Text("Devices").tag(3)
                    Text("Checks").tag(4)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                switch selectedTab {
                case 0:
                    eventsListView
                case 1:
                    countsView
                case 2:
                    NetworkInspectorView()
                case 3:
                    TestMatrixView()
                case 4:
                    RegressionChecklistView()
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Analytics Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showFailureInjection = true
                        } label: {
                            Label("Failure Injection", systemImage: "ant")
                        }

                        Divider()

                        Button {
                            exportEvents()
                        } label: {
                            Label("Export Events", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            analyticsService.clearEvents()
                        } label: {
                            Label("Clear Events", systemImage: "trash")
                        }

                        Button {
                            analyticsService.resetPersistedCounts()
                        } label: {
                            Label("Reset Counts", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showFailureInjection) {
                FailureInjectionView()
            }
            .sheet(isPresented: $showExportSheet) {
                exportSheet
            }
        }
    }

    // MARK: - Session Info Header

    private var sessionInfoHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Session ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(analyticsService.sessionId.prefix(8)) + "...")
                        .font(.caption.monospaced())
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(analyticsService.sessionDuration))
                        .font(.caption.monospaced())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(analyticsService.recentEvents.count)")
                        .font(.caption.monospaced())
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
        }
    }

    // MARK: - Events List View

    private var eventsListView: some View {
        VStack(spacing: 0) {
            // Search/Filter
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Filter events...", text: $filterText)
                    .textFieldStyle(.plain)
                if !filterText.isEmpty {
                    Button {
                        filterText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

            if filteredEvents.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "chart.bar.xaxis",
                    description: Text(filterText.isEmpty ? "Events will appear here as you use the app" : "No events match '\(filterText)'")
                )
            } else {
                List {
                    ForEach(filteredEvents) { event in
                        EventRowView(event: event)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var filteredEvents: [AnalyticsEvent] {
        if filterText.isEmpty {
            return analyticsService.recentEvents
        }
        let lowercased = filterText.lowercased()
        return analyticsService.recentEvents.filter { event in
            event.name.lowercased().contains(lowercased) ||
            event.parameters.values.contains { $0.lowercased().contains(lowercased) }
        }
    }

    // MARK: - Counts View

    private var countsView: some View {
        let counts = analyticsService.getAggregatedCounts()
        let sortedCounts = counts.sorted { $0.value > $1.value }

        return Group {
            if sortedCounts.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar",
                    description: Text("Event counts will appear here")
                )
            } else {
                List {
                    Section("Event Counts (All Time)") {
                        ForEach(sortedCounts, id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(value)")
                                    .font(.subheadline.monospaced())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Section("Session Counts") {
                        let sessionCounts = getSessionCounts()
                        ForEach(sessionCounts.sorted { $0.value > $1.value }, id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(value)")
                                    .font(.subheadline.monospaced())
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    private func getSessionCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for event in analyticsService.recentEvents {
            counts[event.name, default: 0] += 1
        }
        return counts
    }

    // MARK: - Validation View

    private var validationView: some View {
        let discrepancies = analyticsService.getDiscrepancies(
            actualCheckIns: achievementService.userStats.totalCheckIns,
            actualGroupsCreated: achievementService.userStats.groupsCreated,
            actualAchievements: achievementService.earnedAchievements.count
        )

        return List {
            Section("Data Validation") {
                if discrepancies.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("All analytics data matches expected values")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(discrepancies) { discrepancy in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(discrepancy.eventName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            Text(discrepancy.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("Tracked: \(discrepancy.localCount)")
                                    .font(.caption.monospaced())
                                Text("Expected: \(discrepancy.expectedCount)")
                                    .font(.caption.monospaced())
                            }
                            .foregroundColor(.orange)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Expected Values (from UserStats)") {
                LabeledContent("Total Check-ins", value: "\(achievementService.userStats.totalCheckIns)")
                LabeledContent("Groups Created", value: "\(achievementService.userStats.groupsCreated)")
                LabeledContent("Achievements Earned", value: "\(achievementService.earnedAchievements.count)")
                LabeledContent("Current Streak", value: "\(achievementService.userStats.currentStreak)")
            }

            Section("Tracked Counts") {
                let counts = analyticsService.getAggregatedCounts()
                LabeledContent("check_in events", value: "\(counts[AnalyticsEventName.checkIn.rawValue, default: 0])")
                LabeledContent("group_created events", value: "\(counts[AnalyticsEventName.groupCreated.rawValue, default: 0])")
                LabeledContent("achievement_unlocked events", value: "\(counts[AnalyticsEventName.achievementUnlocked.rawValue, default: 0])")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Export Sheet

    private var exportSheet: some View {
        NavigationStack {
            ScrollView {
                Text(exportedJSON)
                    .font(.caption.monospaced())
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Exported Events")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showExportSheet = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIPasteboard.general.string = exportedJSON
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func exportEvents() {
        exportedJSON = analyticsService.exportEventsAsJSON()
        showExportSheet = true
    }
}

// MARK: - Event Row View

private struct EventRowView: View {
    let event: AnalyticsEvent

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    // Event name with icon
                    HStack(spacing: 6) {
                        Image(systemName: iconForEvent(event.name))
                            .font(.caption)
                            .foregroundColor(colorForEvent(event.name))
                            .frame(width: 20)

                        Text(event.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    // Timestamp
                    Text(formatTime(event.timestamp))
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)

                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Parameters (when expanded)
            if isExpanded && !event.parameters.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(event.parameters.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(value)
                                .font(.caption.monospaced())
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.leading, 26)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func iconForEvent(_ name: String) -> String {
        if name.contains("sign_in") || name.contains("sign_out") {
            return "person.circle"
        } else if name.contains("group") {
            return "person.3"
        } else if name.contains("check") {
            return "location"
        } else if name.contains("achievement") {
            return "trophy"
        } else if name.contains("message") {
            return "bubble.left"
        } else if name.contains("error") {
            return "exclamationmark.triangle"
        } else if name.contains("screen") {
            return "rectangle.portrait"
        } else if name.contains("app") {
            return "apps.iphone"
        }
        return "circle"
    }

    private func colorForEvent(_ name: String) -> Color {
        if name.contains("error") || name.contains("failure") {
            return .red
        } else if name.contains("success") {
            return .green
        } else if name.contains("check_in") {
            return .green
        } else if name.contains("check_out") {
            return .orange
        } else if name.contains("achievement") {
            return .purple
        } else if name.contains("group") {
            return .blue
        }
        return .gray
    }
}

#Preview {
    AnalyticsDashboardView()
}
