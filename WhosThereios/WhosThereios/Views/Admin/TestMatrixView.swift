//
//  TestMatrixView.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

/// Admin view for viewing and managing device/OS test matrix
struct TestMatrixView: View {
    @ObservedObject private var matrixService = TestMatrixService.shared
    @State private var selectedTab = 0
    @State private var selectedEntry: TestMatrixEntry?
    @State private var showAddIssue = false
    @State private var newIssueText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Coverage summary header
            coverageSummaryHeader

            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Matrix").tag(0)
                Text("Sessions").tag(1)
                Text("Coverage").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content
            switch selectedTab {
            case 0:
                matrixListView
            case 1:
                sessionsListView
            case 2:
                coverageAnalysisView
            default:
                matrixListView
            }
        }
        .navigationTitle("Test Matrix")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { matrixService.captureCurrentDevice() }) {
                        Label("Record Current Device", systemImage: "plus.circle")
                    }

                    if matrixService.currentSession == nil {
                        Button(action: { matrixService.startSession() }) {
                            Label("Start Test Session", systemImage: "play.circle")
                        }
                    } else {
                        Button(action: { matrixService.endSession() }) {
                            Label("End Test Session", systemImage: "stop.circle")
                        }
                    }

                    Divider()

                    Button(role: .destructive, action: { matrixService.clearAllData() }) {
                        Label("Clear All Data", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            EntryDetailSheet(entry: entry)
        }
    }

    // MARK: - Coverage Summary Header

    private var coverageSummaryHeader: some View {
        let summary = matrixService.coverageSummary

        return VStack(spacing: 8) {
            // Current device info
            if let device = matrixService.currentDevice {
                HStack {
                    Image(systemName: device.isSimulator ? "desktopcomputer" : "iphone")
                        .foregroundColor(.blue)
                    Text(device.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("iOS \(device.systemVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if matrixService.currentSession != nil {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Recording")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            Divider()

            // Stats row
            HStack(spacing: 16) {
                StatBadge(value: "\(summary.totalDevices)", label: "Devices", color: .blue)
                StatBadge(value: "\(summary.uniqueOSVersions)", label: "OS Versions", color: .purple)
                StatBadge(value: "\(summary.passedCount)", label: "Passed", color: .green)
                StatBadge(value: String(format: "%.0f%%", summary.coveragePercentage), label: "Coverage", color: .orange)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Matrix List View

    private var matrixListView: some View {
        Group {
            if matrixService.matrixEntries.isEmpty {
                emptyStateView(
                    icon: "rectangle.grid.2x2",
                    title: "No Devices Tested",
                    message: "Run the app on different devices and simulators to build your test matrix."
                )
            } else {
                List {
                    ForEach(TestStatus.allCases, id: \.self) { status in
                        let entries = matrixService.entriesByStatus[status] ?? []
                        if !entries.isEmpty {
                            Section(status.rawValue) {
                                ForEach(entries) { entry in
                                    MatrixEntryRow(entry: entry)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedEntry = entry
                                        }
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        matrixService.deleteEntry(entries[index])
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Sessions List View

    private var sessionsListView: some View {
        Group {
            if matrixService.sessions.isEmpty {
                emptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Test Sessions",
                    message: "Start a test session to track your testing activity."
                )
            } else {
                List {
                    ForEach(matrixService.sessions) { session in
                        SessionRow(session: session)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Coverage Analysis View

    private var coverageAnalysisView: some View {
        let summary = matrixService.coverageSummary

        return List {
            Section("Overview") {
                CoverageRow(label: "Total Devices", value: "\(summary.totalDevices)")
                CoverageRow(label: "Physical Devices", value: "\(summary.physicalDevices)")
                CoverageRow(label: "Simulators", value: "\(summary.simulators)")
                CoverageRow(label: "Unique OS Versions", value: "\(summary.uniqueOSVersions)")
            }

            Section("Screen Sizes") {
                ForEach(ScreenCategory.allCases, id: \.self) { category in
                    let entries = matrixService.entriesByScreenCategory[category] ?? []
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(entries.isEmpty ? .secondary : .blue)
                            .frame(width: 24)
                        Text(category.rawValue)
                        Spacer()
                        if entries.isEmpty {
                            Text("Not tested")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Text("\(entries.count) device(s)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("OS Versions") {
                let sortedVersions = matrixService.entriesByOSVersion.keys.sorted().reversed()
                ForEach(Array(sortedVersions), id: \.self) { version in
                    let entries = matrixService.entriesByOSVersion[version] ?? []
                    HStack {
                        Text("iOS \(version)")
                        Spacer()
                        Text("\(entries.count) device(s)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !matrixService.recommendedDevices.isEmpty {
                Section("Recommended Tests") {
                    ForEach(matrixService.recommendedDevices, id: \.self) { recommendation in
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(recommendation)
                                .font(.subheadline)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("Complete Coverage")
                    Spacer()
                    Image(systemName: summary.hasCompleteCoverage ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(summary.hasCompleteCoverage ? .green : .red)
                }
            } footer: {
                Text("Complete coverage requires testing on at least 3 screen sizes and 1 physical device.")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helper Views

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Matrix Entry Row

struct MatrixEntryRow: View {
    let entry: TestMatrixEntry

    private var statusColor: Color {
        switch entry.status {
        case .passed: return .green
        case .failed: return .red
        case .partial: return .orange
        case .untested: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: entry.status.icon)
                .foregroundColor(statusColor)

            // Device icon
            Image(systemName: entry.isSimulator ? "desktopcomputer" : entry.screenCategory.icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.deviceName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if entry.isSimulator {
                        Text("SIM")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                HStack(spacing: 8) {
                    Text("iOS \(entry.osVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !entry.issues.isEmpty {
                        Text("\(entry.issues.count) issue(s)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Test count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.testCount)x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDate(entry.lastTestedAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: TestSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: session.deviceInfo.isSimulator ? "desktopcomputer" : "iphone")
                    .foregroundColor(.blue)
                Text(session.deviceInfo.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if session.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            HStack(spacing: 16) {
                Label("\(session.screensVisited.count) screens", systemImage: "rectangle.portrait")
                Label("\(session.actionsPerformed) actions", systemImage: "hand.tap")
                if session.errorsEncountered > 0 {
                    Label("\(session.errorsEncountered) errors", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)

            Text(formatSessionTime(session))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatSessionTime(_ session: TestSession) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, HH:mm"

        let start = formatter.string(from: session.startTime)
        let duration = formatDuration(session.duration)

        return "\(start) (\(duration))"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

// MARK: - Entry Detail Sheet

struct EntryDetailSheet: View {
    let entry: TestMatrixEntry
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var matrixService = TestMatrixService.shared
    @State private var showAddIssue = false
    @State private var newIssueText = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Device Info") {
                    DetailRow(label: "Device", value: entry.deviceName)
                    DetailRow(label: "Model", value: entry.deviceModel)
                    DetailRow(label: "OS Version", value: "iOS \(entry.osVersion)")
                    DetailRow(label: "Screen Size", value: entry.screenCategory.rawValue)
                    DetailRow(label: "Type", value: entry.isSimulator ? "Simulator" : "Physical")
                }

                Section("Test Info") {
                    DetailRow(label: "Test Count", value: "\(entry.testCount)")
                    DetailRow(label: "Last Tested", value: formatDate(entry.lastTestedAt))

                    Picker("Status", selection: Binding(
                        get: { entry.status },
                        set: { matrixService.updateStatus(for: entry, status: $0) }
                    )) {
                        ForEach(TestStatus.allCases, id: \.self) { status in
                            Label(status.rawValue, systemImage: status.icon)
                                .tag(status)
                        }
                    }
                }

                Section("Issues") {
                    if entry.issues.isEmpty {
                        Text("No issues reported")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(Array(entry.issues.enumerated()), id: \.offset) { index, issue in
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text(issue)
                                    .font(.subheadline)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                matrixService.removeIssue(from: entry, at: index)
                            }
                        }
                    }

                    Button {
                        showAddIssue = true
                    } label: {
                        Label("Add Issue", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Device Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Add Issue", isPresented: $showAddIssue) {
                TextField("Issue description", text: $newIssueText)
                Button("Cancel", role: .cancel) {
                    newIssueText = ""
                }
                Button("Add") {
                    if !newIssueText.isEmpty {
                        matrixService.addIssue(to: entry, issue: newIssueText)
                        newIssueText = ""
                    }
                }
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CoverageRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        TestMatrixView()
    }
}
