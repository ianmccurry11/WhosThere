//
//  LocationSetupView.swift
//  WhosThereios
//

import SwiftUI
import CoreLocation

/// Walks the user through the two settings automatic check-in needs:
/// location "Always" and Precise Location. Shown once from Home when either is
/// missing, and again from the home banner's Fix button.
struct LocationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var locationService = LocationService.shared

    /// iOS shows its "Change to Always Allow" prompt only once per install;
    /// after that, Settings is the only way
    @AppStorage("hasRequestedAlwaysLocation") private var hasRequestedAlways = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: isComplete ? "checkmark.circle.fill" : "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(isComplete ? .green : .appBlue)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(isComplete ? "You're all set" : "Get checked in automatically")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Who's There checks you in when you arrive and out when you leave, without opening the app. That needs two settings:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    LocationSetupRow(
                        title: "Location: Always",
                        detail: "So your phone can check you in while the app is closed",
                        isDone: hasAlways
                    )
                    LocationSetupRow(
                        title: "Precise Location: On",
                        detail: "So you match the right spot, not just the neighborhood",
                        isDone: hasPrecise
                    )
                }

                Text("Friends only see whether you're at a group, never where you are.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                VStack(spacing: 12) {
                    if opensSettings {
                        Text("In Settings, tap Location, choose Always, and turn on Precise Location.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: performPrimaryAction) {
                        Text(primaryButtonTitle)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appBlue)
                            .cornerRadius(14)
                    }

                    if !isComplete {
                        Button("Not Now") {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(24)
        }
    }

    // MARK: - State

    private var hasAlways: Bool {
        locationService.authorizationStatus == .authorizedAlways
    }

    private var hasPrecise: Bool {
        let isAuthorized = locationService.authorizationStatus == .authorizedAlways
            || locationService.authorizationStatus == .authorizedWhenInUse
        return isAuthorized && locationService.hasPreciseLocation
    }

    private var isComplete: Bool {
        hasAlways && hasPrecise
    }

    /// Whether the main button can only help by opening Settings
    private var opensSettings: Bool {
        switch locationService.authorizationStatus {
        case .notDetermined:
            return false
        case .authorizedWhenInUse:
            return hasRequestedAlways
        case .authorizedAlways:
            return !hasPrecise
        default:
            return true
        }
    }

    private var primaryButtonTitle: String {
        if isComplete { return "Done" }
        switch locationService.authorizationStatus {
        case .notDetermined:
            return "Allow Location"
        case .authorizedWhenInUse where !hasRequestedAlways:
            return "Allow \"Always\""
        default:
            return "Open Settings"
        }
    }

    // MARK: - Actions

    private func performPrimaryAction() {
        HapticManager.light()
        if isComplete {
            dismiss()
            return
        }
        switch locationService.authorizationStatus {
        case .notDetermined:
            // Shows iOS's "While Using" prompt, which includes the Precise toggle
            locationService.requestAuthorization()
        case .authorizedWhenInUse where !hasRequestedAlways:
            hasRequestedAlways = true
            locationService.requestAlwaysAuthorization()
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

private struct LocationSetupRow: View {
    let title: String
    let detail: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isDone ? .green : .secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isDone ? "Done" : "Not set")
    }
}

#Preview {
    LocationSetupView()
}
