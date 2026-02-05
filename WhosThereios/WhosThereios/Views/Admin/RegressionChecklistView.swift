//
//  RegressionChecklistView.swift
//  WhosThereios
//
//  Created by Claude on 2/5/26.
//

import SwiftUI

/// Admin view for managing regression test checklists
struct RegressionChecklistView: View {
    @ObservedObject private var service = RegressionChecklistService.shared
    @State private var selectedCategory: RegressionCategory?
    @State private var showHistory = false
    @State private var showCompleteAlert = false
    @State private var completionNotes = ""

    var body: some View {
        VStack(spacing: 0) {
            if let run = service.currentRun {
                // Active run header
                activeRunHeader(run)

                // Category list or check details
                if let category = selectedCategory {
                    categoryDetailView(category: category, run: run)
                } else {
                    categoryListView(run: run)
                }
            } else {
                // No active run
                noActiveRunView
            }
        }
        .sheet(isPresented: $showHistory) {
            RunHistoryView()
        }
        .alert("Complete Run", isPresented: $showCompleteAlert) {
            TextField("Notes (optional)", text: $completionNotes)
            Button("Cancel", role: .cancel) {
                completionNotes = ""
            }
            Button("Complete") {
                service.completeCurrentRun(notes: completionNotes)
                completionNotes = ""
            }
        } message: {
            if let run = service.currentRun {
                Text("Pass rate: \(String(format: "%.0f%%", run.passRate)). \(run.notRunCount) tests not run.")
            }
        }
    }

    // MARK: - Active Run Header

