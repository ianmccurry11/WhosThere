//
//  FailureInjectionView.swift
//  WhosThereios
//
//  Created by Claude on 2/5/26.
//

import SwiftUI

/// Admin view for controlling failure injection modes
struct FailureInjectionView: View {
    @ObservedObject private var service = FailureInjectionService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Status header
                statusHeader

                // Tab picker
                Picker("View", selection: $selectedTab) {
                    Text("Modes").tag(0)
                    Text("Log").tag(1)
                    Text("Stats").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content
                switch selectedTab {
                case 0:
                    modesView
                case 1:
                    logView
                case 2:
                    statsView
                default:
                    EmptyView()
                }
            }
            .navigationTitle("Failure Injection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { service.reset() }) {
                            Label("Reset to Normal", systemImage: "arrow.counterclockwise")
                        }
                        Button(action: { service.clearLog() }) {
                            Label("Clear Log", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 8) {
            HStack {
                // Active mode indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(service.isEnabled ? Color.red : Color.green)
                        .frame(width: 10, height: 10)

                    Text(service.isEnabled ? "INJECTION ACTIVE" : "NORMAL MODE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(service.isEnabled ? .red : .green)
                }

                Spacer()

                // Current mode
                if service.isEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: service.currentMode.icon)
                            .font(.caption)
                        Text(service.currentMode.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }

            // Stats row
            HStack(spacing: 16) {
                VStack(spacing: 2) {
                    Text("\(service.injectedCount)")
                        .font(.headline.monospaced())
                        .foregroundColor(.red)
                    Text("Injected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text("\(service.passedCount)")
                        .font(.headline.monospaced())
                        .foregroundColor(.green)
                    Text("Passed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", service.failureRate))
                        .font(.headline.monospaced())
                        .foregroundColor(.orange)
                    Text("Fail Rate")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(service.isEnabled ? Color.red.opacity(0.1) : Color(.systemGray6))
    }

    // MARK: - Modes View

    private var modesView: some View {
        List {
            Section {
                ForEach(FailureMode.allCases, id: \.self) { mode in
                    Button {
                        service.setMode(mode)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.icon)
                                .foregroundColor(mode == .none ? .green : .orange)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)

                                Text(mode.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if service.currentMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Failure Modes")
            } footer: {
                Text("Select a mode to simulate failures. The app should handle all modes gracefully without crashing.")
            }

            Section("Expected Behaviors") {
                ExpectedBehaviorRow(
                    mode: "No Network",
                    expected: "Offline indicator shows, operations fail with clear error, retry available"
                )
                ExpectedBehaviorRow(
                    mode: "Slow Network",
                    expected: "Loading indicators show, UI stays responsive, no premature timeouts"
                )
                ExpectedBehaviorRow(
                    mode: "Intermittent",
                    expected: "Retry logic handles failures, occasional errors shown, no data corruption"
                )
                ExpectedBehaviorRow(
                    mode: "Auth Failure",
                    expected: "Clear error message, retry option, no infinite loops"
                )
                ExpectedBehaviorRow(
                    mode: "Firestore Failure",
                    expected: "Graceful degradation, cached data shown if available"
                )
                ExpectedBehaviorRow(
                    mode: "Timeout",
                    expected: "Timeout after reasonable period, loading state resolves, cancel option"
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Log View

    private var logView: some View {
        Group {
            if service.failureLog.isEmpty {
                ContentUnavailableView(
                    "No Events",
                    systemImage: "doc.text",
                    description: Text("Failure injection events will appear here")
                )
            } else {
                List {
                    ForEach(service.failureLog) { event in
                        FailureEventRow(event: event)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Stats View

    private var statsView: some View {
        List {
            Section("Session Statistics") {
                HStack {
                    Text("Total Operations")
                    Spacer()
                    Text("\(service.injectedCount + service.passedCount)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Injected Failures")
                    Spacer()
                    Text("\(service.injectedCount)")
                        .foregroundColor(.red)
                }
                HStack {
                    Text("Passed Through")
                    Spacer()
                    Text("\(service.passedCount)")
                        .foregroundColor(.green)
                }
                HStack {
                    Text("Failure Rate")
                    Spacer()
                    Text(String(format: "%.1f%%", service.failureRate))
                        .foregroundColor(.orange)
                }
            }

            let byOp = service.failuresByOperation
            if !byOp.isEmpty {
                Section("Failures by Operation") {
                    ForEach(byOp.sorted { $0.value > $1.value }, id: \.key) { op, count in
                        HStack {
                            Text(op)
                                .font(.subheadline)
                            Spacer()
                            Text("\(count)")
                                .font(.subheadline.monospaced())
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            Section("Current Mode") {
                HStack {
                    Image(systemName: service.currentMode.icon)
                        .foregroundColor(service.currentMode == .none ? .green : .orange)
                    Text(service.currentMode.rawValue)
                    Spacer()
                    Text(service.isEnabled ? "Active" : "Inactive")
                        .foregroundColor(service.isEnabled ? .red : .secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Failure Event Row

private struct FailureEventRow: View {
    let event: FailureEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: event.didFail ? "xmark.circle.fill" : "checkmark.circle")
                    .foregroundColor(event.didFail ? .red : .green)
                    .font(.caption)

                Text(event.operation)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(formatTime(event.timestamp))
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
            }

            Text(event.appBehavior)
                .font(.caption)
                .foregroundColor(.secondary)

            if event.didFail {
                Text(event.injectedMode.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Expected Behavior Row

private struct ExpectedBehaviorRow: View {
    let mode: String
    let expected: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(mode)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(expected)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    FailureInjectionView()
}
