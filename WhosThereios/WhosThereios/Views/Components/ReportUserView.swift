//
//  ReportUserView.swift
//  WhosThereios
//
//  Reusable sheet for reporting a user. Can be triggered from
//  presence lists, chat messages, friend lists, etc.
//

import SwiftUI
import FirebaseAuth

struct ReportUserView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var firestoreService = FirestoreService.shared

    let reportedUserId: String
    let reportedDisplayName: String
    let context: ReportContext
    var groupId: String? = nil
    var messageId: String? = nil
    var messageText: String? = nil

    @State private var selectedReason: ReportReason?
    @State private var additionalDetails = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showAlreadyReported = false
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Report \(reportedDisplayName)")
                                .font(.title3)
                                .fontWeight(.bold)

                            Text("Select the reason for your report. Reports are reviewed by the team and kept confidential.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)

                        // Reason selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reason")
                                .font(.headline)

                            ForEach(ReportReason.allCases, id: \.self) { reason in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedReason = reason
                                    }
                                    HapticManager.light()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: reason.icon)
                                            .frame(width: 24)
                                            .foregroundColor(selectedReason == reason ? .white : .primary)

                                        Text(reason.displayName)
                                            .foregroundColor(selectedReason == reason ? .white : .primary)

                                        Spacer()

                                        if selectedReason == reason {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedReason == reason ? Color.red.opacity(0.85) : Color(.systemGray6))
                                    )
                                }
                                .accessibilityLabel("\(reason.displayName)\(selectedReason == reason ? ", selected" : "")")
                            }
                        }

                        // Message snapshot (if reporting a chat message)
                        if let messageText = messageText, !messageText.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reported Message")
                                    .font(.headline)

                                Text(messageText)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                            }
                        }

                        // Additional details
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Details (Optional)")
                                .font(.headline)

                            TextField("Describe the issue...", text: $additionalDetails, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                }

                // Submit button
                VStack(spacing: 0) {
                    Divider()
                    Button {
                        Task { await submitReport() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "flag.fill")
                                Text("Submit Report")
                            }
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedReason != nil ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedReason == nil || isSubmitting)
                    .padding()
                }
            }
            .navigationTitle("Report User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .alert("Report Submitted", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Thank you for helping keep the community safe. We'll review this report.")
        }
        .alert("Already Reported", isPresented: $showAlreadyReported) {
            Button("OK") { dismiss() }
        } message: {
            Text("You've already reported this user recently. We're reviewing it.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text("Failed to submit report. Please try again.")
        }
    }

    private func submitReport() async {
        guard let reason = selectedReason,
              let reporterId = Auth.auth().currentUser?.uid else { return }

        isSubmitting = true

        // Check for duplicate reports
        let alreadyReported = await firestoreService.hasRecentReport(reportedUserId: reportedUserId)
        if alreadyReported {
            isSubmitting = false
            showAlreadyReported = true
            return
        }

        let report = Report(
            reporterId: reporterId,
            reportedUserId: reportedUserId,
            reportedDisplayName: reportedDisplayName,
            reason: reason,
            context: context,
            details: additionalDetails.isEmpty ? nil : additionalDetails,
            groupId: groupId,
            messageId: messageId,
            messageText: messageText,
            status: .pending,
            createdAt: Date()
        )

        let result = await firestoreService.submitReport(report)

        isSubmitting = false

        switch result {
        case .success:
            HapticManager.success()
            showSuccess = true
        case .failure:
            HapticManager.error()
            showError = true
        }
    }
}
