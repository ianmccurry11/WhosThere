//
//  UpdateRequiredView.swift
//  WhosThereios
//

import SwiftUI

/// Full-screen block shown when this version is below the minimum set in
/// Firestore (see AppVersionService). There's no way past it except updating.
struct UpdateRequiredView: View {
    let message: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 72))
                .foregroundColor(.appBlue)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Update Required")
                    .font(.title)
                    .fontWeight(.bold)

                Text(message ?? "A new version of Who's There is available. Update to keep checking in with your groups.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                HapticManager.medium()
                if let url = AppVersionService.appStoreURL {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Update")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appBlue)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    UpdateRequiredView(message: nil)
}