    private func activeRunHeader(_ run: RegressionRun) -> some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Passed
                    if run.passedCount > 0 {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(run.passedCount) / CGFloat(run.totalChecks))
                    }
                    // Failed
                    if run.failedCount > 0 {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: geometry.size.width * CGFloat(run.failedCount) / CGFloat(run.totalChecks))
                    }
                    // Blocked
                    if run.blockedCount > 0 {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: geometry.size.width * CGFloat(run.blockedCount) / CGFloat(run.totalChecks))
                    }
                    // Skipped
                    if run.skippedCount > 0 {
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * CGFloat(run.skippedCount) / CGFloat(run.totalChecks))
                    }
                    // Not run
                    if run.notRunCount > 0 {
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: geometry.size.width * CGFloat(run.notRunCount) / CGFloat(run.totalChecks))
                    }
                }
                .cornerRadius(4)
            }
            .frame(height: 8)

            // Stats row
            HStack(spacing: 12) {
                StatusCount(count: run.passedCount, label: "Pass", color: .green)
                StatusCount(count: run.failedCount, label: "Fail", color: .red)
                StatusCount(count: run.blockedCount, label: "Block", color: .orange)
                StatusCount(count: run.skippedCount, label: "Skip", color: .purple)
                StatusCount(count: run.notRunCount, label: "Left", color: .gray)
            }

            // Action buttons
            HStack {
                Button {
                    showHistory = true
                } label: {
                    Label("History", systemImage: "clock")
                        .font(.caption)
                }

                Spacer()

                if selectedCategory != nil {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Label("Categories", systemImage: "chevron.left")
                            .font(.caption)
                    }
                }

                Spacer()

                Menu {
                    Button(action: { showCompleteAlert = true }) {
                        Label("Complete Run", systemImage: "checkmark.seal")
                    }

                    Button(role: .destructive, action: { service.abandonCurrentRun() }) {
                        Label("Abandon Run", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Category List

    private func categoryListView(run: RegressionRun) -> some View {
        List {
            ForEach(RegressionCategory.allCases, id: \.self) { category in
                let checks = run.checks.filter { $0.category == category }
                let passed = checks.filter { $0.status == .passed }.count
                let failed = checks.filter { $0.status == .failed }.count
                let total = checks.count

                Button {
                    selectedCategory = category
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: category.icon)
                            .foregroundColor(.blue)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)

                            HStack(spacing: 8) {
                                if passed > 0 {
                                    Label("\(passed)", systemImage: "checkmark")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                                if failed > 0 {
                                    Label("\(failed)", systemImage: "xmark")
                                        .font(.caption2)
                                        .foregroundColor(.red)
                                }
                                let remaining = total - passed - failed - checks.filter { $0.status == .blocked || $0.status == .skipped }.count
                                if remaining > 0 {
                                    Text("\(remaining) remaining")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        // Mini progress
                        Text("\(passed)/\(total)")
                            .font(.caption.monospaced())
                            .foregroundColor(passed == total ? .green : .secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Category Detail

    private func categoryDetailView(category: RegressionCategory, run: RegressionRun) -> some View {
        let checks = run.checks.filter { $0.category == category }

        return List {
            ForEach(checks) { check in
                CheckRowView(
                    check: check,
                    onStatusChange: { status in
                        service.updateCheckStatus(check.id, status: status)
                    },
                    onNotesChange: { notes in
                        service.addNotes(to: check.id, notes: notes)
                    }
                )
            }
        }
        .listStyle(.plain)
        .navigationTitle(category.rawValue)
    }

    // MARK: - No Active Run

    private var noActiveRunView: some View {
        VStack(spacing: 16) {
            let summary = service.summary

            if summary.totalRuns > 0 {
                // Show summary of past runs
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(.blue)
                        Text("Last \(summary.totalRuns) run(s)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack(spacing: 16) {
                        VStack {
                            Text(String(format: "%.0f%%", summary.lastPassRate))
                                .font(.headline)
                                .foregroundColor(.green)
                            Text("Last Rate")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text(String(format: "%.0f%%", summary.averagePassRate))
                                .font(.headline)
                                .foregroundColor(.blue)
                            Text("Avg Rate")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text("\(summary.totalTestsExecuted)")
                                .font(.headline)
                                .foregroundColor(.purple)
                            Text("Tests Run")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }

            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Active Regression Run")
                .font(.headline)

            Text("Start a new run to test 45 checks across 8 categories")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                service.startNewRun()
            } label: {
                Label("Start New Run", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            if summary.totalRuns > 0 {
                Button {
                    showHistory = true
                } label: {
                    Label("View History", systemImage: "clock")
                        .font(.subheadline)
                }
            }

            Spacer()
        }
        .sheet(isPresented: $showHistory) {
            RunHistoryView()
        }
    }
}

// MARK: - Check Row View

private struct CheckRowView: View {
    let check: RegressionCheck
    let onStatusChange: (CheckStatus) -> Void
    let onNotesChange: (String) -> Void

    @State private var isExpanded = false
    @State private var editingNotes = false
    @State private var noteText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: check.status.icon)
                        .foregroundColor(colorForStatus(check.status))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(check.testId)
                                .font(.caption.monospaced())
                                .foregroundColor(.secondary)
                            Text(check.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    // Description
                    Text(check.description)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Expected result
                    HStack(alignment: .top) {
                        Text("Expected:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(check.expectedResult)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Status buttons
                    HStack(spacing: 8) {
                        ForEach(CheckStatus.allCases, id: \.self) { status in
                            Button {
                                onStatusChange(status)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: status.icon)
                                        .font(.caption2)
                                    Text(status.rawValue)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    check.status == status
                                        ? colorForStatus(status).opacity(0.2)
                                        : Color(.systemGray5)
                                )
                                .foregroundColor(
                                    check.status == status
                                        ? colorForStatus(status)
                                        : .secondary
                                )
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Notes
                    if !check.notes.isEmpty {
                        HStack(alignment: .top) {
                            Image(systemName: "note.text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(check.notes)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        noteText = check.notes
                        editingNotes = true
                    } label: {
                        Label(check.notes.isEmpty ? "Add Notes" : "Edit Notes", systemImage: "pencil")
                            .font(.caption)
                    }
                }
                .padding(.leading, 28)
            }
        }
        .padding(.vertical, 4)
        .alert("Notes", isPresented: $editingNotes) {
            TextField("Notes", text: $noteText)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                onNotesChange(noteText)
            }
        }
    }

    private func colorForStatus(_ status: CheckStatus) -> Color {
        switch status {
        case .notRun: return .gray
        case .passed: return .green
        case .failed: return .red
        case .blocked: return .orange
        case .skipped: return .purple
        }
    }
}

// MARK: - Status Count

private struct StatusCount: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.subheadline.monospaced())
                .fontWeight(.semibold)
                .foregroundColor(count > 0 ? color : .secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Run History View

struct RunHistoryView: View {
    @ObservedObject private var service = RegressionChecklistService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if service.completedRuns.isEmpty {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("Completed regression runs will appear here")
                    )
                } else {
                    List {
                        ForEach(service.completedRuns) { run in
                            RunSummaryRow(run: run)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                service.deleteRun(service.completedRuns[index])
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Run History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Run Summary Row

private struct RunSummaryRow: View {
    let run: RegressionRun

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: run.overallStatus.icon)
                    .foregroundColor(colorForRunStatus(run.overallStatus))

                Text("v\(run.appVersion) (\(run.buildNumber))")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(String(format: "%.0f%%", run.passRate))
                    .font(.subheadline.monospaced())
                    .fontWeight(.semibold)
                    .foregroundColor(run.passRate >= 90 ? .green : run.passRate >= 70 ? .orange : .red)
            }

            HStack(spacing: 12) {
                Label("\(run.passedCount) passed", systemImage: "checkmark")
                    .foregroundColor(.green)
                if run.failedCount > 0 {
                    Label("\(run.failedCount) failed", systemImage: "xmark")
                        .foregroundColor(.red)
                }
            }
            .font(.caption)

            HStack {
                Text(run.deviceName)
                Text("iOS \(run.osVersion)")
                if let completed = run.completedAt {
                    Spacer()
                    Text(formatDate(completed))
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)

            if !run.notes.isEmpty {
                Text(run.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func colorForRunStatus(_ status: RunStatus) -> Color {
        switch status {
        case .inProgress: return .blue
        case .passed: return .green
        case .failed: return .red
        case .blocked: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        RegressionChecklistView()
    }
}
