//
//  NetworkInspectorView.swift
//  WhosThereios
//
//  Created by Claude on 2/4/26.
//

import SwiftUI

/// Admin view for inspecting network requests
/// Access: Analytics Dashboard -> Network tab
struct NetworkInspectorView: View {
    @ObservedObject private var inspector = NetworkInspector.shared
    @State private var selectedRequest: NetworkRequest?
    @State private var showFilters = false
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Requests").tag(0)
                Text("Stats").tag(1)
                Text("Slow").tag(2)
                Text("Errors").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            // Content based on selected tab
            switch selectedTab {
            case 0:
                requestsListView
            case 1:
                statisticsView
            case 2:
                slowRequestsView
            case 3:
                errorsView
            default:
                requestsListView
            }
        }
        .navigationTitle("Network Inspector")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showFilters.toggle() }) {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }

                    Button(action: { inspector.toggleLogging() }) {
                        Label(
                            inspector.isLoggingEnabled ? "Disable Logging" : "Enable Logging",
                            systemImage: inspector.isLoggingEnabled ? "pause.circle" : "play.circle"
                        )
                    }

                    Divider()

                    Button(role: .destructive, action: { inspector.clearRequests() }) {
                        Label("Clear All", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            filterSheet
        }
        .sheet(item: $selectedRequest) { request in
            RequestDetailView(request: request)
        }
    }

    // MARK: - Requests List

    private var requestsListView: some View {
        Group {
            if inspector.filteredRequests.isEmpty {
                emptyStateView(
                    icon: "network",
                    title: "No Requests",
                    message: inspector.isLoggingEnabled
                        ? "Network requests will appear here as they occur."
                        : "Logging is disabled. Enable it to capture requests."
                )
            } else {
                List {
                    ForEach(inspector.filteredRequests) { request in
                        RequestRowView(request: request)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRequest = request
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Statistics View

    private var statisticsView: some View {
        List {
            Section("Overview") {
                StatRow(label: "Total Requests", value: "\(inspector.statistics.totalRequests)")
                StatRow(label: "Successful", value: "\(inspector.statistics.successfulRequests)", color: .green)
                StatRow(label: "Failed", value: "\(inspector.statistics.failedRequests)", color: .red)
                StatRow(label: "Success Rate", value: String(format: "%.1f%%", inspector.statistics.successRate))
                StatRow(label: "Avg Latency", value: String(format: "%.0f ms", inspector.statistics.averageLatencyMs))
            }

            Section("By Operation") {
                ForEach(NetworkOperation.allCases, id: \.self) { operation in
                    let count = inspector.statistics.requestsByOperation[operation] ?? 0
                    if count > 0 {
                        HStack {
                            Text("\(operation.emoji) \(operation.rawValue)")
                            Spacer()
                            Text("\(count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Section("By Collection") {
                ForEach(inspector.accessedCollections, id: \.self) { collection in
                    let count = inspector.statistics.requestsByCollection[collection] ?? 0
                    HStack {
                        Text(collection)
                        Spacer()
                        Text("\(count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Slow Requests View

    private var slowRequestsView: some View {
        Group {
            if inspector.slowRequests.isEmpty {
                emptyStateView(
                    icon: "tortoise",
                    title: "No Slow Requests",
                    message: "Requests taking longer than \(Int(SlowRequestThreshold.warning))ms will appear here."
                )
            } else {
                List {
                    Section {
                        Text("Requests exceeding \(Int(SlowRequestThreshold.warning))ms threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ForEach(inspector.slowRequests.sorted(by: { $0.durationMs > $1.durationMs })) { request in
                        RequestRowView(request: request, showDurationProminent: true)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedRequest = request
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Errors View

    private var errorsView: some View {
        Group {
            if inspector.failedRequests.isEmpty {
                emptyStateView(
                    icon: "checkmark.circle",
                    title: "No Errors",
                    message: "Failed requests will appear here."
                )
            } else {
                List {
                    ForEach(inspector.failedRequests) { request in
                        VStack(alignment: .leading, spacing: 4) {
                            RequestRowView(request: request)

                            if let error = request.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .lineLimit(2)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRequest = request
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            Form {
                Section("Operations") {
                    ForEach(NetworkOperation.allCases, id: \.self) { operation in
                        Toggle(isOn: Binding(
                            get: { inspector.filter.operations.contains(operation) },
                            set: { isOn in
                                if isOn {
                                    inspector.filter.operations.insert(operation)
                                } else {
                                    inspector.filter.operations.remove(operation)
                                }
                            }
                        )) {
                            Text("\(operation.emoji) \(operation.rawValue)")
                        }
                    }
                }

                Section("Status") {
                    Toggle("Show Only Errors", isOn: $inspector.filter.showOnlyErrors)
                }

                Section("Performance") {
                    Toggle("Slow Requests Only (>\(Int(SlowRequestThreshold.warning))ms)", isOn: Binding(
                        get: { inspector.filter.minDurationMs != nil },
                        set: { isOn in
                            inspector.filter.minDurationMs = isOn ? SlowRequestThreshold.warning : nil
                        }
                    ))
                }

                Section {
                    Button("Reset Filters") {
                        inspector.filter = NetworkRequestFilter()
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showFilters = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
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

// MARK: - Request Row View

struct RequestRowView: View {
    let request: NetworkRequest
    var showDurationProminent: Bool = false

    private var statusColor: Color {
        switch request.status {
        case .success: return .green
        case .failure: return .red
        case .pending: return .orange
        case .cached: return .blue
        case .timeout: return .yellow
        }
    }

    private var durationColor: Color {
        switch SlowRequestThreshold.severity(for: request.durationMs) {
        case .normal: return .secondary
        case .warning: return .orange
        case .critical: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Operation icon
            Text(request.operation.emoji)
                .font(.title3)

            // Details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(request.collection)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let docId = request.documentId {
                        Text("/\(docId.prefix(8))...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Text(request.method.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(formatTime(request.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Duration
            Text(formatDuration(request.durationMs))
                .font(showDurationProminent ? .subheadline : .caption)
                .fontWeight(showDurationProminent ? .semibold : .regular)
                .foregroundColor(durationColor)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms < 1000 {
            return String(format: "%.0fms", ms)
        } else {
            return String(format: "%.1fs", ms / 1000)
        }
    }
}

// MARK: - Request Detail View

struct RequestDetailView: View {
    let request: NetworkRequest
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Request Info") {
                    DetailRow(label: "Operation", value: "\(request.operation.emoji) \(request.operation.rawValue)")
                    DetailRow(label: "Collection", value: request.collection)
                    if let docId = request.documentId {
                        DetailRow(label: "Document ID", value: docId)
                    }
                    DetailRow(label: "Method", value: request.method.rawValue)
                }

                Section("Response") {
                    DetailRow(label: "Status", value: request.status.rawValue)
                    DetailRow(label: "Duration", value: String(format: "%.2f ms", request.durationMs))
                    if let size = request.payloadSize {
                        DetailRow(label: "Payload Size", value: formatBytes(size))
                    }
                }

                if let error = request.errorMessage {
                    Section("Error") {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                if !request.metadata.isEmpty {
                    Section("Metadata") {
                        ForEach(request.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                            DetailRow(label: key, value: value)
                        }
                    }
                }

                Section("Timing") {
                    DetailRow(label: "Timestamp", value: formatFullDate(request.timestamp))
                    DetailRow(label: "Request ID", value: request.id.uuidString)
                }
            }
            .navigationTitle("Request Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

// MARK: - Helper Views

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    NavigationStack {
        NetworkInspectorView()
    }
}
